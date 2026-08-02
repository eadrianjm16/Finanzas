import SwiftUI
import SwiftData

private let iconOptions = [
    "arrow.down.circle", "cart", "fork.knife", "car", "house", "bolt",
    "cross.case", "gamecontroller", "bag", "arrow.triangle.2.circlepath",
    "building.columns", "questionmark.circle",
    "banknote", "gift", "pawprint", "airplane", "wrench.and.screwdriver",
    "heart", "graduationcap", "dumbbell", "tshirt", "wifi", "tv",
    "cup.and.saucer", "fuelpump", "briefcase", "umbrella", "creditcard",
    "book", "phone"
]

private enum CategorySheetMode: Identifiable {
    case add
    case edit(Category)

    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let category): return String(category.persistentModelID.hashValue)
        }
    }
}

struct CategoriesSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    @State private var sheetMode: CategorySheetMode?

    var body: some View {
        List {
            ForEach(categories) { category in
                Button {
                    sheetMode = .edit(category)
                } label: {
                    Label(category.name, systemImage: category.systemIconName)
                        .foregroundStyle(.primary)
                }
            }
            .onDelete(perform: delete)
        }
        .navigationTitle("Categorías")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    sheetMode = .add
                } label: {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                NavigationLink("Reordenar") {
                    CategoryReorderView()
                }
            }
        }
        .sheet(item: $sheetMode) { mode in
            CategoryEditorSheet(
                mode: mode,
                existingNames: categories.map(\.name),
                nextSortOrder: (categories.map(\.sortOrder).max() ?? -1) + 1
            )
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            deleteCategory(categories[index])
        }
    }

    private func deleteCategory(_ category: Category) {
        guard category.name != DefaultCategories.otrosName else { return }
        let otros = categories.first(where: { $0.name == DefaultCategories.otrosName })
        for tx in category.transactions {
            tx.category = otros
        }
        let categoryName = category.name
        var descriptor = FetchDescriptor<Budget>(predicate: #Predicate { $0.categoryName == categoryName })
        descriptor.fetchLimit = 1
        if let budget = try? modelContext.fetch(descriptor).first {
            modelContext.delete(budget)
        }
        modelContext.delete(category)
        try? modelContext.save()
    }
}

private struct CategoryEditorSheet: View {
    let mode: CategorySheetMode
    let existingNames: [String]
    let nextSortOrder: Int

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var draftName: String
    @State private var draftIcon: String
    @State private var errorMessage: String?

    init(mode: CategorySheetMode, existingNames: [String], nextSortOrder: Int) {
        self.mode = mode
        self.existingNames = existingNames
        self.nextSortOrder = nextSortOrder
        switch mode {
        case .add:
            _draftName = State(initialValue: "")
            _draftIcon = State(initialValue: "questionmark.circle")
        case .edit(let category):
            _draftName = State(initialValue: category.name)
            _draftIcon = State(initialValue: category.systemIconName)
        }
    }

    private var title: String {
        switch mode {
        case .add: return "Nueva categoría"
        case .edit: return "Editar categoría"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nombre", text: $draftName)
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                Section("Ícono") {
                    Picker("Ícono", selection: $draftIcon) {
                        ForEach(iconOptions, id: \.self) { icon in
                            Image(systemName: icon).tag(icon)
                        }
                    }
                    .pickerStyle(.palette)
                    .paletteSelectionEffect(.symbolVariant(.fill))
                    .labelsHidden()
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        let trimmed = draftName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            errorMessage = "Pon un nombre"
            return
        }

        switch mode {
        case .add:
            guard !existingNames.contains(trimmed) else {
                errorMessage = "Ya existe una categoría con ese nombre"
                return
            }
            modelContext.insert(Category(name: trimmed, systemIconName: draftIcon, sortOrder: nextSortOrder))
            try? modelContext.save()
            dismiss()

        case .edit(let category):
            let oldName = category.name
            guard trimmed == oldName || !existingNames.contains(trimmed) else {
                errorMessage = "Ya existe una categoría con ese nombre"
                return
            }
            category.name = trimmed
            category.systemIconName = draftIcon
            if trimmed != oldName {
                var descriptor = FetchDescriptor<Budget>(predicate: #Predicate { $0.categoryName == oldName })
                descriptor.fetchLimit = 1
                if let budget = try? modelContext.fetch(descriptor).first {
                    budget.categoryName = trimmed
                }
            }
            try? modelContext.save()
            dismiss()
        }
    }
}

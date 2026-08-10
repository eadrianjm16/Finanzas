import SwiftUI
import SwiftData

struct CategoryReorderView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    @State private var orderedCategories: [Category] = []

    var body: some View {
        List {
            ForEach(orderedCategories) { category in
                Label(category.name, systemImage: category.systemIconName)
            }
            .onMove(perform: move)
        }
        .navigationTitle("Reordenar")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
        .task {
            orderedCategories = categories
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        orderedCategories.move(fromOffsets: source, toOffset: destination)
        for (index, category) in orderedCategories.enumerated() {
            category.sortOrder = index
        }
        try? modelContext.save()
    }
}

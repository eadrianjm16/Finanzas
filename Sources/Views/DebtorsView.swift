import SwiftUI
import SwiftData

struct DebtorsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Debtor.name) private var debtors: [Debtor]
    @State private var showingAddDebtor = false
    @State private var newDebtorName = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                ForEach(debtors) { debtor in
                    NavigationLink {
                        DebtorDetailView(debtor: debtor)
                    } label: {
                        HStack {
                            Text(debtor.name)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(balanceLabel(balance(debtor)))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(balanceText(debtor))
                                    .foregroundStyle(balanceColor(balance(debtor)))
                            }
                        }
                    }
                }
                .onDelete { offsets in
                    for index in offsets { modelContext.delete(debtors[index]) }
                    try? modelContext.save()
                }
            }
            .navigationTitle("Cobros")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        newDebtorName = ""
                        showingAddDebtor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .overlay {
                if debtors.isEmpty {
                    ContentUnavailableView(
                        "Sin deudores",
                        systemImage: "person.2",
                        description: Text("Añade una persona con el botón +")
                    )
                }
            }
            .alert("Nueva persona", isPresented: $showingAddDebtor) {
                TextField("Nombre", text: $newDebtorName)
                Button("Cancelar", role: .cancel) {}
                Button("Añadir") { addDebtor() }
            }
            .alert("Aviso", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func addDebtor() {
        let trimmed = newDebtorName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        guard !debtors.contains(where: { $0.name == trimmed }) else {
            errorMessage = "Ya existe una persona con ese nombre"
            return
        }
        modelContext.insert(Debtor(name: trimmed))
        try? modelContext.save()
    }

    private func balance(_ debtor: Debtor) -> Decimal {
        debtor.entries.reduce(Decimal(0)) { $0 + $1.amount }
    }

    private func balanceText(_ debtor: Debtor) -> String {
        let value = abs(balance(debtor))
        return String(format: "%.2f €", NSDecimalNumber(decimal: value).doubleValue)
    }

    private func balanceLabel(_ value: Decimal) -> String {
        if value > 0 { return "Te debe" }
        if value < 0 { return "Le debes" }
        return "Al día"
    }

    private func balanceColor(_ value: Decimal) -> Color {
        if value > 0 { return .red }
        if value < 0 { return .orange }
        return .secondary
    }
}

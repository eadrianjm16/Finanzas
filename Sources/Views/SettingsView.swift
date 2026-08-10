import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showingRecalculateConfirm = false
    @State private var recalculateResultMessage: String?

    var body: some View {
        NavigationStack {
            List {
                NavigationLink("Categorías") {
                    CategoriesSettingsView()
                }
                Section {
                    Button("Recalcular categorías de movimientos existentes") {
                        showingRecalculateConfirm = true
                    }
                } footer: {
                    Text("Vuelve a categorizar automáticamente los movimientos que no hayas categorizado a mano, usando las reglas actuales.")
                }
            }
            .navigationTitle("Ajustes")
            .confirmationDialog(
                "¿Recalcular categorías?",
                isPresented: $showingRecalculateConfirm,
                titleVisibility: .visible
            ) {
                Button("Recalcular") {
                    let store = TransactionsStore(modelContext: modelContext, client: EnableBankingClient())
                    let count = store.recategorizeUncategorized()
                    DispatchQueue.main.async {
                        recalculateResultMessage = "Se actualizaron \(count) movimiento\(count == 1 ? "" : "s")."
                    }
                }
            } message: {
                Text("No se tocan los movimientos que ya categorizaste a mano.")
            }
            .alert("Listo", isPresented: Binding(
                get: { recalculateResultMessage != nil },
                set: { if !$0 { recalculateResultMessage = nil } }
            )) {
                Button("OK") { recalculateResultMessage = nil }
            } message: {
                Text(recalculateResultMessage ?? "")
            }
        }
    }
}

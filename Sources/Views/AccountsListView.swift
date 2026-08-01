import SwiftUI
import SwiftData

struct AccountsListView: View {
    @EnvironmentObject private var appState: AppState
    @Query(sort: \LinkedAccount.linkedAt) private var accounts: [LinkedAccount]
    @State private var showingBankPicker = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(accounts) { account in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(account.displayName)
                            .font(.headline)
                        if let amount = account.lastBalanceAmount, let currency = account.lastBalanceCurrency {
                            Text("\(amount) \(currency)")
                                .font(.title2.bold())
                        } else {
                            Text("Sin saldo todavía")
                                .foregroundStyle(.secondary)
                        }
                        if let iban = account.iban {
                            Text(iban)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onDelete(perform: delete)
            }
            .navigationTitle("Cuentas")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingBankPicker = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .refreshable {
                await appState.refreshAll()
            }
            .sheet(isPresented: $showingBankPicker) {
                BankPickerView()
            }
            .overlay {
                if accounts.isEmpty {
                    ContentUnavailableView(
                        "Sin cuentas",
                        systemImage: "building.columns",
                        description: Text("Añade un banco con el botón +")
                    )
                }
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            appState.unlink(accounts[index])
        }
    }
}

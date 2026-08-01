import SwiftUI
import SwiftData

struct AccountsListView: View {
    @EnvironmentObject private var appState: AppState
    @Query(sort: \BankConnection.linkedAt) private var connections: [BankConnection]
    @State private var showingBankPicker = false

    private var allVisibleAccounts: [LinkedAccount] {
        connections.flatMap(\.accounts).filter { $0.isVisible }
    }

    var body: some View {
        NavigationStack {
            List {
                if !connections.isEmpty {
                    Section {
                        HStack {
                            Text("Saldo total")
                                .font(.headline)
                            Spacer()
                            Text(grandTotalText)
                                .font(.headline)
                        }
                    }
                }

                ForEach(connections) { connection in
                    Section {
                        ForEach(connection.accounts.filter { $0.isVisible }) { account in
                            AccountSummaryRow(account: account)
                        }
                    } header: {
                        NavigationLink {
                            BankDetailView(connection: connection)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(connection.aspspName)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.primary)
                                    if let refreshedAt = mostRecentRefresh(connection) {
                                        Text("Actualizado \(refreshedAt, style: .relative)")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text(totalBalanceText(connection))
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }
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
                if connections.isEmpty {
                    ContentUnavailableView(
                        "Sin cuentas",
                        systemImage: "building.columns",
                        description: Text("Añade un banco con el botón +")
                    )
                }
            }
        }
    }

    private var grandTotalText: String {
        let accounts = allVisibleAccounts.filter { $0.isBalanceVisible }
        guard let currency = accounts.first(where: { $0.lastBalanceCurrency != nil })?.lastBalanceCurrency else {
            return "Sin saldo todavía"
        }
        let sum = accounts.reduce(Decimal(0)) { partial, account in
            guard let amount = account.lastBalanceAmount.flatMap({ Decimal(string: $0) }) else { return partial }
            return partial + amount
        }
        return "\(sum) \(currency)"
    }

    private func totalBalanceText(_ connection: BankConnection) -> String {
        let visible = connection.accounts.filter { $0.isVisible && $0.isBalanceVisible }
        guard let currency = visible.first(where: { $0.lastBalanceCurrency != nil })?.lastBalanceCurrency else {
            return "Sin saldo todavía"
        }
        let sum = visible.reduce(Decimal(0)) { partial, account in
            guard let amount = account.lastBalanceAmount.flatMap({ Decimal(string: $0) }) else { return partial }
            return partial + amount
        }
        return "\(sum) \(currency)"
    }

    private func mostRecentRefresh(_ connection: BankConnection) -> Date? {
        connection.accounts.compactMap(\.lastBalanceRefreshedAt).max()
    }
}

private struct AccountSummaryRow: View {
    let account: LinkedAccount

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(displayNameWithSuffix)
                    .font(.subheadline)
                if let refreshedAt = account.lastBalanceRefreshedAt {
                    Text("Actualizado \(refreshedAt, style: .relative)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(balanceText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var balanceText: String {
        guard account.isBalanceVisible else { return "•••••" }
        guard let amount = account.lastBalanceAmount, let currency = account.lastBalanceCurrency else {
            return "Sin saldo"
        }
        return "\(amount) \(currency)"
    }

    /// Enable Banking suele devolver el nombre del titular como account.name,
    /// igual para todas las cuentas de un mismo banco — no sirve para
    /// distinguirlas. Se añaden los últimos 4 dígitos del IBAN, como hace Fintonic.
    private var displayNameWithSuffix: String {
        guard let iban = account.iban, iban.count >= 4 else { return account.displayName }
        return "\(account.displayName) (\(iban.suffix(4)))"
    }
}

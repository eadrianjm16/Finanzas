import SwiftUI
import SwiftData

struct BankDetailView: View {
    @Bindable var connection: BankConnection
    @EnvironmentObject private var appState: AppState
    @State private var showingDeleteConfirm = false

    var body: some View {
        List {
            ForEach(connection.accounts) { account in
                AccountRow(account: account)
                    .swipeActions(edge: .trailing) {
                        Button {
                            Task { await appState.refreshConnection(connection) }
                        } label: {
                            Label("Actualizar", systemImage: "arrow.clockwise")
                        }
                        .tint(.blue)
                    }
            }
        }
        .navigationTitle(connection.aspspName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        Task { await appState.refreshConnection(connection) }
                    } label: {
                        Label("Actualizar", systemImage: "arrow.clockwise")
                    }
                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        Label("Eliminar entidad", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog(
            "¿Eliminar \(connection.aspspName)?",
            isPresented: $showingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Eliminar y borrar historial", role: .destructive) {
                appState.unlink(connection)
            }
        } message: {
            Text("Se eliminará el historial de movimientos de este banco. Si lo vuelves a conectar, empezará de cero.")
        }
    }
}

private struct AccountRow: View {
    @Bindable var account: LinkedAccount

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(account.displayName)
                    .font(.headline)
                Spacer()
                if account.isVisible {
                    Text(balanceText)
                        .font(.title3.bold())
                }
            }
            if let iban = account.iban {
                Text(iban)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Toggle("Ver mi cuenta", isOn: $account.isVisible)
            if account.isVisible {
                Toggle("Ver saldo", isOn: $account.isBalanceVisible)
            }
        }
        .padding(.vertical, 4)
        .opacity(account.isVisible ? 1 : 0.5)
    }

    private var balanceText: String {
        guard account.isBalanceVisible else { return "•••••" }
        guard let amount = account.lastBalanceAmount, let currency = account.lastBalanceCurrency else {
            return "Sin saldo todavía"
        }
        return "\(amount) \(currency)"
    }
}

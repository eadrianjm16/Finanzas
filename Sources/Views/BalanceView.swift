import SwiftUI

struct BalanceView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text(appState.bankDisplayName)
                .font(.headline)
                .foregroundStyle(.secondary)
            if let balance = appState.balance {
                Text(formatted(balance))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
            } else {
                Text("Sin datos de saldo")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Desconectar", role: .destructive) {
                appState.disconnect()
            }
            .padding(.bottom, 40)
        }
    }

    private func formatted(_ balance: AccountBalance) -> String {
        "\(balance.balanceAmount.amount) \(balance.balanceAmount.currency)"
    }
}

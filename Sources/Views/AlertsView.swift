import SwiftUI
import SwiftData

struct AlertsView: View {
    @Query private var transactions: [Transaction]
    @Query private var budgets: [Budget]
    @Query private var connections: [BankConnection] // sin usar: fuerza reevaluación al cambiar isVisible en BankDetailView

    private var alerts: [AlertsEngine.Alert] {
        AlertsEngine.evaluate(transactions: transactions, budgets: budgets)
    }

    var body: some View {
        NavigationStack {
            List(alerts) { alert in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: alert.icon)
                        .foregroundStyle(.orange)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(alert.title)
                            .font(.subheadline.bold())
                        Text(alert.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Alertas")
            .overlay {
                if alerts.isEmpty {
                    ContentUnavailableView(
                        "Sin alertas",
                        systemImage: "bell",
                        description: Text("Aquí verás avisos de presupuestos, posibles duplicados y comisiones")
                    )
                }
            }
        }
    }
}

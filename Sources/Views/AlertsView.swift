import SwiftUI
import SwiftData

struct AlertsView: View {
    @Query private var transactions: [Transaction]
    @Query private var budgets: [Budget]
    @Query private var connections: [BankConnection] // sin usar: fuerza reevaluación al cambiar isVisible en BankDetailView
    @State private var dismissedIDs: Set<String> = []

    private static let dismissedIDsKey = "AlertsView.dismissedIDs"

    private var allAlerts: [AlertsEngine.Alert] {
        AlertsEngine.evaluate(transactions: transactions, budgets: budgets)
    }

    private var visibleAlerts: [AlertsEngine.Alert] {
        allAlerts.filter { !dismissedIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            List(visibleAlerts) { alert in
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
                    Spacer()
                    Button {
                        dismiss(alert.id)
                    } label: {
                        Image(systemName: "checkmark.circle")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
                .swipeActions(edge: .trailing) {
                    Button {
                        dismiss(alert.id)
                    } label: {
                        Label("Descartar", systemImage: "checkmark")
                    }
                    .tint(.green)
                }
            }
            .navigationTitle("Alertas")
            .overlay {
                if visibleAlerts.isEmpty {
                    ContentUnavailableView(
                        "Sin alertas",
                        systemImage: "bell",
                        description: Text("Aquí verás avisos de presupuestos, posibles duplicados y comisiones")
                    )
                }
            }
            .onAppear { loadDismissed() }
        }
    }

    private func dismiss(_ id: String) {
        dismissedIDs.insert(id)
        UserDefaults.standard.set(Array(dismissedIDs), forKey: Self.dismissedIDsKey)
    }

    private func loadDismissed() {
        let stored = UserDefaults.standard.stringArray(forKey: Self.dismissedIDsKey) ?? []
        dismissedIDs = Set(stored)
    }
}

import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            AccountsListView()
                .tabItem { Label("Cuentas", systemImage: "building.columns") }
            TransactionsListView()
                .tabItem { Label("Movimientos", systemImage: "list.bullet") }
            BudgetsView()
                .tabItem { Label("Presupuestos", systemImage: "chart.pie") }
            AlertsView()
                .tabItem { Label("Alertas", systemImage: "bell") }
            SettingsView()
                .tabItem { Label("Ajustes", systemImage: "gearshape") }
        }
    }
}

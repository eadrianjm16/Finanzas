import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            AccountsListView()
                .tabItem { Label("Cuentas", systemImage: "building.columns") }
            TransactionsListView()
                .tabItem { Label("Movimientos", systemImage: "list.bullet") }
            AnalysisView()
                .tabItem { Label("Análisis", systemImage: "chart.bar") }
            BudgetsView()
                .tabItem { Label("Presupuestos", systemImage: "chart.pie") }
            DebtorsView()
                .tabItem { Label("Cobros", systemImage: "person.2") }
            AlertsView()
                .tabItem { Label("Alertas", systemImage: "bell") }
            SettingsView()
                .tabItem { Label("Ajustes", systemImage: "gearshape") }
        }
    }
}

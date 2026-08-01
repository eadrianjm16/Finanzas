import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            AccountsListView()
                .tabItem { Label("Cuentas", systemImage: "building.columns") }
            TransactionsListView()
                .tabItem { Label("Movimientos", systemImage: "list.bullet") }
        }
    }
}

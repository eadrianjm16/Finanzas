import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink("Categorías") {
                    CategoriesSettingsView()
                }
            }
            .navigationTitle("Ajustes")
        }
    }
}

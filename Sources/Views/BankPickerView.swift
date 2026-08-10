import SwiftUI

struct BankPickerView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var aspsps: [ASPSP] = []
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var loadError: String?

    private var filtered: [ASPSP] {
        guard !searchText.isEmpty else { return aspsps }
        return aspsps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if let loadError {
                    Text(loadError)
                        .foregroundStyle(.secondary)
                        .padding()
                } else {
                    List(filtered) { aspsp in
                        Button {
                            appState.connectBank(aspsp: aspsp)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                if let logo = aspsp.logo, let url = URL(string: logo) {
                                    AsyncImage(url: url) { image in
                                        image.resizable().scaledToFit()
                                    } placeholder: {
                                        Color.clear
                                    }
                                    .frame(width: 32, height: 32)
                                }
                                Text(aspsp.name)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                    .searchable(text: $searchText, prompt: "Buscar banco")
                }
            }
            .navigationTitle("Elige tu banco")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .task { await load() }
        }
    }

    private func load() async {
        isLoading = true
        do {
            aspsps = try await appState.listASPSPs(country: "ES").sorted { $0.name < $1.name }
        } catch {
            loadError = "No se pudo cargar la lista de bancos."
        }
        isLoading = false
    }
}

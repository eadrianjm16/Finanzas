import SwiftUI

struct ConnectingView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text(appState.statusMessage)
                .foregroundStyle(.secondary)
        }
    }
}

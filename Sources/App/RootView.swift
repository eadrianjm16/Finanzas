import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            switch appState.stage {
            case .onboarding:
                OnboardingView()
            case .connecting:
                ConnectingView()
            case .main:
                MainTabView()
            }
        }
        .alert(
            "Error",
            isPresented: $appState.showError,
            presenting: appState.errorMessage
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { message in
            Text(message)
        }
    }
}

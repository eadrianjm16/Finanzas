import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "eurosign.circle")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("Mis Finanzas")
                .font(.largeTitle.bold())
            Text("Conecta tu cuenta del Banco Santander para ver tu saldo.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
            Spacer()
            Button {
                appState.connectBank()
            } label: {
                Text("Conectar con Banco Santander")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
    }
}

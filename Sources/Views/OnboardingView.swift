import SwiftUI

struct OnboardingView: View {
    @State private var showingBankPicker = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "eurosign.circle")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("Mis Finanzas")
                .font(.largeTitle.bold())
            Text("Conecta tu primera cuenta bancaria para ver tu saldo y tus movimientos.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
            Spacer()
            Button {
                showingBankPicker = true
            } label: {
                Text("Conectar banco")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
        .sheet(isPresented: $showingBankPicker) {
            BankPickerView()
        }
    }
}

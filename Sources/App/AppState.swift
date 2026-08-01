import Foundation

enum AppStage {
    case onboarding
    case connecting
    case connected
}

@MainActor
final class AppState: ObservableObject {
    @Published var stage: AppStage = .onboarding
    @Published var statusMessage: String = ""
    @Published var bankDisplayName: String = ""
    @Published var balance: AccountBalance?
    @Published var showError = false
    @Published var errorMessage: String?

    private let client = EnableBankingClient()
    private let webAuth = WebAuthenticator()
    private let sessionStore = BankSessionStore()

    init() {
        if let saved = sessionStore.load() {
            bankDisplayName = saved.bankName
            Task { await refreshBalance(accountUID: saved.accountUID) }
        }
    }

    func connectBank() {
        Task {
            do {
                stage = .connecting
                statusMessage = "Buscando Banco Santander…"
                let aspsp = try await client.findASPSP(matching: "santander", country: "ES")
                bankDisplayName = aspsp.name

                statusMessage = "Abriendo autorización del banco…"
                let expectedState = UUID().uuidString
                let authURL = try await client.startAuthorization(aspsp: aspsp, state: expectedState)

                let callbackURL = try await webAuth.authenticate(url: authURL, callbackScheme: EnableBankingConfig.redirectScheme)

                if let error = callbackURL.queryItem(named: "error") {
                    throw EnableBankingError.authorizationFailed(callbackURL.queryItem(named: "error_description") ?? error)
                }
                if let returnedState = callbackURL.queryItem(named: "state"), returnedState != expectedState {
                    throw EnableBankingError.stateMismatch
                }
                guard let code = callbackURL.queryItem(named: "code") else {
                    throw EnableBankingError.missingAuthorizationCode
                }

                statusMessage = "Creando sesión…"
                let session = try await client.createSession(code: code)
                guard let account = session.accounts.first else {
                    throw EnableBankingError.noAccounts
                }

                sessionStore.save(sessionID: session.sessionID, accountUID: account.uid, bankName: aspsp.name)
                await refreshBalance(accountUID: account.uid)
            } catch {
                stage = .onboarding
                present(error)
            }
        }
    }

    func disconnect() {
        sessionStore.clear()
        balance = nil
        bankDisplayName = ""
        stage = .onboarding
    }

    private func refreshBalance(accountUID: String) async {
        do {
            stage = .connecting
            statusMessage = "Consultando saldo…"
            let balances = try await client.fetchBalances(accountUID: accountUID)
            balance = balances.first
            stage = .connected
        } catch {
            stage = .onboarding
            present(error)
        }
    }

    private func present(_ error: Error) {
        errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        showError = true
    }
}

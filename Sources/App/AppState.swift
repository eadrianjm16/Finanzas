import Foundation

enum AppStage {
    case onboarding
    case connecting
    case main
}

@MainActor
final class AppState: ObservableObject {
    @Published var stage: AppStage = .onboarding
    @Published var statusMessage: String = ""
    @Published var showError = false
    @Published var errorMessage: String?

    private let client: EnableBankingClient
    private let webAuth = WebAuthenticator()
    private let accountsStore: AccountsStore
    private let transactionsStore: TransactionsStore

    init(client: EnableBankingClient, accountsStore: AccountsStore, transactionsStore: TransactionsStore) {
        self.client = client
        self.accountsStore = accountsStore
        self.transactionsStore = transactionsStore
    }

    func bootstrap() async {
        let connections = (try? accountsStore.allConnections()) ?? []
        stage = connections.isEmpty ? .onboarding : .main
    }

    func listASPSPs(country: String) async throws -> [ASPSP] {
        try await client.listASPSPs(country: country)
    }

    func connectBank(aspsp: ASPSP) {
        Task {
            do {
                stage = .connecting
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
                let connection = try accountsStore.linkAccounts(session: session, aspsp: aspsp)

                statusMessage = "Consultando saldo…"
                for account in connection.accounts {
                    try? await accountsStore.refreshBalance(account)
                }

                statusMessage = "Trayendo movimientos…"
                for account in connection.accounts {
                    try? await transactionsStore.sync(account: account)
                }

                stage = .main
            } catch {
                await bootstrap()
                present(error)
            }
        }
    }

    func refreshConnection(_ connection: BankConnection) async {
        for account in connection.accounts {
            try? await accountsStore.refreshBalance(account)
            try? await transactionsStore.sync(account: account)
        }
    }

    func unlink(_ connection: BankConnection) {
        accountsStore.deleteConnection(connection)
        Task { await bootstrap() }
    }

    func refreshAll() async {
        guard let accounts = try? accountsStore.allAccounts() else { return }
        for account in accounts {
            try? await accountsStore.refreshBalance(account)
            try? await transactionsStore.sync(account: account)
        }
    }

    private func present(_ error: Error) {
        errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        showError = true
    }
}

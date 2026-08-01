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

    private let client = GoCardlessClient()
    private let webAuth = WebAuthenticator()
    private let sessionStore = BankSessionStore()

    init() {
        if let saved = sessionStore.load() {
            bankDisplayName = saved.bankName
            Task { await refreshBalance(accountID: saved.accountUID) }
        }
    }

    func connectBank() {
        Task {
            do {
                stage = .connecting
                statusMessage = "Buscando Banco Santander…"
                let institution = try await client.findInstitution(matching: "santander", country: "ES")
                bankDisplayName = institution.name

                statusMessage = "Preparando autorización…"
                let agreementID = try await client.createAgreement(institutionId: institution.id)
                let requisition = try await client.createRequisition(
                    institutionId: institution.id,
                    agreement: agreementID,
                    reference: UUID().uuidString
                )

                statusMessage = "Abriendo autorización del banco…"
                _ = try await webAuth.authenticate(url: requisition.link, callbackScheme: GoCardlessConfig.redirectScheme)

                statusMessage = "Verificando autorización…"
                var detail = try await client.getRequisition(id: requisition.id)
                if detail.accounts.isEmpty {
                    try await Task.sleep(nanoseconds: 2_000_000_000)
                    detail = try await client.getRequisition(id: requisition.id)
                }
                guard let accountID = detail.accounts.first else {
                    if detail.status != "LN" {
                        throw GoCardlessError.requisitionNotLinked(status: detail.status)
                    }
                    throw GoCardlessError.noAccounts
                }

                sessionStore.save(accountUID: accountID, bankName: institution.name)
                await refreshBalance(accountID: accountID)
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

    private func refreshBalance(accountID: String) async {
        do {
            stage = .connecting
            statusMessage = "Consultando saldo…"
            let balances = try await client.fetchBalances(accountID: accountID)
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

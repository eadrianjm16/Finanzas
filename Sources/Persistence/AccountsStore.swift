import Foundation
import SwiftData

@MainActor
final class AccountsStore {
    private let modelContext: ModelContext
    private let client: EnableBankingClient
    private let sessionStore: BankSessionStore

    init(modelContext: ModelContext, client: EnableBankingClient, sessionStore: BankSessionStore) {
        self.modelContext = modelContext
        self.client = client
        self.sessionStore = sessionStore
    }

    @discardableResult
    func linkAccount(session: SessionResponse, aspsp: ASPSP) throws -> LinkedAccount {
        guard let account = session.accounts.first else {
            throw EnableBankingError.noAccounts
        }
        sessionStore.save(sessionID: session.sessionID, accountUID: account.uid)

        // Reautorizar una cuenta ya vinculada (p. ej. para ampliar el scope de
        // consentimiento) debe actualizar la fila existente, no duplicarla —
        // @Attribute(.unique) no hace upsert automático al insertar un nuevo
        // objeto en memoria con el mismo accountUID.
        let targetUID = account.uid
        var descriptor = FetchDescriptor<LinkedAccount>(predicate: #Predicate { $0.accountUID == targetUID })
        descriptor.fetchLimit = 1
        if let existing = try modelContext.fetch(descriptor).first {
            existing.aspspName = aspsp.name
            existing.aspspCountry = aspsp.country
            existing.iban = account.accountID?.iban
            existing.lastSyncedAt = nil // fuerza un backfill completo de movimientos tras reautorizar
            try modelContext.save()
            return existing
        }

        let linked = LinkedAccount(
            accountUID: account.uid,
            aspspName: aspsp.name,
            aspspCountry: aspsp.country,
            displayName: aspsp.name,
            iban: account.accountID?.iban
        )
        modelContext.insert(linked)
        try modelContext.save()
        return linked
    }

    func refreshBalance(_ account: LinkedAccount) async throws {
        let balances = try await client.fetchBalances(accountUID: account.accountUID)
        guard let balance = balances.available else { return }
        account.lastBalanceAmount = balance.balanceAmount.amount
        account.lastBalanceCurrency = balance.balanceAmount.currency
        // lastSyncedAt es el checkpoint de TransactionsStore.sync (marca hasta
        // dónde se trajeron movimientos) — no tocarlo aquí, o sync() cree que
        // ya sincronizó "ahora mismo" y pida transacciones de una ventana vacía.
        try modelContext.save()
    }

    func delete(_ account: LinkedAccount) {
        sessionStore.delete(accountUID: account.accountUID)
        modelContext.delete(account)
        try? modelContext.save()
    }

    func all() throws -> [LinkedAccount] {
        try modelContext.fetch(FetchDescriptor<LinkedAccount>(sortBy: [SortDescriptor(\.linkedAt)]))
    }
}

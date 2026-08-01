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
    func linkAccounts(session: SessionResponse, aspsp: ASPSP) throws -> BankConnection {
        guard !session.accounts.isEmpty else {
            throw EnableBankingError.noAccounts
        }

        let connectionKey = "\(aspsp.name.trimmingCharacters(in: .whitespaces))|\(aspsp.country.trimmingCharacters(in: .whitespaces))"
        var connDescriptor = FetchDescriptor<BankConnection>(predicate: #Predicate { $0.key == connectionKey })
        connDescriptor.fetchLimit = 1
        let connection: BankConnection
        if let existingConnection = try modelContext.fetch(connDescriptor).first {
            connection = existingConnection
        } else {
            let newConnection = BankConnection(aspspName: aspsp.name, aspspCountry: aspsp.country)
            modelContext.insert(newConnection)
            connection = newConnection
        }

        for account in session.accounts {
            sessionStore.save(sessionID: session.sessionID, accountUID: account.uid)

            // Reautorizar una cuenta ya vinculada (p. ej. para ampliar el scope de
            // consentimiento) debe actualizar la fila existente, no duplicarla —
            // @Attribute(.unique) no hace upsert automático al insertar un nuevo
            // objeto en memoria con el mismo accountUID.
            let targetUID = account.uid
            var descriptor = FetchDescriptor<LinkedAccount>(predicate: #Predicate { $0.accountUID == targetUID })
            descriptor.fetchLimit = 1
            if let existing = try modelContext.fetch(descriptor).first {
                existing.iban = account.accountID?.iban
                existing.connection = connection
                existing.lastSyncedAt = nil // fuerza un backfill completo de movimientos tras reautorizar
            } else {
                let linked = LinkedAccount(
                    accountUID: account.uid,
                    displayName: account.name ?? aspsp.name,
                    iban: account.accountID?.iban
                )
                linked.connection = connection
                modelContext.insert(linked)
            }
        }

        try modelContext.save()
        return connection
    }

    func refreshBalance(_ account: LinkedAccount) async throws {
        let balances = try await client.fetchBalances(accountUID: account.accountUID)
        guard let balance = balances.available else { return }
        account.lastBalanceAmount = balance.balanceAmount.amount
        account.lastBalanceCurrency = balance.balanceAmount.currency
        account.lastBalanceRefreshedAt = .now
        // lastSyncedAt es el checkpoint de TransactionsStore.sync (marca hasta
        // dónde se trajeron movimientos) — no tocarlo aquí, o sync() cree que
        // ya sincronizó "ahora mismo" y pida transacciones de una ventana vacía.
        try modelContext.save()
    }

    func deleteConnection(_ connection: BankConnection) {
        // No confiar solo en el cascade de dos niveles (BankConnection ->
        // LinkedAccount -> Transaction): en SwiftData de iOS 17.0 GA el cascade
        // a través de una relación nieta no siempre se propaga de forma
        // fiable si no está materializada. Se borra explícitamente.
        for account in connection.accounts {
            for transaction in account.transactions {
                modelContext.delete(transaction)
            }
            sessionStore.delete(accountUID: account.accountUID)
            modelContext.delete(account)
        }
        modelContext.delete(connection)
        try? modelContext.save()
    }

    func allConnections() throws -> [BankConnection] {
        try modelContext.fetch(FetchDescriptor<BankConnection>(sortBy: [SortDescriptor(\.linkedAt)]))
    }

    func allAccounts() throws -> [LinkedAccount] {
        try allConnections().flatMap(\.accounts)
    }
}

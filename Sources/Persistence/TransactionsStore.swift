import Foundation
import SwiftData
import CryptoKit

@MainActor
final class TransactionsStore {
    private let modelContext: ModelContext
    private let client: EnableBankingClient

    init(modelContext: ModelContext, client: EnableBankingClient) {
        self.modelContext = modelContext
        self.client = client
    }

    private static let backfillWindow: TimeInterval = 90 * 24 * 3600

    private static let dateParser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// Trae movimientos nuevos desde el último sync (o desde 90 días atrás si
    /// es la primera vez) y los inserta de forma idempotente: entryReference
    /// (o una clave alternativa derivada si el banco no lo da) evita duplicados
    /// entre syncs repetidos. Solo asigna categoría a movimientos nuevos —
    /// nunca toca uno que el usuario ya categorizó a mano.
    func sync(account: LinkedAccount) async throws {
        let from = account.lastSyncedAt ?? Date().addingTimeInterval(-Self.backfillWindow)
        let raw = try await client.fetchAllTransactions(accountUID: account.accountUID, dateFrom: from, dateTo: .now)

        for ebTx in raw {
            let key = ebTx.entryReference ?? Self.fallbackKey(for: ebTx)
            guard try existing(entryReference: key) == nil else { continue }

            let indicator = ebTx.creditDebitIndicator
            let amountValue = Decimal(string: ebTx.transactionAmount.amount) ?? 0
            let remittance = (ebTx.remittanceInformation ?? []).joined(separator: "\n")
            let counterparty = indicator == "CRDT" ? ebTx.debtor?.name : ebTx.creditor?.name

            let tx = Transaction(
                entryReference: key,
                amount: amountValue,
                currency: ebTx.transactionAmount.currency,
                creditDebitIndicator: indicator,
                bookingDate: ebTx.bookingDate.flatMap(Self.dateParser.date(from:)) ?? .now,
                valueDate: ebTx.valueDate.flatMap(Self.dateParser.date(from:)),
                remittanceInformation: remittance,
                counterpartyName: counterparty,
                merchantCategoryCode: ebTx.merchantCategoryCode,
                status: ebTx.status
            )
            tx.account = account
            tx.category = categoryFor(name: CategorizationEngine.suggestCategory(
                mcc: ebTx.merchantCategoryCode,
                remittanceInformation: remittance,
                creditDebitIndicator: indicator
            ))
            modelContext.insert(tx)
        }

        account.lastSyncedAt = .now
        try modelContext.save()
    }

    private func existing(entryReference: String) throws -> Transaction? {
        var descriptor = FetchDescriptor<Transaction>(predicate: #Predicate { $0.entryReference == entryReference })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func categoryFor(name: String) -> Category? {
        var descriptor = FetchDescriptor<Category>(predicate: #Predicate { $0.name == name })
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    private static func fallbackKey(for tx: EBTransaction) -> String {
        let raw = "\(tx.bookingDate ?? "")|\(tx.transactionAmount.amount)|\(tx.transactionAmount.currency)|\((tx.remittanceInformation ?? []).joined())"
        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

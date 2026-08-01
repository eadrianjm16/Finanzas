import Foundation
import SwiftData

@Model
final class BankConnection {
    @Attribute(.unique) var key: String
    var aspspName: String
    var aspspCountry: String
    var linkedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \LinkedAccount.connection)
    var accounts: [LinkedAccount] = []

    init(aspspName: String, aspspCountry: String, linkedAt: Date = .now) {
        self.aspspName = aspspName
        self.aspspCountry = aspspCountry
        self.key = "\(aspspName.trimmingCharacters(in: .whitespaces))|\(aspspCountry.trimmingCharacters(in: .whitespaces))"
        self.linkedAt = linkedAt
    }
}

@Model
final class LinkedAccount {
    @Attribute(.unique) var accountUID: String
    var displayName: String
    var iban: String?
    var lastSyncedAt: Date?
    var lastBalanceAmount: String?
    var lastBalanceCurrency: String?
    var lastBalanceRefreshedAt: Date?
    var linkedAt: Date
    var isVisible: Bool = true
    var isBalanceVisible: Bool = true

    var connection: BankConnection?

    @Relationship(deleteRule: .cascade, inverse: \Transaction.account)
    var transactions: [Transaction] = []

    init(
        accountUID: String,
        displayName: String,
        iban: String?,
        linkedAt: Date = .now
    ) {
        self.accountUID = accountUID
        self.displayName = displayName
        self.iban = iban
        self.linkedAt = linkedAt
    }
}

@Model
final class Transaction {
    @Attribute(.unique) var entryReference: String
    var amount: Decimal
    var currency: String
    var creditDebitIndicator: String
    var bookingDate: Date
    var valueDate: Date?
    var remittanceInformation: String
    var counterpartyName: String?
    var merchantCategoryCode: String?
    var status: String?
    var isUserCategorized: Bool = false

    var account: LinkedAccount?
    var category: Category?

    init(
        entryReference: String,
        amount: Decimal,
        currency: String,
        creditDebitIndicator: String,
        bookingDate: Date,
        valueDate: Date?,
        remittanceInformation: String,
        counterpartyName: String?,
        merchantCategoryCode: String?,
        status: String?
    ) {
        self.entryReference = entryReference
        self.amount = amount
        self.currency = currency
        self.creditDebitIndicator = creditDebitIndicator
        self.bookingDate = bookingDate
        self.valueDate = valueDate
        self.remittanceInformation = remittanceInformation
        self.counterpartyName = counterpartyName
        self.merchantCategoryCode = merchantCategoryCode
        self.status = status
    }
}

@Model
final class Category {
    @Attribute(.unique) var name: String
    var systemIconName: String
    var sortOrder: Int

    @Relationship(deleteRule: .nullify, inverse: \Transaction.category)
    var transactions: [Transaction] = []

    init(name: String, systemIconName: String, sortOrder: Int) {
        self.name = name
        self.systemIconName = systemIconName
        self.sortOrder = sortOrder
    }
}

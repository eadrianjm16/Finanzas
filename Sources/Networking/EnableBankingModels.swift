import Foundation

// MARK: - ASPSPs (banks)

struct ASPSP: Codable, Identifiable, Hashable {
    let name: String
    let country: String
    let logo: String?
    let bic: String?
    let psuTypes: [String]?

    /// Solo para uso en List/ForEach — nunca se lee al reenviar el struct a la API.
    var id: String { "\(name)_\(country)" }

    enum CodingKeys: String, CodingKey {
        case name, country, logo, bic
        case psuTypes = "psu_types"
    }
}

struct ASPSPListResponse: Codable {
    let aspsps: [ASPSP]
}

// MARK: - POST /auth

struct AuthStartRequest: Encodable {
    struct Access: Encodable {
        let validUntil: String
        let balances: Bool
        let transactions: Bool
        enum CodingKeys: String, CodingKey {
            case validUntil = "valid_until"
            case balances, transactions
        }
    }

    let access: Access
    let aspsp: ASPSP
    let state: String
    let redirectURL: String
    let psuType: String

    enum CodingKeys: String, CodingKey {
        case access, aspsp, state
        case redirectURL = "redirect_url"
        case psuType = "psu_type"
    }
}

struct AuthStartResponse: Codable {
    let url: URL
}

// MARK: - POST /sessions

struct SessionRequest: Encodable {
    let code: String
}

struct AccountIdentifier: Codable {
    let iban: String?
}

struct Account: Codable {
    let uid: String
    let name: String?
    let accountID: AccountIdentifier?

    enum CodingKeys: String, CodingKey {
        case uid, name
        case accountID = "account_id"
    }
}

struct SessionResponse: Codable {
    let sessionID: String
    let accounts: [Account]

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case accounts
    }
}

// MARK: - GET /accounts/{uid}/balances

struct BalanceAmount: Codable {
    let amount: String
    let currency: String
}

struct AccountBalance: Codable {
    let balanceAmount: BalanceAmount
    let balanceType: String?
    let referenceDate: String?

    enum CodingKeys: String, CodingKey {
        case balanceAmount = "balance_amount"
        case balanceType = "balance_type"
        case referenceDate = "reference_date"
    }
}

extension Array where Element == AccountBalance {
    /// El saldo más actualizado que expone el banco. Preferimos, en orden,
    /// un disponible real con retenciones ya descontadas (XPCD/ITAV/CLAV/OPAV,
    /// códigos BalanceStatus de ISO 20022); si el banco no los expone —como
    /// Santander vía Enable Banking, que solo da OPBD/CLBD—, caemos al saldo
    /// contable acumulado (CLBD) en vez del de apertura del día (OPBD), por
    /// ser el más reciente de los dos, aunque tampoco descuenta retenciones
    /// pendientes de tarjeta no liquidadas.
    var available: AccountBalance? {
        let priority = ["XPCD", "ITAV", "CLAV", "OPAV", "CLBD"]
        for type in priority {
            if let match = first(where: { $0.balanceType == type }) {
                return match
            }
        }
        return first
    }
}

struct BalancesResponse: Codable {
    let balances: [AccountBalance]
}

// MARK: - GET /accounts/{uid}/transactions

struct EBParty: Codable {
    let name: String?
}

struct EBTransaction: Codable {
    let entryReference: String?
    let transactionAmount: BalanceAmount
    let creditDebitIndicator: String
    let bookingDate: String?
    let valueDate: String?
    let remittanceInformation: [String]?
    let creditor: EBParty?
    let debtor: EBParty?
    let merchantCategoryCode: String?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case entryReference = "entry_reference"
        case transactionAmount = "transaction_amount"
        case creditDebitIndicator = "credit_debit_indicator"
        case bookingDate = "booking_date"
        case valueDate = "value_date"
        case remittanceInformation = "remittance_information"
        case creditor, debtor
        case merchantCategoryCode = "merchant_category_code"
        case status
    }
}

struct TransactionsResponse: Codable {
    let transactions: [EBTransaction]
    let continuationKey: String?

    enum CodingKeys: String, CodingKey {
        case transactions
        case continuationKey = "continuation_key"
    }
}

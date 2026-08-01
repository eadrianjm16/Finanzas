import Foundation

// MARK: - ASPSPs (banks)

struct ASPSP: Codable {
    let name: String
    let country: String
}

struct ASPSPListResponse: Codable {
    let aspsps: [ASPSP]
}

// MARK: - POST /auth

struct AuthStartRequest: Encodable {
    struct Access: Encodable {
        let validUntil: String
        enum CodingKeys: String, CodingKey { case validUntil = "valid_until" }
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

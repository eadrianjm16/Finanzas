import Foundation

// MARK: - POST /token/new/

struct TokenRequest: Encodable {
    let secretId: String
    let secretKey: String

    enum CodingKeys: String, CodingKey {
        case secretId = "secret_id"
        case secretKey = "secret_key"
    }
}

struct TokenResponse: Decodable {
    let access: String
    let accessExpires: Int
    let refresh: String
    let refreshExpires: Int

    enum CodingKeys: String, CodingKey {
        case access
        case accessExpires = "access_expires"
        case refresh
        case refreshExpires = "refresh_expires"
    }
}

// MARK: - GET /institutions/

struct Institution: Codable {
    let id: String
    let name: String
}

// MARK: - POST /agreements/enduser/

struct AgreementRequest: Encodable {
    let institutionId: String
    let maxHistoricalDays: Int
    let accessValidForDays: Int
    let accessScope: [String]

    enum CodingKeys: String, CodingKey {
        case institutionId = "institution_id"
        case maxHistoricalDays = "max_historical_days"
        case accessValidForDays = "access_valid_for_days"
        case accessScope = "access_scope"
    }
}

struct AgreementResponse: Decodable {
    let id: String
}

// MARK: - POST /requisitions/

struct RequisitionRequest: Encodable {
    let redirect: String
    let institutionId: String
    let agreement: String
    let reference: String
    let userLanguage: String

    enum CodingKeys: String, CodingKey {
        case redirect
        case institutionId = "institution_id"
        case agreement
        case reference
        case userLanguage = "user_language"
    }
}

struct RequisitionCreateResponse: Decodable {
    let id: String
    let link: URL
}

// MARK: - GET /requisitions/{id}/

struct RequisitionDetail: Decodable {
    let id: String
    let status: String
    let accounts: [String]
}

// MARK: - GET /accounts/{id}/balances/

struct BalanceAmount: Codable {
    let amount: String
    let currency: String
}

struct AccountBalance: Codable {
    let balanceAmount: BalanceAmount
    let balanceType: String?
    let referenceDate: String?

    enum CodingKeys: String, CodingKey {
        case balanceAmount
        case balanceType
        case referenceDate
    }
}

struct BalancesResponse: Decodable {
    let balances: [AccountBalance]
}

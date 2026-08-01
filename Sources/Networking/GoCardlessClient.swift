import Foundation

enum GoCardlessError: LocalizedError {
    case institutionNotFound(query: String, available: [String])
    case requisitionNotLinked(status: String)
    case noAccounts
    case server(status: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .institutionNotFound(let query, let available):
            if available.isEmpty {
                return "No se encontró ningún banco que coincida con \"\(query)\" (la lista de bancos disponibles está vacía)."
            }
            let sample = available.prefix(40).joined(separator: ", ")
            return "No se encontró ningún banco que coincida con \"\(query)\". Bancos disponibles (\(available.count)): \(sample)"
        case .requisitionNotLinked(let status):
            return "La autorización del banco no se completó (estado: \(status))."
        case .noAccounts:
            return "No se encontraron cuentas tras autorizar el acceso."
        case .server(let status, let body):
            return "Error del servidor de GoCardless (\(status)): \(body)"
        }
    }
}

final class GoCardlessClient {
    private let urlSession: URLSession
    private var accessToken: String?
    private var accessTokenExpiry: Date?

    init(urlSession: URLSession = URLSession(configuration: .default)) {
        self.urlSession = urlSession
    }

    func findInstitution(matching query: String, country: String) async throws -> Institution {
        let url = GoCardlessConfig.baseURL
            .appendingPathComponent("institutions/")
            .appendingQuery(["country": country])
        let request = try await makeRequest(url: url)
        let institutions: [Institution] = try await send(request)
        guard let match = institutions.first(where: { $0.name.localizedCaseInsensitiveContains(query) }) else {
            throw GoCardlessError.institutionNotFound(query: query, available: institutions.map(\.name))
        }
        return match
    }

    func createAgreement(institutionId: String) async throws -> String {
        let url = GoCardlessConfig.baseURL.appendingPathComponent("agreements/enduser/")
        let body = AgreementRequest(
            institutionId: institutionId,
            maxHistoricalDays: 90,
            accessValidForDays: 90,
            accessScope: ["balances"]
        )
        let request = try await makeRequest(url: url, method: "POST", body: body)
        let response: AgreementResponse = try await send(request)
        return response.id
    }

    func createRequisition(institutionId: String, agreement: String, reference: String) async throws -> RequisitionCreateResponse {
        let url = GoCardlessConfig.baseURL.appendingPathComponent("requisitions/")
        let body = RequisitionRequest(
            redirect: GoCardlessConfig.redirectURL,
            institutionId: institutionId,
            agreement: agreement,
            reference: reference,
            userLanguage: "ES"
        )
        let request = try await makeRequest(url: url, method: "POST", body: body)
        return try await send(request)
    }

    func getRequisition(id: String) async throws -> RequisitionDetail {
        let url = GoCardlessConfig.baseURL.appendingPathComponent("requisitions/\(id)/")
        let request = try await makeRequest(url: url)
        return try await send(request)
    }

    func fetchBalances(accountID: String) async throws -> [AccountBalance] {
        let url = GoCardlessConfig.baseURL.appendingPathComponent("accounts/\(accountID)/balances/")
        let request = try await makeRequest(url: url)
        let response: BalancesResponse = try await send(request)
        return response.balances
    }

    // MARK: - Auth

    private func validAccessToken() async throws -> String {
        if let accessToken, let accessTokenExpiry, accessTokenExpiry > Date() {
            return accessToken
        }
        let url = GoCardlessConfig.baseURL.appendingPathComponent("token/new/")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(
            TokenRequest(secretId: GoCardlessConfig.secretID, secretKey: GoCardlessConfig.secretKey)
        )
        let token: TokenResponse = try await send(request)
        accessToken = token.access
        accessTokenExpiry = Date().addingTimeInterval(TimeInterval(token.accessExpires - 60))
        return token.access
    }

    private func makeRequest(url: URL, method: String = "GET", body: Encodable? = nil) async throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(try await validAccessToken())", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = try JSONEncoder().encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }

    private func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GoCardlessError.server(status: -1, body: "sin respuesta HTTP")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw GoCardlessError.server(status: http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

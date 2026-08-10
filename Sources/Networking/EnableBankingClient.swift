import Foundation

enum EnableBankingError: LocalizedError {
    case authorizationFailed(String)
    case missingAuthorizationCode
    case stateMismatch
    case noAccounts
    case server(status: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .authorizationFailed(let reason):
            return "El banco no autorizó el acceso: \(reason)"
        case .missingAuthorizationCode:
            return "El banco no devolvió un código de autorización."
        case .stateMismatch:
            return "La respuesta del banco no coincide con la solicitud original (state inválido)."
        case .noAccounts:
            return "No se encontraron cuentas tras autorizar el acceso."
        case .server(let status, let body):
            return "Error del servidor de Enable Banking (\(status)): \(body)"
        }
    }
}

final class EnableBankingClient {
    private let urlSession: URLSession

    init(urlSession: URLSession = URLSession(configuration: .default)) {
        self.urlSession = urlSession
    }

    func listASPSPs(country: String?) async throws -> [ASPSP] {
        var url = EnableBankingConfig.baseURL.appendingPathComponent("aspsps")
        if let country {
            url = url.appendingQuery(["country": country])
        }
        let response: ASPSPListResponse = try await send(makeRequest(url: url))
        return response.aspsps
    }

    func startAuthorization(aspsp: ASPSP, state: String) async throws -> URL {
        let validUntil = ISO8601DateFormatter().string(from: Date().addingTimeInterval(90 * 24 * 3600))
        let body = AuthStartRequest(
            access: .init(validUntil: validUntil, balances: true, transactions: true),
            aspsp: aspsp,
            state: state,
            redirectURL: EnableBankingConfig.redirectURL,
            psuType: "personal"
        )
        let url = EnableBankingConfig.baseURL.appendingPathComponent("auth")
        let response: AuthStartResponse = try await send(makeRequest(url: url, method: "POST", body: body))
        return response.url
    }

    func createSession(code: String) async throws -> SessionResponse {
        let url = EnableBankingConfig.baseURL.appendingPathComponent("sessions")
        return try await send(makeRequest(url: url, method: "POST", body: SessionRequest(code: code)))
    }

    func fetchBalances(accountUID: String) async throws -> [AccountBalance] {
        let url = EnableBankingConfig.baseURL.appendingPathComponent("accounts/\(accountUID)/balances")
        let response: BalancesResponse = try await send(makeRequest(url: url))
        return response.balances
    }

    struct TransactionsPage {
        let transactions: [EBTransaction]
        let continuationKey: String?
    }

    private static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    func fetchTransactions(
        accountUID: String,
        dateFrom: Date?,
        dateTo: Date?,
        continuationKey: String? = nil
    ) async throws -> TransactionsPage {
        var params: [String: String] = [:]
        if let dateFrom { params["date_from"] = Self.dateOnlyFormatter.string(from: dateFrom) }
        if let dateTo { params["date_to"] = Self.dateOnlyFormatter.string(from: dateTo) }
        if let continuationKey { params["continuation_key"] = continuationKey }

        var url = EnableBankingConfig.baseURL.appendingPathComponent("accounts/\(accountUID)/transactions")
        if !params.isEmpty {
            url = url.appendingQuery(params)
        }
        let response: TransactionsResponse = try await send(makeRequest(url: url))
        return TransactionsPage(transactions: response.transactions, continuationKey: response.continuationKey)
    }

    func fetchAllTransactions(accountUID: String, dateFrom: Date?, dateTo: Date?) async throws -> [EBTransaction] {
        var all: [EBTransaction] = []
        var key: String?
        repeat {
            let page = try await fetchTransactions(accountUID: accountUID, dateFrom: dateFrom, dateTo: dateTo, continuationKey: key)
            all += page.transactions
            key = page.continuationKey
        } while key != nil
        return all
    }

    private func makeRequest(url: URL, method: String = "GET", body: Encodable? = nil) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(try JWTSigner.makeApplicationToken())", forHTTPHeaderField: "Authorization")
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
            throw EnableBankingError.server(status: -1, body: "sin respuesta HTTP")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw EnableBankingError.server(status: http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

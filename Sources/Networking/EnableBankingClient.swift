import Foundation

enum EnableBankingError: LocalizedError {
    case aspspNotFound(String)
    case authorizationFailed(String)
    case missingAuthorizationCode
    case stateMismatch
    case noAccounts
    case server(status: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .aspspNotFound(let query):
            return "No se encontró ningún banco que coincida con \"\(query)\"."
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

    func findASPSP(matching query: String, country: String) async throws -> ASPSP {
        let url = EnableBankingConfig.baseURL
            .appendingPathComponent("aspsps")
            .appendingQuery(["country": country])
        let response: ASPSPListResponse = try await send(makeRequest(url: url))
        guard let match = response.aspsps.first(where: { $0.name.localizedCaseInsensitiveContains(query) }) else {
            throw EnableBankingError.aspspNotFound(query)
        }
        return match
    }

    func startAuthorization(aspsp: ASPSP, state: String) async throws -> URL {
        let validUntil = ISO8601DateFormatter().string(from: Date().addingTimeInterval(90 * 24 * 3600))
        let body = AuthStartRequest(
            access: .init(validUntil: validUntil),
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

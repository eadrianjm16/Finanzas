import AuthenticationServices
import UIKit

enum WebAuthenticatorError: LocalizedError {
    case cancelled

    var errorDescription: String? {
        "Se canceló la autorización con el banco."
    }
}

/// Drives the PSD2 SCA redirect flow: opens the bank's authorization page
/// in a system browser sheet and captures the `finanzasapp://callback` redirect.
final class WebAuthenticator: NSObject, ASWebAuthenticationPresentationContextProviding {
    // ASWebAuthenticationSession no se retiene a sí mismo: hay que mantener una
    // referencia fuerte mientras dure la sesión o puede liberarse (y colgarse o
    // fallar de forma intermitente, dependiendo del timing) antes de llamar al
    // completion handler.
    private var activeSession: ASWebAuthenticationSession?

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }

    @MainActor
    func authenticate(url: URL, callbackScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) { [weak self] callbackURL, error in
                self?.activeSession = nil
                if let callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: error ?? WebAuthenticatorError.cancelled)
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = true
            activeSession = session
            session.start()
        }
    }
}

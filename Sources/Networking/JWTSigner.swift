import Foundation
import Security

enum JWTSignerError: LocalizedError {
    case invalidPEM
    case keyImportFailed(String)
    case signingFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidPEM:
            return "La clave privada en Secrets.plist no tiene un formato PEM válido (PKCS#1 o PKCS#8)."
        case .keyImportFailed(let reason):
            return "No se pudo importar la clave privada: \(reason)"
        case .signingFailed(let reason):
            return "No se pudo firmar el JWT: \(reason)"
        }
    }
}

/// Builds the application-level JWT Enable Banking requires on every
/// request (RS256, signed with the app's private key, `kid` = application id).
/// Implemented with Security.framework only, no third-party crypto deps.
enum JWTSigner {
    static func makeApplicationToken() throws -> String {
        let now = Int(Date().timeIntervalSince1970)
        let header: [String: Any] = [
            "typ": "JWT",
            "alg": "RS256",
            "kid": EnableBankingConfig.applicationID
        ]
        let payload: [String: Any] = [
            "iss": "enablebanking.com",
            "aud": "api.enablebanking.com",
            "iat": now,
            "exp": now + 3600
        ]

        let headerSegment = try base64URLJSON(header)
        let payloadSegment = try base64URLJSON(payload)
        let signingInput = "\(headerSegment).\(payloadSegment)"

        let signature = try sign(signingInput)
        return "\(signingInput).\(base64URLEncode(signature))"
    }

    private static func sign(_ input: String) throws -> Data {
        let key = try privateKey()
        guard let data = input.data(using: .utf8) else {
            throw JWTSignerError.signingFailed("entrada inválida")
        }
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            key,
            .rsaSignatureMessagePKCS1v15SHA256,
            data as CFData,
            &error
        ) as Data? else {
            throw JWTSignerError.signingFailed(error?.takeRetainedValue().localizedDescription ?? "desconocido")
        }
        return signature
    }

    private static func privateKey() throws -> SecKey {
        let der = try pkcs1DER(fromPEM: EnableBankingConfig.privateKeyPEM)
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate
        ]
        var error: Unmanaged<CFError>?
        guard let key = SecKeyCreateWithData(der as CFData, attributes as CFDictionary, &error) else {
            throw JWTSignerError.keyImportFailed(error?.takeRetainedValue().localizedDescription ?? "desconocido")
        }
        return key
    }

    /// Enable Banking issues PKCS#8 PEM (`BEGIN PRIVATE KEY`). SecKeyCreateWithData
    /// wants the raw PKCS#1 RSAPrivateKey DER, so PKCS#8 needs its wrapper stripped.
    /// PKCS#1 PEM (`BEGIN RSA PRIVATE KEY`) is already in the right shape.
    private static func pkcs1DER(fromPEM pem: String) throws -> Data {
        let lines = pem.split(whereSeparator: \.isNewline).map(String.init)
        guard let beginLine = lines.first(where: { $0.hasPrefix("-----BEGIN") }) else {
            throw JWTSignerError.invalidPEM
        }
        let base64 = lines
            .filter { !$0.hasPrefix("-----") }
            .joined()
        guard let der = Data(base64Encoded: base64) else {
            throw JWTSignerError.invalidPEM
        }

        if beginLine.contains("RSA PRIVATE KEY") {
            return der
        }
        return try stripPKCS8Wrapper(der)
    }

    /// PrivateKeyInfo ::= SEQUENCE { version INTEGER, algorithm SEQUENCE, privateKey OCTET STRING, ... }
    private static func stripPKCS8Wrapper(_ der: Data) throws -> Data {
        var reader = DERReader(data: der)
        try reader.enterSequence()
        _ = try reader.readInteger()
        try reader.skipSequence()
        return try reader.readOctetString()
    }

    private static func base64URLJSON(_ object: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        return base64URLEncode(data)
    }

    private static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

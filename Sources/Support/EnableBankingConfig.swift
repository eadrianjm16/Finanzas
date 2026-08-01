import Foundation

enum EnableBankingConfig {
    static let baseURL = URL(string: "https://api.enablebanking.com")!
    static let redirectScheme = "esiosapp"
    static let redirectURL = "esiosapp://callback"

    static let applicationID: String = {
        guard let value = secrets["EnableBankingApplicationID"] as? String, !value.isEmpty else {
            fatalError("Falta EnableBankingApplicationID en Sources/Secrets/Secrets.plist. Copia Secrets.example.plist a Secrets.plist y complétalo.")
        }
        return value
    }()

    static let privateKeyPEM: String = {
        guard let value = secrets["EnableBankingPrivateKeyPEM"] as? String, !value.isEmpty else {
            fatalError("Falta EnableBankingPrivateKeyPEM en Sources/Secrets/Secrets.plist. Copia Secrets.example.plist a Secrets.plist y complétalo.")
        }
        return value
    }()

    private static let secrets: [String: Any] = {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            fatalError("No se encontró Secrets.plist en el bundle. Copia Sources/Secrets/Secrets.example.plist a Sources/Secrets/Secrets.plist, complétalo y vuelve a ejecutar `xcodegen generate`.")
        }
        return plist
    }()
}

import Foundation

enum GoCardlessConfig {
    static let baseURL = URL(string: "https://bankaccountdata.gocardless.com/api/v2")!
    static let redirectScheme = "finanzasapp"
    static let redirectURL = "finanzasapp://callback"

    static let secretID: String = {
        guard let value = secrets["GoCardlessSecretID"] as? String, !value.isEmpty else {
            fatalError("Falta GoCardlessSecretID en Sources/Secrets/Secrets.plist. Copia Secrets.example.plist a Secrets.plist y complétalo.")
        }
        return value
    }()

    static let secretKey: String = {
        guard let value = secrets["GoCardlessSecretKey"] as? String, !value.isEmpty else {
            fatalError("Falta GoCardlessSecretKey en Sources/Secrets/Secrets.plist. Copia Secrets.example.plist a Secrets.plist y complétalo.")
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

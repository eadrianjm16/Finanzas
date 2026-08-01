import Foundation

/// Sugiere una categoría (por nombre, ver DefaultCategories) para un movimiento
/// bancario. Enable Banking no categoriza gastos — solo da merchant_category_code
/// (a menudo ausente) y texto libre en remittance_information — así que esto es
/// un motor de reglas propio: código MCC primero (más fiable cuando está
/// presente), palabras clave como fallback, y "Otros" si nada coincide.
/// Nunca se aplica sobre un movimiento que el usuario ya categorizó a mano.
enum CategorizationEngine {
    private static let mccTable: [String: String] = [
        "5411": "Alimentación", "5422": "Alimentación", "5462": "Alimentación",
        "5499": "Alimentación", "5451": "Alimentación",
        "5812": "Restaurantes", "5813": "Restaurantes", "5814": "Restaurantes",
        "4111": "Transporte", "4121": "Transporte", "5541": "Transporte",
        "5542": "Transporte", "4112": "Transporte", "7523": "Transporte",
        "4900": "Suministros", "4899": "Suministros",
        "8011": "Salud", "8021": "Salud", "8062": "Salud", "5912": "Salud",
        "7832": "Ocio", "7922": "Ocio", "7996": "Ocio", "7995": "Ocio",
        "5311": "Compras", "5651": "Compras", "5691": "Compras", "5999": "Compras",
        "5964": "Compras", "5732": "Compras"
    ]

    private static let keywordRules: [(keywords: [String], category: String)] = [
        (["MERCADONA", "CARREFOUR", "LIDL", "DIA ", "ALCAMPO", "EROSKI", "AHORRAMAS"], "Alimentación"),
        (["NETFLIX", "SPOTIFY", "HBO", "DISNEY+", "PRIME VIDEO", "APPLE.COM/BILL", "YOUTUBE PREMIUM",
          "ANTHROPIC", "CLAUDE", "OPENAI", "CHATGPT", "WWW.USE.AI", "AMAZON PRIME"], "Suscripciones"),
        (["UBER", "CABIFY", "BOLT", "RENFE", "METRO", "EMT", "REPSOL", "CEPSA", "BP ", "SHELL"], "Transporte"),
        (["COMISION", "MANTENIMIENTO CUENTA", "CUOTA TARJETA", "COMISIÓN"], "Comisiones bancarias"),
        (["FARMACIA", "SEGURO SALUD", "CLINICA", "CLÍNICA", "MUTUA", "VETERINAR"], "Salud"),
        (["AMAZON", "EL CORTE INGLES", "EL CORTE INGLÉS", "ZARA", "IKEA"], "Compras"),
        (["ALQUILER", "COMUNIDAD PROPIETARIOS", "HIPOTECA"], "Vivienda/Hogar"),
        (["IBERDROLA", "ENDESA", "NATURGY", "VODAFONE", "MOVISTAR", "ORANGE", "JAZZTEL"], "Suministros"),
        (["HOTEL", "TRAVELODGE", "AIRBNB", "BOOKING.COM"], "Ocio"),
        (["NOMINA", "NÓMINA", "PAYROLL", "SALARIO"], "Nómina/Ingresos")
    ]

    static func suggestCategory(
        mcc: String?,
        remittanceInformation: String,
        creditDebitIndicator: String
    ) -> String {
        let upperInfo = remittanceInformation.uppercased()

        if creditDebitIndicator == "CRDT",
           keywordRules.first(where: { $0.category == "Nómina/Ingresos" })!.keywords.contains(where: { upperInfo.contains($0) }) {
            return "Nómina/Ingresos"
        }

        if let mcc, let category = mccTable[mcc] {
            return category
        }

        for rule in keywordRules where rule.category != "Nómina/Ingresos" {
            if rule.keywords.contains(where: { upperInfo.contains($0) }) {
                return rule.category
            }
        }

        return "Otros"
    }
}

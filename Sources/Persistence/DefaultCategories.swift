import Foundation
import SwiftData

enum DefaultCategories {
    static let otrosName = "Otros"

    static let seed: [(name: String, icon: String)] = [
        ("Nómina/Ingresos", "arrow.down.circle"),
        ("Alimentación", "cart"),
        ("Restaurantes", "fork.knife"),
        ("Transporte", "car"),
        ("Vivienda/Hogar", "house"),
        ("Suministros", "bolt"),
        ("Salud", "cross.case"),
        ("Ocio", "gamecontroller"),
        ("Compras", "bag"),
        ("Suscripciones", "arrow.triangle.2.circlepath"),
        ("Comisiones bancarias", "building.columns"),
        (otrosName, "questionmark.circle")
    ]

    /// Siembra las categorías por defecto si la tabla está vacía. Llamar una vez al arrancar.
    static func seedIfNeeded(in context: ModelContext) {
        let existing = (try? context.fetchCount(FetchDescriptor<Category>())) ?? 0
        guard existing == 0 else { return }
        for (index, entry) in seed.enumerated() {
            context.insert(Category(name: entry.name, systemIconName: entry.icon, sortOrder: index))
        }
        try? context.save()
    }
}

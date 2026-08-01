import Foundation
import SwiftData

enum PersistenceController {
    static let shared: ModelContainer = {
        let schema = Schema([LinkedAccount.self, Transaction.self, Category.self])
        let configuration = ModelConfiguration(schema: schema)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("No se pudo crear el ModelContainer de SwiftData: \(error)")
        }
    }()
}

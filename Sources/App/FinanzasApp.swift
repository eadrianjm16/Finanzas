import SwiftUI
import SwiftData

@main
struct FinanzasApp: App {
    @StateObject private var appState: AppState

    @MainActor
    init() {
        let context = PersistenceController.shared.mainContext
        DefaultCategories.seedIfNeeded(in: context)

        let client = EnableBankingClient()
        let sessionStore = BankSessionStore()
        let accountsStore = AccountsStore(modelContext: context, client: client, sessionStore: sessionStore)
        let transactionsStore = TransactionsStore(modelContext: context, client: client)

        _appState = StateObject(wrappedValue: AppState(
            client: client,
            accountsStore: accountsStore,
            transactionsStore: transactionsStore
        ))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .modelContainer(PersistenceController.shared)
                .task { await appState.bootstrap() }
        }
    }
}

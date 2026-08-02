import SwiftUI
import SwiftData

struct TransactionsListView: View {
    @Query(sort: \Transaction.bookingDate, order: .reverse) private var transactions: [Transaction]
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query private var connections: [BankConnection] // sin usar directamente: fuerza a esta vista a reevaluar su body cuando cambia la visibilidad de una cuenta en BankDetailView

    private var visibleTransactions: [Transaction] {
        transactions.filter { $0.account?.isVisible ?? true }
    }

    private var grouped: [(category: String, icon: String, items: [Transaction])] {
        let byCategory = Dictionary(grouping: visibleTransactions) { $0.category?.name ?? DefaultCategories.otrosName }
        return byCategory.keys.sorted().map { name in
            let icon = categories.first(where: { $0.name == name })?.systemIconName ?? "questionmark.circle"
            return (category: name, icon: icon, items: byCategory[name] ?? [])
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(grouped, id: \.category) { group in
                    Section {
                        ForEach(group.items) { tx in
                            TransactionRow(transaction: tx, categories: categories)
                        }
                    } header: {
                        Label(group.category, systemImage: group.icon)
                    }
                }
            }
            .navigationTitle("Movimientos")
            .overlay {
                if visibleTransactions.isEmpty {
                    ContentUnavailableView(
                        "Sin movimientos",
                        systemImage: "list.bullet",
                        description: Text("Conecta un banco para ver tus movimientos")
                    )
                }
            }
        }
    }
}

private struct TransactionRow: View {
    @Bindable var transaction: Transaction
    let categories: [Category]

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.counterpartyName ?? transaction.remittanceInformation)
                    .lineLimit(1)
                Text(transaction.bookingDate, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(formattedAmount)
                .foregroundStyle(transaction.creditDebitIndicator == "CRDT" ? .green : .red)
        }
        .contextMenu {
            Menu("Cambiar categoría") {
                ForEach(categories) { category in
                    Button(category.name) {
                        transaction.category = category
                        transaction.isUserCategorized = true
                    }
                }
            }
        }
    }

    private var formattedAmount: String {
        let sign = transaction.creditDebitIndicator == "CRDT" ? "+" : "-"
        return "\(sign)\(transaction.amount) \(transaction.currency)"
    }
}

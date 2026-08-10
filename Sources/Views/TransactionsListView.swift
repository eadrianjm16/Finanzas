import SwiftUI
import SwiftData

struct TransactionsListView: View {
    @Query(sort: \Transaction.bookingDate, order: .reverse) private var transactions: [Transaction]
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query private var connections: [BankConnection] // sin usar directamente: fuerza a esta vista a reevaluar su body cuando cambia la visibilidad de una cuenta en BankDetailView

    private var visibleTransactions: [Transaction] {
        transactions.filter { $0.account?.isVisible ?? true }
    }

    private var groupedByDay: [(date: Date, items: [Transaction])] {
        TransactionGrouping.byDay(visibleTransactions)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(groupedByDay, id: \.date) { group in
                    Section {
                        ForEach(group.items) { tx in
                            TransactionRow(transaction: tx, categories: categories)
                        }
                    } header: {
                        Text(TransactionGrouping.dayHeaderFormatter.string(from: group.date).uppercased())
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

struct TransactionRow: View {
    @Bindable var transaction: Transaction
    let categories: [Category]
    @State private var showingSplit = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.counterpartyName ?? transaction.remittanceInformation)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(transaction.category?.name ?? DefaultCategories.otrosName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !transaction.debtEntries.isEmpty {
                        Text("Dividido")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }
                }
                HStack(spacing: 8) {
                    Menu {
                        ForEach(categories) { category in
                            Button(category.name) {
                                transaction.category = category
                                transaction.isUserCategorized = true
                            }
                        }
                    } label: {
                        Text("Recategorizar")
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .overlay(Capsule().stroke(Color.accentColor, lineWidth: 1))
                    }
                    Button {
                        showingSplit = true
                    } label: {
                        Text("Dividir")
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .overlay(Capsule().stroke(Color.orange, lineWidth: 1))
                    }
                }
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
        .sheet(isPresented: $showingSplit) {
            SplitTransactionView(transaction: transaction)
        }
    }

    private var formattedAmount: String {
        let sign = transaction.creditDebitIndicator == "CRDT" ? "+" : "-"
        return "\(sign)\(transaction.amount) \(transaction.currency)"
    }
}

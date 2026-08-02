import SwiftUI
import SwiftData
import Charts

struct CategoryAnalysisDetailView: View {
    let categoryName: String

    @Query(sort: \Transaction.bookingDate, order: .reverse) private var transactions: [Transaction]
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query private var connections: [BankConnection] // sin usar: fuerza reevaluación al cambiar isVisible

    @State private var selectedMonth: Date

    init(categoryName: String, initialMonth: Date) {
        self.categoryName = categoryName
        _selectedMonth = State(initialValue: initialMonth)
    }

    private struct MonthAmount: Identifiable {
        let id = UUID()
        let monthLabel: String
        let amount: Double
    }

    private var categoryTransactions: [Transaction] {
        transactions.filter {
            $0.category?.name == categoryName &&
            ($0.account?.isVisible ?? true) &&
            $0.creditDebitIndicator == "DBIT"
        }
    }

    private func total(for month: Date) -> Decimal {
        categoryTransactions
            .filter { Calendar.current.isDate($0.bookingDate, equalTo: month, toGranularity: .month) }
            .reduce(Decimal(0)) { $0 + abs($1.amount) }
    }

    private var monthlyChartData: [MonthAmount] {
        MonthRange.lastSixMonths(endingAt: selectedMonth).map { month in
            MonthAmount(monthLabel: MonthRange.label(month), amount: (total(for: month) as NSDecimalNumber).doubleValue)
        }
    }

    private var monthTransactions: [Transaction] {
        categoryTransactions.filter { Calendar.current.isDate($0.bookingDate, equalTo: selectedMonth, toGranularity: .month) }
    }

    private var groupedByDay: [(date: Date, items: [Transaction])] {
        TransactionGrouping.byDay(monthTransactions)
    }

    var body: some View {
        List {
            Section {
                monthNavigator
                Chart(monthlyChartData) { item in
                    BarMark(x: .value("Mes", item.monthLabel), y: .value("Importe", item.amount))
                        .foregroundStyle(.red)
                }
                .frame(height: 160)
                HStack {
                    Text("Gastado")
                    Spacer()
                    Text("\(total(for: selectedMonth)) EUR").bold()
                }
            }

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
        .navigationTitle(categoryName)
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if monthTransactions.isEmpty {
                ContentUnavailableView(
                    "Sin movimientos",
                    systemImage: "list.bullet",
                    description: Text("Sin movimientos de \(categoryName) este mes")
                )
            }
        }
    }

    private var monthNavigator: some View {
        HStack {
            Button {
                selectedMonth = MonthRange.adding(-1, to: selectedMonth)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Spacer()
            Text(MonthRange.rangeText(selectedMonth))
                .font(.subheadline.bold())
            Spacer()
            Button {
                selectedMonth = MonthRange.adding(1, to: selectedMonth)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

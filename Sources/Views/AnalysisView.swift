import SwiftUI
import SwiftData
import Charts

struct AnalysisView: View {
    @Query(sort: \Transaction.bookingDate, order: .reverse) private var transactions: [Transaction]
    @Query private var budgets: [Budget]
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query private var connections: [BankConnection] // sin usar: fuerza reevaluación al cambiar isVisible en BankDetailView

    @State private var selectedMonth = MonthRange.startOfMonth(.now)
    @State private var segment: Segment = .gastos

    private enum Segment: String, CaseIterable, Identifiable {
        case ingresos = "Ingresos"
        case gastos = "Gastos"
        var id: String { rawValue }
    }

    private struct MonthAmount: Identifiable {
        let id = UUID()
        let monthLabel: String
        let kind: String
        let amount: Double
    }

    private struct CategoryBreakdownItem: Identifiable {
        let id: String
        let categoryName: String
        let icon: String
        let amount: Decimal
        let count: Int
    }

    private var visibleTransactions: [Transaction] {
        transactions.filter { $0.account?.isVisible ?? true }
    }

    private func totals(for month: Date) -> (ingresos: Decimal, gastos: Decimal) {
        var ingresos = Decimal(0)
        var gastos = Decimal(0)
        for tx in visibleTransactions {
            guard Calendar.current.isDate(tx.bookingDate, equalTo: month, toGranularity: .month) else { continue }
            if tx.creditDebitIndicator == "CRDT" {
                ingresos += abs(tx.amount)
            } else {
                gastos += abs(tx.amount)
            }
        }
        return (ingresos, gastos)
    }

    private var monthlyChartData: [MonthAmount] {
        MonthRange.lastSixMonths(endingAt: selectedMonth).flatMap { month -> [MonthAmount] in
            let t = totals(for: month)
            let label = MonthRange.label(month)
            return [
                MonthAmount(monthLabel: label, kind: "Ingresos", amount: (t.ingresos as NSDecimalNumber).doubleValue),
                MonthAmount(monthLabel: label, kind: "Gastos", amount: (t.gastos as NSDecimalNumber).doubleValue)
            ]
        }
    }

    private var selectedMonthTotals: (ingresos: Decimal, gastos: Decimal) {
        totals(for: selectedMonth)
    }

    private var previsto: Decimal {
        budgets.reduce(Decimal(0)) { $0 + $1.monthlyLimit }
    }

    private var categoryBreakdown: [CategoryBreakdownItem] {
        let indicator = segment == .ingresos ? "CRDT" : "DBIT"
        var amounts: [String: Decimal] = [:]
        var counts: [String: Int] = [:]
        for tx in visibleTransactions {
            guard tx.creditDebitIndicator == indicator,
                  Calendar.current.isDate(tx.bookingDate, equalTo: selectedMonth, toGranularity: .month) else { continue }
            let name = tx.category?.name ?? DefaultCategories.otrosName
            amounts[name, default: 0] += abs(tx.amount)
            counts[name, default: 0] += 1
        }
        return amounts.map { name, amount in
            CategoryBreakdownItem(
                id: name,
                categoryName: name,
                icon: categories.first(where: { $0.name == name })?.systemIconName ?? "questionmark.circle",
                amount: amount,
                count: counts[name] ?? 0
            )
        }.sorted { $0.amount > $1.amount }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    monthNavigator
                    monthlyBarChart
                }
                Section {
                    totalsRows
                    previstoRow
                }
                Section {
                    Picker("", selection: $segment) {
                        ForEach(Segment.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    categoryDonutChart
                    ForEach(categoryBreakdown) { item in
                        NavigationLink {
                            CategoryAnalysisDetailView(categoryName: item.categoryName, initialMonth: selectedMonth)
                        } label: {
                            HStack {
                                Label(item.categoryName, systemImage: item.icon)
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text("\(item.amount) EUR")
                                    Text("\(item.count) movimiento\(item.count == 1 ? "" : "s")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Análisis")
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

    private var monthlyBarChart: some View {
        Chart(monthlyChartData) { item in
            BarMark(
                x: .value("Mes", item.monthLabel),
                y: .value("Importe", item.amount)
            )
            .foregroundStyle(by: .value("Tipo", item.kind))
            .position(by: .value("Tipo", item.kind))
        }
        .chartForegroundStyleScale(["Ingresos": Color.blue, "Gastos": Color.red])
        .frame(height: 180)
    }

    private var totalsRows: some View {
        Group {
            HStack {
                Text("Ingresos")
                Spacer()
                Text("\(selectedMonthTotals.ingresos) EUR")
            }
            HStack {
                Text("Gastos")
                Spacer()
                Text("\(selectedMonthTotals.gastos) EUR")
            }
            HStack {
                Text("Neto").bold()
                Spacer()
                Text("\(selectedMonthTotals.ingresos - selectedMonthTotals.gastos) EUR").bold()
            }
        }
    }

    private var previstoRow: some View {
        HStack {
            if previsto > 0 {
                let percent = Int(((selectedMonthTotals.gastos as NSDecimalNumber).doubleValue / (previsto as NSDecimalNumber).doubleValue * 100).rounded())
                Text("\(percent)% de \(previsto) EUR previstos")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Sin presupuesto fijado")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            NavigationLink("Modificar") {
                BudgetsView()
            }
            .font(.caption)
        }
    }

    @ViewBuilder
    private var categoryDonutChart: some View {
        if categoryBreakdown.isEmpty {
            Text("Sin movimientos este mes")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 120)
        } else {
            Chart(categoryBreakdown) { item in
                SectorMark(
                    angle: .value("Importe", (item.amount as NSDecimalNumber).doubleValue),
                    innerRadius: .ratio(0.6)
                )
                .foregroundStyle(by: .value("Categoría", item.categoryName))
            }
            .frame(height: 200)
        }
    }
}

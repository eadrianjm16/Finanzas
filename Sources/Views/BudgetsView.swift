import SwiftUI
import SwiftData

struct BudgetsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query private var budgets: [Budget]
    @Query(sort: \Transaction.bookingDate, order: .reverse) private var transactions: [Transaction]
    @Query private var connections: [BankConnection] // sin usar: fuerza reevaluación al cambiar isVisible en BankDetailView

    @State private var editingCategory: Category?
    @State private var limitText: String = ""

    private var monthlySpendByCategory: [String: Decimal] {
        var result: [String: Decimal] = [:]
        for tx in transactions {
            guard tx.creditDebitIndicator == "DBIT",
                  Calendar.current.isDate(tx.bookingDate, equalTo: .now, toGranularity: .month),
                  tx.account?.isVisible ?? true,
                  let name = tx.category?.name else { continue }
            result[name, default: 0] += abs(tx.amount)
        }
        return result
    }

    private func budget(for category: Category) -> Budget? {
        budgets.first { $0.categoryName == category.name }
    }

    var body: some View {
        NavigationStack {
            List(categories) { category in
                Button {
                    editingCategory = category
                    limitText = budget(for: category).map { "\($0.monthlyLimit)" } ?? ""
                } label: {
                    BudgetRow(
                        category: category,
                        spent: monthlySpendByCategory[category.name] ?? 0,
                        budget: budget(for: category)
                    )
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Presupuestos")
            .sheet(item: $editingCategory) { category in
                budgetEditor(for: category)
            }
        }
    }

    @ViewBuilder
    private func budgetEditor(for category: Category) -> some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Límite mensual (EUR)", text: $limitText)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle(category.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { editingCategory = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        saveBudget(for: category)
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func saveBudget(for category: Category) {
        defer { editingCategory = nil }
        guard let limit = Decimal(string: limitText.replacingOccurrences(of: ",", with: ".")) else { return }
        let categoryName = category.name
        var descriptor = FetchDescriptor<Budget>(predicate: #Predicate { $0.categoryName == categoryName })
        descriptor.fetchLimit = 1
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.monthlyLimit = limit
        } else {
            modelContext.insert(Budget(categoryName: categoryName, monthlyLimit: limit))
        }
        try? modelContext.save()
    }
}

private struct BudgetRow: View {
    let category: Category
    let spent: Decimal
    let budget: Budget?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(category.name, systemImage: category.systemIconName)
                Spacer()
                if let budget {
                    Text("\(spent) / \(budget.monthlyLimit) EUR")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Fijar presupuesto")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
            }
            if let budget, budget.monthlyLimit > 0 {
                ProgressView(value: min((spent as NSDecimalNumber).doubleValue, (budget.monthlyLimit as NSDecimalNumber).doubleValue), total: (budget.monthlyLimit as NSDecimalNumber).doubleValue)
                    .tint(spent >= budget.monthlyLimit ? .red : .accentColor)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

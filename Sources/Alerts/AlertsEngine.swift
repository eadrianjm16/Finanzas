import Foundation

/// Alertas calculadas en vivo a partir de los movimientos y presupuestos ya
/// sincronizados — sin backend ni notificaciones push, se recalculan cada vez
/// que se evalúa (p. ej. al abrir AlertsView). Respeta la visibilidad de
/// cuentas (isVisible) igual que el resto de la app.
enum AlertsEngine {
    struct Alert: Identifiable {
        let id: String
        let icon: String
        let title: String
        let subtitle: String
    }

    private static let duplicateWindow: TimeInterval = 3 * 24 * 3600

    static func evaluate(transactions: [Transaction], budgets: [Budget]) -> [Alert] {
        var alerts: [Alert] = []
        alerts += budgetThresholdAlerts(transactions: transactions, budgets: budgets)
        alerts += duplicateChargeAlerts(transactions: transactions)
        alerts += bankFeeAlerts(transactions: transactions)
        return alerts
    }

    // MARK: - Umbral de presupuesto

    private static func budgetThresholdAlerts(transactions: [Transaction], budgets: [Budget]) -> [Alert] {
        guard !budgets.isEmpty else { return [] }

        var spendByCategory: [String: Decimal] = [:]
        for tx in transactions {
            guard tx.creditDebitIndicator == "DBIT",
                  Calendar.current.isDate(tx.bookingDate, equalTo: .now, toGranularity: .month),
                  tx.account?.isVisible ?? true,
                  let name = tx.category?.name else { continue }
            spendByCategory[name, default: 0] += abs(tx.amount)
        }

        let monthKey = Self.monthKeyFormatter.string(from: .now)

        return budgets.compactMap { budget in
            guard budget.monthlyLimit > 0,
                  let spent = spendByCategory[budget.categoryName] else { return nil }
            let ratio = (spent as NSDecimalNumber).doubleValue / (budget.monthlyLimit as NSDecimalNumber).doubleValue
            guard ratio >= 0.8 else { return nil }
            let percent = Int((ratio * 100).rounded())
            let title = ratio >= 1
                ? "Presupuesto de \(budget.categoryName) superado"
                : "Vas al \(percent)% de tu presupuesto en \(budget.categoryName)"
            return Alert(
                // Incluye el mes en el id: al descartar la alerta solo se oculta
                // hasta que cambie de mes, no para siempre (el gasto real sigue).
                id: "budget-\(budget.categoryName)-\(monthKey)",
                icon: ratio >= 1 ? "exclamationmark.triangle.fill" : "chart.pie",
                title: title,
                subtitle: "\(spent) de \(budget.monthlyLimit) EUR este mes"
            )
        }
    }

    private static let monthKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM"
        return formatter
    }()

    // MARK: - Posibles cargos duplicados

    private static func duplicateChargeAlerts(transactions: [Transaction]) -> [Alert] {
        let candidates = transactions.filter {
            $0.creditDebitIndicator == "DBIT" &&
            ($0.account?.isVisible ?? true) &&
            $0.category?.name != "Suscripciones"
        }

        let grouped = Dictionary(grouping: candidates) { tx in
            "\(tx.amount)|\(tx.currency)|\(normalizedText(tx.counterpartyName ?? tx.remittanceInformation))"
        }

        var alerts: [Alert] = []
        for (key, group) in grouped where group.count > 1 {
            let sorted = group.sorted { $0.bookingDate < $1.bookingDate }
            for i in 1..<sorted.count {
                let gap = sorted[i].bookingDate.timeIntervalSince(sorted[i - 1].bookingDate)
                guard gap <= duplicateWindow else { continue }
                let name = sorted[i].counterpartyName ?? sorted[i].remittanceInformation
                alerts.append(Alert(
                    id: "dup-\(key)-\(i)",
                    icon: "doc.on.doc",
                    title: "Posible cargo duplicado",
                    subtitle: "\(name.trimmingCharacters(in: .whitespacesAndNewlines)): \(sorted[i].amount) \(sorted[i].currency) dos veces en \(max(1, Int((gap / 3600 / 24).rounded(.up)))) día(s)"
                ))
                break // una alerta por grupo basta
            }
        }
        return alerts
    }

    private static func normalizedText(_ text: String) -> String {
        let upper = text.uppercased()
        let filtered = upper.unicodeScalars.filter { CharacterSet.letters.contains($0) || $0 == " " }
        let collapsed = String(String.UnicodeScalarView(filtered))
        return String(collapsed.prefix(20))
    }

    // MARK: - Comisiones bancarias

    private static func bankFeeAlerts(transactions: [Transaction]) -> [Alert] {
        let oneMonthAgo = Date().addingTimeInterval(-30 * 24 * 3600)
        let fees = transactions.filter {
            $0.category?.name == "Comisiones bancarias" &&
            ($0.account?.isVisible ?? true) &&
            $0.bookingDate >= oneMonthAgo
        }
        return fees.map { tx in
            Alert(
                id: "fee-\(tx.entryReference)",
                icon: "building.columns",
                title: "Comisión bancaria detectada",
                subtitle: "\(tx.amount) \(tx.currency) el \(tx.bookingDate.formatted(date: .abbreviated, time: .omitted))"
            )
        }
    }
}

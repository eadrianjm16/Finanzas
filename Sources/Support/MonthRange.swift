import Foundation

enum MonthRange {
    static func startOfMonth(_ date: Date) -> Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: date))!
    }

    static func adding(_ value: Int, to month: Date) -> Date {
        Calendar.current.date(byAdding: .month, value: value, to: month)!
    }

    static func label(_ month: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "MMM"
        return formatter.string(from: month)
    }

    static func rangeText(_ month: Date) -> String {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return "" }
        let lastDay = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end

        let startFormatter = DateFormatter()
        startFormatter.locale = Locale(identifier: "es_ES")
        startFormatter.dateFormat = "d MMM."

        let endFormatter = DateFormatter()
        endFormatter.locale = Locale(identifier: "es_ES")
        endFormatter.dateFormat = "d MMM. yyyy"

        return "\(startFormatter.string(from: interval.start)) - \(endFormatter.string(from: lastDay))"
    }

    static func lastSixMonths(endingAt month: Date) -> [Date] {
        (0..<6).reversed().map { adding(-$0, to: month) }
    }
}

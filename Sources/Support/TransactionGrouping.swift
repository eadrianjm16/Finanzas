import Foundation

enum TransactionGrouping {
    static func byDay(_ transactions: [Transaction]) -> [(date: Date, items: [Transaction])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: transactions) { calendar.startOfDay(for: $0.bookingDate) }
        return grouped.keys.sorted(by: >).map { day in
            (date: day, items: (grouped[day] ?? []).sorted { $0.bookingDate > $1.bookingDate })
        }
    }

    static let dayHeaderFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "EEEE d 'de' MMMM yyyy"
        return formatter
    }()
}

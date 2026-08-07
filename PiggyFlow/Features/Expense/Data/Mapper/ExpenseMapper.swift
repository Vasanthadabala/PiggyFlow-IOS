import Foundation

/// Translates between SwiftData models and the Firestore dictionaries used for sync.
///
/// Keeping the field names in one place matters: the encode and decode sides have to agree
/// exactly, and when they were written inline at each call site a renamed key broke sync
/// silently — the write succeeded, the read just returned a default value.
enum ExpenseMapper {

    private enum Key {
        static let id = "id"
        static let type = "type"
        static let emoji = "emoji"
        static let name = "name"
        static let amount = "price"
        static let date = "date"
        static let note = "note"
        static let updatedAt = "updatedAt"
    }

    // MARK: - Expense

    static func dictionary(from expense: Expense, updatedAt: Date = Date()) -> [String: Any] {
        [
            Key.id: expense.id,
            Key.type: expense.type,
            Key.emoji: expense.emoji,
            Key.name: expense.name,
            Key.amount: expense.price,
            Key.date: expense.date.timeIntervalSince1970,
            Key.note: expense.note,
            Key.updatedAt: updatedAt.timeIntervalSince1970
        ]
    }

    static func expense(from dictionary: [String: Any]) -> Expense? {
        guard let type = dictionary[Key.type] as? String else { return nil }

        let expense = Expense(
            type: type,
            emoji: dictionary[Key.emoji] as? String ?? "",
            name: dictionary[Key.name] as? String ?? "",
            price: dictionary[Key.amount] as? Double ?? 0,
            date: timestamp(dictionary[Key.date]),
            note: dictionary[Key.note] as? String ?? ""
        )
        if let id = dictionary[Key.id] as? String { expense.id = id }
        return expense
    }

    // MARK: - Income

    static func dictionary(from income: Income, updatedAt: Date = Date()) -> [String: Any] {
        [
            Key.id: income.id,
            Key.type: income.type,
            Key.emoji: income.emoji,
            Key.name: income.name,
            Key.amount: income.income,
            Key.date: income.date.timeIntervalSince1970,
            Key.note: income.note,
            Key.updatedAt: updatedAt.timeIntervalSince1970
        ]
    }

    static func income(from dictionary: [String: Any]) -> Income? {
        guard let type = dictionary[Key.type] as? String else { return nil }

        let income = Income(
            type: type,
            emoji: dictionary[Key.emoji] as? String ?? "",
            name: dictionary[Key.name] as? String ?? "",
            income: dictionary[Key.amount] as? Double ?? 0,
            date: timestamp(dictionary[Key.date]),
            note: dictionary[Key.note] as? String ?? ""
        )
        if let id = dictionary[Key.id] as? String { income.id = id }
        return income
    }

    // MARK: - Helpers

    /// Firestore may hand back a `Double` epoch or a `Date`, depending on how the value was
    /// written; accept either rather than defaulting to "now" and corrupting the record.
    private static func timestamp(_ value: Any?) -> Date {
        if let seconds = value as? Double { return Date(timeIntervalSince1970: seconds) }
        if let date = value as? Date { return date }
        return Date()
    }
}

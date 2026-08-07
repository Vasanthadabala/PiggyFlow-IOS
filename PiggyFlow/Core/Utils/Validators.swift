import Foundation

/// Input validation for user-entered values.
///
/// Each validator returns a `ValidationResult` rather than a bare `Bool` so the caller can
/// show *why* something was rejected instead of a generic "invalid input".
enum Validators {

    enum ValidationResult: Equatable {
        case valid
        case invalid(String)

        var isValid: Bool { self == .valid }

        /// The failure message, or `nil` when valid — convenient for binding to a field's
        /// error label.
        var message: String? {
            if case .invalid(let message) = self { return message }
            return nil
        }
    }

    // MARK: - Text

    static func required(_ value: String, field: String) -> ValidationResult {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? .invalid("\(field) is required.")
            : .valid
    }

    static func email(_ value: String) -> ValidationResult {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .invalid("Email is required.") }

        // Deliberately permissive: one @, a dot-bearing domain, no whitespace. Stricter
        // regexes reject valid addresses more often than they catch typos.
        let pattern = #"^[^\s@]+@[^\s@]+\.[^\s@]{2,}$"#
        return trimmed.range(of: pattern, options: .regularExpression) != nil
            ? .valid
            : .invalid("Enter a valid email address.")
    }

    // MARK: - Money

    /// Validates a user-typed amount string.
    static func amount(_ value: String, allowZero: Bool = false) -> ValidationResult {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .invalid("Enter an amount.") }

        // Strip the currency symbol and grouping separators before parsing.
        let cleaned = trimmed
            .replacingOccurrences(of: AppConstants.Currency.symbol, with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)

        guard let number = Double(cleaned) else {
            return .invalid("Enter a valid number.")
        }
        guard number.isFinite else {
            return .invalid("Enter a valid number.")
        }
        if number < 0 {
            return .invalid("Amount can't be negative.")
        }
        if !allowZero && number == 0 {
            return .invalid("Amount must be greater than zero.")
        }
        return .valid
    }

    /// Parses a user-typed amount, returning `nil` when it isn't usable.
    static func parseAmount(_ value: String) -> Double? {
        let cleaned = value
            .replacingOccurrences(of: AppConstants.Currency.symbol, with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let number = Double(cleaned), number.isFinite else { return nil }
        return number
    }

    // MARK: - Dates

    /// Rejects dates in the future for things that can only have already happened.
    static func notInFuture(_ date: Date, field: String = "Date") -> ValidationResult {
        date > Date()
            ? .invalid("\(field) can't be in the future.")
            : .valid
    }

    /// Rejects dates in the past for things that must be upcoming (due dates, reminders).
    static func notInPast(_ date: Date, field: String = "Due date") -> ValidationResult {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return date < startOfToday
            ? .invalid("\(field) can't be in the past.")
            : .valid
    }

    // MARK: - Composition

    /// Returns the first failure, or `.valid` when everything passes.
    static func firstFailure(_ results: ValidationResult...) -> ValidationResult {
        results.first(where: { !$0.isValid }) ?? .valid
    }
}

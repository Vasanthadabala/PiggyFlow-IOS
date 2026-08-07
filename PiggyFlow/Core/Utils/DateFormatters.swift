import Foundation

/// Shared, pre-built date formatters.
///
/// `DateFormatter` is expensive to construct (roughly a millisecond each) because it builds
/// an ICU pattern under the hood. Creating one inside a `View`'s computed property means
/// paying that cost for **every row, on every render pass** — the single biggest cause of
/// dropped frames while scrolling a list. These are built once and reused.
enum AppDateFormat {
    /// `Jul 24, 2026` — transaction rows.
    static let medium: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM dd, yyyy"
        return f
    }()

    /// `Jul 24` — compact, for dense lists.
    static let compact: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM dd"
        return f
    }()

    /// `Friday, July 24, 2026` — detail screens.
    static let full: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM dd, yyyy"
        return f
    }()
}

extension Date {
    var formattedMedium: String { AppDateFormat.medium.string(from: self) }
    var formattedCompact: String { AppDateFormat.compact.string(from: self) }
    var formattedFull: String { AppDateFormat.full.string(from: self) }
}

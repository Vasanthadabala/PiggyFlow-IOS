import Foundation

/// Shared value formatting.
///
/// Currency in particular was being hand-rolled as `"₹\(Int(amount).formatted())"` in
/// dozens of places, which hardcodes the symbol, drops the fractional part inconsistently,
/// and ignores the user's locale grouping. Route money through here instead.
enum AppFormatter {

    // MARK: - Currency

    private static let currencyLocale = Locale(identifier: AppConstants.Currency.localeIdentifier)

    private static let currency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = currencyLocale
        formatter.currencyCode = AppConstants.Currency.code
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter
    }()

    private static let currencyNoDecimals: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = currencyLocale
        formatter.currencyCode = AppConstants.Currency.code
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    /// `₹1,20,440.00`
    static func currency(_ amount: Double) -> String {
        currency.string(from: NSNumber(value: amount)) ?? "\(AppConstants.Currency.symbol)\(amount)"
    }

    /// `₹1,20,440` — for dense UI where the decimals are noise.
    static func currencyRounded(_ amount: Double) -> String {
        currencyNoDecimals.string(from: NSNumber(value: amount)) ?? "\(AppConstants.Currency.symbol)\(Int(amount))"
    }

    /// Signed for ledger rows: `-₹450.00` / `+₹450.00`.
    static func signedCurrency(_ amount: Double, isIncome: Bool) -> String {
        "\(isIncome ? "+" : "-")\(currency(abs(amount)))"
    }

    /// Compact form for charts and chips: `₹1.20L`, `₹32.5K`.
    static func compactCurrency(_ amount: Double) -> String {
        let symbol = AppConstants.Currency.symbol
        let magnitude = abs(amount)
        let sign = amount < 0 ? "-" : ""

        switch magnitude {
        case 10_000_000...:
            return "\(sign)\(symbol)\(String(format: "%.2f", magnitude / 10_000_000))Cr"
        case 100_000...:
            return "\(sign)\(symbol)\(String(format: "%.2f", magnitude / 100_000))L"
        case 1_000...:
            return "\(sign)\(symbol)\(String(format: "%.1f", magnitude / 1_000))K"
        default:
            return "\(sign)\(symbol)\(Int(magnitude))"
        }
    }

    // MARK: - Percent

    /// `26.9%`
    static func percent(_ value: Double, decimals: Int = 1) -> String {
        String(format: "%.\(decimals)f%%", value)
    }

    /// Share of a total, guarding divide-by-zero.
    static func percentOf(_ value: Double, total: Double, decimals: Int = 1) -> String {
        guard total != 0 else { return percent(0, decimals: decimals) }
        return percent((value / total) * 100, decimals: decimals)
    }

    // MARK: - File size

    private static let byteCount: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter
    }()

    /// `245 KB`
    static func fileSize(_ bytes: Int) -> String {
        byteCount.string(fromByteCount: Int64(bytes))
    }
}

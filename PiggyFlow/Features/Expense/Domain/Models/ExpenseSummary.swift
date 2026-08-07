import Foundation

/// Aggregated spending figures for a period.
///
/// A plain value type rather than a SwiftData model: these numbers are *derived*, never
/// stored. Computing them once here — instead of re-deriving totals inline in every view
/// body — keeps Home, Stats and Reports from disagreeing about what "total spend" means.
struct ExpenseSummary: Equatable {
    let totalSpent: Double
    let totalIncome: Double
    let transactionCount: Int
    let categoryBreakdown: [CategoryTotal]

    var netBalance: Double { totalIncome - totalSpent }

    /// Percentage of income kept, clamped to 0…100. Zero income yields 0 rather than a
    /// divide-by-zero or a misleading 100%.
    var savingsRate: Double {
        guard totalIncome > 0 else { return 0 }
        return max(0, min(100, ((totalIncome - totalSpent) / totalIncome) * 100))
    }

    var averagePerTransaction: Double {
        guard transactionCount > 0 else { return 0 }
        return totalSpent / Double(transactionCount)
    }

    /// The single biggest category, if there is any spend at all.
    var topCategory: CategoryTotal? { categoryBreakdown.first }

    static let empty = ExpenseSummary(
        totalSpent: 0,
        totalIncome: 0,
        transactionCount: 0,
        categoryBreakdown: []
    )
}

/// One category's share of total spend.
struct CategoryTotal: Equatable, Identifiable {
    var id: String { name }
    let name: String
    let amount: Double
    /// Share of the period's total spend, 0…100.
    let percentage: Double
}

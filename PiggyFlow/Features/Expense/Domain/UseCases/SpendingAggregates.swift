import Foundation

/// Merchant-level aggregation, period-over-period comparisons, and weekly trend bucketing —
/// the derivations `CalculateExpenseSummaryUseCase` doesn't cover (it groups by category
/// only). Mirrors the grouping/comparison logic already proven out in `SpendingInsightsCard`,
/// generalized so Stats/Insights/Reports screens share one implementation instead of each
/// hand-rolling (and mostly faking) their own.
enum SpendingAggregates {

    struct MerchantTotal: Identifiable {
        var id: String { name }
        let name: String
        let amount: Double
        let percentage: Double
    }

    /// Groups by merchant — falling back to the transaction's own name, then its category,
    /// when merchant is blank — largest first.
    static func topMerchants(in expenses: [Expense], limit: Int = 5) -> [MerchantTotal] {
        let total = expenses.reduce(0) { $0 + $1.price }
        guard total > 0 else { return [] }

        let grouped = Dictionary(grouping: expenses) { expense -> String in
            let merchant = expense.merchant.trimmingCharacters(in: .whitespaces)
            if !merchant.isEmpty { return merchant }
            return expense.name.isEmpty ? expense.type : expense.name
        }

        return grouped
            .map { name, items in
                let amount = items.reduce(0) { $0 + $1.price }
                return MerchantTotal(name: name, amount: amount, percentage: (amount / total) * 100)
            }
            .sorted { $0.amount > $1.amount }
            .prefix(limit)
            .map { $0 }
    }

    /// Total expenses in the given month — 0 is the reference month, 1 is a month before it.
    static func expenseTotal(in expenses: [Expense], monthsAgo: Int, from reference: Date = Date()) -> Double {
        let calendar = Calendar.current
        guard let target = calendar.date(byAdding: .month, value: -monthsAgo, to: reference) else { return 0 }
        return expenses
            .filter { calendar.isDate($0.date, equalTo: target, toGranularity: .month) }
            .reduce(0) { $0 + $1.price }
    }

    /// Percent change vs the prior month — `nil` when there's no prior-month spend to compare
    /// against (e.g. the first month of use), so callers can show an honest message instead of
    /// a divide-by-zero-derived number.
    static func monthOverMonthChange(in expenses: [Expense], from reference: Date = Date()) -> Double? {
        let current = expenseTotal(in: expenses, monthsAgo: 0, from: reference)
        let previous = expenseTotal(in: expenses, monthsAgo: 1, from: reference)
        guard previous > 0 else { return nil }
        return ((current - previous) / previous) * 100
    }

    /// Same comparison, generalized to any per-category slice — used to find "which category
    /// moved the most" rather than only the running total.
    static func categoryMonthOverMonthChange(
        in expenses: [Expense],
        category: String,
        from reference: Date = Date()
    ) -> Double? {
        let matching = expenses.filter { $0.type == category }
        return monthOverMonthChange(in: matching, from: reference)
    }

    struct WeeklyTotal: Identifiable {
        let id = UUID()
        let label: String
        let income: Double
        let expense: Double
    }

    /// Buckets a month into 5 fixed-width spans and sums income/expense per bucket — the one
    /// weekly-trend implementation every "trend chart" in the app should call, instead of each
    /// screen inventing its own fake curve.
    static func weeklyTotals(expenses: [Expense], incomes: [Income], month: Date = Date()) -> [WeeklyTotal] {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: month) else { return [] }
        let dayCount = calendar.dateComponents([.day], from: monthInterval.start, to: monthInterval.end).day ?? 30
        let bucketCount = 5
        let bucketSize = max(1, Int((Double(dayCount) / Double(bucketCount)).rounded(.up)))

        var buckets: [WeeklyTotal] = []
        for index in 0..<bucketCount {
            guard let bucketStart = calendar.date(byAdding: .day, value: index * bucketSize, to: monthInterval.start),
                  bucketStart < monthInterval.end else { break }
            let bucketEnd = min(
                calendar.date(byAdding: .day, value: bucketSize, to: bucketStart) ?? monthInterval.end,
                monthInterval.end
            )
            let income = incomes.filter { $0.date >= bucketStart && $0.date < bucketEnd }.reduce(0) { $0 + $1.income }
            let expense = expenses.filter { $0.date >= bucketStart && $0.date < bucketEnd }.reduce(0) { $0 + $1.price }
            buckets.append(WeeklyTotal(label: bucketStart.formatted(.dateTime.month(.abbreviated).day()), income: income, expense: expense))
        }
        return buckets
    }
}

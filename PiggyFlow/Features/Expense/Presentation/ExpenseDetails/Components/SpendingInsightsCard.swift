import SwiftUI

/// Real per-merchant (or per-category, when no merchant is recorded) spending stats for an
/// expense's edit screen — total spent this month, how many transactions, the average order,
/// and how this month compares to last. Computed from the same `Expense` records already
/// loaded elsewhere in the app rather than persisted anywhere, so it always reflects the
/// current ledger instead of the placeholder numbers this card used to hardcode.
struct SpendingInsightsCard: View {
    let expenses: [Expense]
    let subject: Expense

    private var calendar: Calendar { .current }

    /// What the card calls the group in its copy — the merchant if there is one, else the
    /// transaction's own name, else the category.
    private var groupLabel: String {
        let merchant = subject.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        if !merchant.isEmpty { return merchant }
        return subject.name.isEmpty ? subject.type : subject.name
    }

    private func matches(_ expense: Expense) -> Bool {
        let merchant = subject.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        if !merchant.isEmpty {
            return expense.merchant.caseInsensitiveCompare(merchant) == .orderedSame
        }
        return expense.type == subject.type
    }

    private func totals(monthsAgo: Int) -> (total: Double, count: Int) {
        guard let targetMonth = calendar.date(byAdding: .month, value: -monthsAgo, to: Date()) else {
            return (0, 0)
        }
        let matching = expenses.filter {
            matches($0) && calendar.isDate($0.date, equalTo: targetMonth, toGranularity: .month)
        }
        return (matching.reduce(0) { $0 + $1.price }, matching.count)
    }

    private var thisMonth: (total: Double, count: Int) { totals(monthsAgo: 0) }
    private var lastMonth: (total: Double, count: Int) { totals(monthsAgo: 1) }

    private var averageThisMonth: Double {
        thisMonth.count == 0 ? 0 : thisMonth.total / Double(thisMonth.count)
    }

    private var comparisonText: String {
        guard lastMonth.total > 0 else {
            return thisMonth.count <= 1
                ? "First transaction at \(groupLabel) this month."
                : "\(thisMonth.count) transactions at \(groupLabel) this month so far."
        }
        let change = ((thisMonth.total - lastMonth.total) / lastMonth.total) * 100
        let direction = change >= 0 ? "more" : "less"
        return "You've spent \(AppFormatter.percent(abs(change), decimals: 0)) \(direction) at \(groupLabel) compared to last month."
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: AppIcon.Chart.insight)
                    .font(.system(size: 13))
                    .foregroundColor(.appWarningAmber)
                Text("Spending Insights")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(16)

            RowDivider().padding(.horizontal, 16)

            HStack(spacing: 0) {
                stat(title: "Total spent at \(groupLabel)", value: AppFormatter.currency(thisMonth.total), sub: "This Month")
                Divider().frame(height: 50)
                stat(title: "Transactions", value: "\(thisMonth.count)", sub: "This Month")
                Divider().frame(height: 50)
                stat(title: "Average per order", value: AppFormatter.currency(averageThisMonth), sub: "This Month")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            RowDivider().padding(.horizontal, 16)

            HStack {
                Image(systemName: AppIcon.Chart.trend)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.appGreen)
                Text(comparisonText)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .groupedCard(cornerRadius: 18)
    }

    @ViewBuilder
    private func stat(title: String, value: String, sub: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(sub)
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

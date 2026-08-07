import Foundation

/// Builds the aggregate figures the dashboards render.
///
/// This is the logic Home, Stats and Reports each used to re-derive inline — totals,
/// savings rate, and the category breakdown feeding every donut chart. Centralising it
/// means those screens can't drift apart, and the arithmetic is unit-testable without a view.
struct CalculateExpenseSummaryUseCase {

    private let repository: ExpenseRepository

    init(repository: ExpenseRepository) {
        self.repository = repository
    }

    /// Summary across all recorded history.
    func execute() throws -> ExpenseSummary {
        try summarize(
            expenses: repository.fetchExpenses(),
            incomes: repository.fetchIncomes()
        )
    }

    /// Summary limited to a period.
    func execute(in interval: DateInterval) throws -> ExpenseSummary {
        try summarize(
            expenses: repository.fetchExpenses(in: interval),
            incomes: repository.fetchIncomes(in: interval)
        )
    }

    // MARK: - Aggregation

    private func summarize(expenses: [Expense], incomes: [Income]) -> ExpenseSummary {
        let totalSpent = expenses.reduce(0) { $0 + $1.price }
        let totalIncome = incomes.reduce(0) { $0 + $1.income }

        return ExpenseSummary(
            totalSpent: totalSpent,
            totalIncome: totalIncome,
            transactionCount: expenses.count,
            categoryBreakdown: breakdown(of: expenses, total: totalSpent)
        )
    }

    /// Groups by category, largest first.
    private func breakdown(of expenses: [Expense], total: Double) -> [CategoryTotal] {
        guard total > 0 else { return [] }

        let grouped = Dictionary(grouping: expenses) { expense -> String in
            let name = expense.type.trimmingCharacters(in: .whitespaces)
            return name.isEmpty ? "Uncategorised" : name
        }

        return grouped
            .map { name, items in
                let amount = items.reduce(0) { $0 + $1.price }
                return CategoryTotal(
                    name: name,
                    amount: amount,
                    percentage: (amount / total) * 100
                )
            }
            .sorted { $0.amount > $1.amount }
    }
}

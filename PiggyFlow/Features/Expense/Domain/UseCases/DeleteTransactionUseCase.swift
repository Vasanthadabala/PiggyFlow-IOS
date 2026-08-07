import Foundation

/// Deletes an expense or income, keeping the cloud copy in step.
///
/// Deletion has to be queued for sync as well as applied locally — otherwise the next
/// restore pulls the "deleted" record straight back down.
struct DeleteTransactionUseCase {

    private let repository: ExpenseRepository

    init(repository: ExpenseRepository) {
        self.repository = repository
    }

    func execute(expense: Expense) throws {
        try repository.delete(expense)
        Log.info("Deleted expense \(expense.id)", category: .database)
    }

    func execute(income: Income) throws {
        try repository.delete(income)
        Log.info("Deleted income \(income.id)", category: .database)
    }
}

/// Reads transactions for a period, newest first.
struct FetchTransactionsUseCase {

    private let repository: ExpenseRepository

    init(repository: ExpenseRepository) {
        self.repository = repository
    }

    func expenses(in interval: DateInterval? = nil) throws -> [Expense] {
        if let interval {
            return try repository.fetchExpenses(in: interval)
        }
        return try repository.fetchExpenses()
    }

    func incomes(in interval: DateInterval? = nil) throws -> [Income] {
        if let interval {
            return try repository.fetchIncomes(in: interval)
        }
        return try repository.fetchIncomes()
    }
}

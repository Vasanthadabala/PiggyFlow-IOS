import Foundation
import SwiftData

/// Builds the Domain-layer use cases.
///
/// Use cases are cheap value types holding only a repository reference, so they're built on
/// demand rather than cached — that keeps them bound to the caller's `ModelContext` instead
/// of a stale one.
@MainActor
final class UseCaseContainer {

    private unowned let repositories: RepositoryContainer

    init(repositories: RepositoryContainer) {
        self.repositories = repositories
    }

    // MARK: - Expense

    func calculateSummary(context: ModelContext) -> CalculateExpenseSummaryUseCase {
        CalculateExpenseSummaryUseCase(repository: repositories.expenseRepository(context: context))
    }

    func saveExpense(context: ModelContext) -> SaveExpenseUseCase {
        SaveExpenseUseCase(repository: repositories.expenseRepository(context: context))
    }

    func saveIncome(context: ModelContext) -> SaveIncomeUseCase {
        SaveIncomeUseCase(repository: repositories.expenseRepository(context: context))
    }

    func deleteTransaction(context: ModelContext) -> DeleteTransactionUseCase {
        DeleteTransactionUseCase(repository: repositories.expenseRepository(context: context))
    }

    func fetchTransactions(context: ModelContext) -> FetchTransactionsUseCase {
        FetchTransactionsUseCase(repository: repositories.expenseRepository(context: context))
    }
}

import Foundation
import SwiftData

/// SwiftData-backed `ExpenseRepository`.
///
/// Also enqueues cloud sync on every mutation, so callers can't forget to — previously each
/// view remembered (or didn't) to call `CloudSyncManager` after saving, which is how records
/// ended up local-only.
final class ExpenseRepositoryImpl: ExpenseRepository {

    private let context: ModelContext
    private let cloudSync: CloudSyncManager?

    init(context: ModelContext, cloudSync: CloudSyncManager? = nil) {
        self.context = context
        self.cloudSync = cloudSync
    }

    // MARK: - Reads

    func fetchExpenses() throws -> [Expense] {
        try context.fetch(
            FetchDescriptor<Expense>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        )
    }

    func fetchExpenses(in interval: DateInterval) throws -> [Expense] {
        let start = interval.start
        let end = interval.end
        return try context.fetch(
            FetchDescriptor<Expense>(
                predicate: #Predicate { $0.date >= start && $0.date <= end },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
        )
    }

    func fetchIncomes() throws -> [Income] {
        try context.fetch(
            FetchDescriptor<Income>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        )
    }

    func fetchIncomes(in interval: DateInterval) throws -> [Income] {
        let start = interval.start
        let end = interval.end
        return try context.fetch(
            FetchDescriptor<Income>(
                predicate: #Predicate { $0.date >= start && $0.date <= end },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
        )
    }

    // MARK: - Writes

    func add(_ expense: Expense) throws {
        context.insert(expense)
        try save()
        Task { @MainActor in cloudSync?.queueExpenseUpsert(expense) }
    }

    func add(_ income: Income) throws {
        context.insert(income)
        try save()
        Task { @MainActor in cloudSync?.queueIncomeUpsert(income) }
    }

    func delete(_ expense: Expense) throws {
        let id = expense.id
        context.delete(expense)
        try save()
        Task { @MainActor in cloudSync?.queueDeleteExpense(id: id) }
    }

    func delete(_ income: Income) throws {
        let id = income.id
        context.delete(income)
        try save()
        Task { @MainActor in cloudSync?.queueDeleteIncome(id: id) }
    }

    func save() throws {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            Log.error(error, context: "Saving expense context", category: .database)
            throw AppError.persistence("Couldn't save your changes. Please try again.")
        }
    }
}

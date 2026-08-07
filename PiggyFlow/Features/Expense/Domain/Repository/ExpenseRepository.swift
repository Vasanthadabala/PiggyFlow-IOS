import Foundation

/// Persistence contract for expenses and income.
///
/// Declared in Domain and implemented in Data, so use cases depend on this protocol rather
/// than on SwiftData directly — that's what makes them testable without a live store, and
/// what would let the storage engine change without touching business rules.
protocol ExpenseRepository {

    // MARK: - Reads

    func fetchExpenses() throws -> [Expense]
    func fetchExpenses(in interval: DateInterval) throws -> [Expense]
    func fetchIncomes() throws -> [Income]
    func fetchIncomes(in interval: DateInterval) throws -> [Income]

    // MARK: - Writes

    func add(_ expense: Expense) throws
    func add(_ income: Income) throws
    func delete(_ expense: Expense) throws
    func delete(_ income: Income) throws
    func save() throws
}

import Foundation

/// Validates and persists a new expense.
///
/// Validation lives here rather than in the view so the same rules apply however an expense
/// arrives — typed by hand, extracted from a scanned receipt, or restored from the cloud.
struct SaveExpenseUseCase {

    private let repository: ExpenseRepository

    init(repository: ExpenseRepository) {
        self.repository = repository
    }

    struct Input {
        var category: String
        var name: String
        var amount: Double
        var date: Date
        var emoji: String = ""
        var note: String = ""
        /// Optional detail captured by the full expense form; left at its default when an
        /// expense arrives from a quicker path (the bottom sheet, a scan, a cloud restore).
        var currencyCode: String = AppConstants.Currency.code
        var merchant: String = ""
        var paymentMethod: String = ""
        var account: String = ""
        var tags: [String] = []
    }

    func execute(_ input: Input) throws {
        try validate(input)

        let expense = Expense(
            type: input.category,
            emoji: input.emoji,
            name: input.name.trimmingCharacters(in: .whitespacesAndNewlines),
            price: input.amount,
            date: input.date,
            note: input.note.trimmingCharacters(in: .whitespacesAndNewlines),
            currencyCode: input.currencyCode,
            merchant: input.merchant.trimmingCharacters(in: .whitespacesAndNewlines),
            paymentMethod: input.paymentMethod,
            account: input.account,
            tags: input.tags
        )

        try repository.add(expense)
        Log.info("Saved expense \(expense.id)", category: .database)
    }

    private func validate(_ input: Input) throws {
        let result = Validators.firstFailure(
            Validators.required(input.category, field: "Category"),
            Validators.amount(String(input.amount)),
            Validators.notInFuture(input.date, field: "Expense date")
        )
        if case .invalid(let message) = result {
            throw AppError.validation(message)
        }
    }
}

/// Validates and persists new income. Mirrors `SaveExpenseUseCase`; kept separate because
/// income has its own rules (a future-dated salary entry is legitimate, a future-dated
/// expense usually isn't).
struct SaveIncomeUseCase {

    private let repository: ExpenseRepository

    init(repository: ExpenseRepository) {
        self.repository = repository
    }

    struct Input {
        var category: String
        var name: String
        var amount: Double
        var date: Date
        var emoji: String = ""
        var note: String = ""
        /// Optional detail captured by the full income form; left at its default when income
        /// arrives from a quicker path (a scan, a cloud restore).
        var currencyCode: String = AppConstants.Currency.code
        var payer: String = ""
        var paymentMethod: String = ""
        var account: String = ""
        var incomeType: String = ""
        var tags: [String] = []
    }

    func execute(_ input: Input) throws {
        let result = Validators.firstFailure(
            Validators.required(input.category, field: "Category"),
            Validators.amount(String(input.amount))
        )
        if case .invalid(let message) = result {
            throw AppError.validation(message)
        }

        let income = Income(
            type: input.category,
            emoji: input.emoji,
            name: input.name.trimmingCharacters(in: .whitespacesAndNewlines),
            income: input.amount,
            date: input.date,
            note: input.note.trimmingCharacters(in: .whitespacesAndNewlines),
            currencyCode: input.currencyCode,
            payer: input.payer.trimmingCharacters(in: .whitespacesAndNewlines),
            paymentMethod: input.paymentMethod,
            account: input.account,
            incomeType: input.incomeType,
            tags: input.tags
        )

        try repository.add(income)
        Log.info("Saved income \(income.id)", category: .database)
    }
}

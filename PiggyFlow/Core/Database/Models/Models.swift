import Foundation
import SwiftData
import SwiftUI

@Model
final class Expense {
    var id: String = UUID().uuidString
    var type:String = " "
    var emoji: String = ""
    var name: String = ""
    var price: Double = 0
    var date: Date = Date()
    var note: String = ""

    /// Everything below is captured by `AddExpenseView` and is optional — older records, the
    /// quick bottom-sheet form and scanned receipts simply leave these empty. Defaults are
    /// supplied on every property so the store migrates in place rather than being reset.
    var currencyCode: String = AppConstants.Currency.code
    /// Where the money was spent — "Zomato", "Reliance Fresh".
    var merchant: String = ""
    /// How it was paid — "HDFC Bank •••• 2345", "Cash", "UPI".
    var paymentMethod: String = ""
    /// Which of the user's accounts it came out of.
    var account: String = ""
    var tags: [String] = []

    /// How this record was created — `"manual"` (typed in) or `"receipt"` (scanned/uploaded
    /// bill). Decides which editor (`EditExpenseView` vs `EditTransactionView`) a transaction
    /// opens into. Defaults to `"manual"` so every record predating this field keeps the edit
    /// path it already had rather than being silently reclassified.
    var source: String = "manual"
    /// Filename of an attached receipt image inside `ReceiptStorage`'s directory, empty if none.
    var receiptFileName: String = ""

    init(
        type: String,
        emoji: String = "",
        name: String = "",
        price: Double = 0,
        date: Date = Date(),
        note: String = "",
        currencyCode: String = AppConstants.Currency.code,
        merchant: String = "",
        paymentMethod: String = "",
        account: String = "",
        tags: [String] = [],
        source: String = "manual",
        receiptFileName: String = ""
    ) {
        self.type = type
        self.emoji = emoji
        self.name = name
        self.price = price
        self.date = date
        self.note = note
        self.currencyCode = currencyCode
        self.merchant = merchant
        self.paymentMethod = paymentMethod
        self.account = account
        self.tags = tags
        self.source = source
        self.receiptFileName = receiptFileName
    }
}

@Model
final class Income {
    var id: String = UUID().uuidString
    var type:String = " "
    var emoji: String = ""
    var name: String = ""
    var income: Double = 0
    var date: Date = Date()
    var note: String = ""

    /// Everything below is captured by `AddIncomeView` and is optional — older records and
    /// income created from a scanned receipt simply leave these empty. Defaults are supplied
    /// on every property so the store migrates in place rather than being reset.
    var currencyCode: String = AppConstants.Currency.code
    /// Employer or payer the money came from.
    var payer: String = ""
    /// How it arrived — "HDFC Bank •••• 2345", "Cash", "UPI".
    var paymentMethod: String = ""
    /// Which of the user's accounts it landed in.
    var account: String = ""
    /// Sub-classification within the source — "Monthly Salary", "Bonus", "One-time".
    var incomeType: String = ""
    var tags: [String] = []

    init(
        type:String,
        emoji: String = "",
        name: String = "",
        income: Double = 0,
        date: Date = Date(),
        note: String = "",
        currencyCode: String = AppConstants.Currency.code,
        payer: String = "",
        paymentMethod: String = "",
        account: String = "",
        incomeType: String = "",
        tags: [String] = []
    ) {
        self.type = type
        self.emoji = emoji
        self.name = name
        self.income = income
        self.date = date
        self.note = note
        self.currencyCode = currencyCode
        self.payer = payer
        self.paymentMethod = paymentMethod
        self.account = account
        self.incomeType = incomeType
        self.tags = tags
    }
}

/// A user's bank account, card, wallet, or cash — lives in its own local-only store via
/// `AccountManager`, the same pattern `UserCategory`/`UserCategoryManager` already use, rather
/// than the main synced container (see `AccountManager` for why).
@Model
final class Account {
    var id: String = UUID().uuidString
    var name: String = ""
    /// `AccountCategory.rawValue` — drives icon/colour/caption at render time, so those never
    /// need to be stored (and `iconColor` is always `.white` in every real construction, so it
    /// isn't stored at all).
    var categoryRaw: String = AccountCategory.bank.rawValue
    var subType: String = "Savings Account"
    /// Masked, e.g. "•••• 1234" — empty for cash/wallets.
    var accountNumber: String = ""
    /// Signed: negative for a credit card's outstanding balance.
    var balance: Double = 0
    var isCreditCard: Bool = false
    /// Whether this account's balance counts toward the app's net-balance figures.
    var includeInNetBalance: Bool = true

    init(
        name: String,
        categoryRaw: String = AccountCategory.bank.rawValue,
        subType: String = "Savings Account",
        accountNumber: String = "",
        balance: Double = 0,
        isCreditCard: Bool = false,
        includeInNetBalance: Bool = true
    ) {
        self.name = name
        self.categoryRaw = categoryRaw
        self.subType = subType
        self.accountNumber = accountNumber
        self.balance = balance
        self.isCreditCard = isCreditCard
        self.includeInNetBalance = includeInNetBalance
    }

    var category: AccountCategory { AccountCategory(rawValue: categoryRaw) ?? .other }
    var iconName: String { category.iconName }
    var iconBgColor: Color { category.iconBgColor }
    var caption: String { isCreditCard ? "Outstanding" : "Available Balance" }
}

@Model
final class UserCategory {
    var id: String = UUID().uuidString
    var name: String = ""
    var emoji: String = ""
    var budgetLimit: Double = 0

    init(name: String, emoji: String = "", budgetLimit: Double = 0) {
        self.name = name
        self.emoji = emoji
        self.budgetLimit = budgetLimit
    }
}

@Model
final class TrackerRecord {
    var id: String = UUID().uuidString
    var type: String = "subscription" // subscription | emi | bill | budget | goal
    var name: String = ""
    var subType: String = "monthly" // monthly | yearly
    var amount: Double = 0
    var dueDate: Date = Date()
    var logoUrl: String = ""
    var isPaid: Bool = false

    /// Budget's spending-category or Goal's goalCategory — shared field, blank for
    /// subscription/EMI. Not pushed to Firestore yet (see `CloudSyncManager`'s tracker sync
    /// blocks) — local-only for now, same as `Account`.
    var category: String = ""
    /// Goal progress-so-far, toward `amount`. Unused (0) outside goal trackers. Not pushed to
    /// Firestore yet — see `CloudSyncManager`.
    var currentAmount: Double = 0
    /// Free-form notes from the Add Tracker form. Not pushed to Firestore yet — see
    /// `CloudSyncManager`.
    var notes: String = ""

    init(
        type: String = "subscription",
        name: String = "",
        subType: String = "monthly",
        amount: Double = 0,
        dueDate: Date = Date(),
        logoUrl: String = "",
        isPaid: Bool = false,
        category: String = "",
        currentAmount: Double = 0,
        notes: String = ""
    ) {
        self.type = type
        self.name = name
        self.subType = subType
        self.amount = amount
        self.dueDate = dueDate
        self.logoUrl = logoUrl
        self.isPaid = isPaid
        self.category = category
        self.currentAmount = currentAmount
        self.notes = notes
    }
}

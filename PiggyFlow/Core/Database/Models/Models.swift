import Foundation
import SwiftData

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
        tags: [String] = []
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
    var type: String = "subscription" // subscription | emi | bill
    var name: String = ""
    var subType: String = "monthly" // monthly | yearly
    var amount: Double = 0
    var dueDate: Date = Date()
    var logoUrl: String = ""
    var isPaid: Bool = false

    init(
        type: String = "subscription",
        name: String = "",
        subType: String = "monthly",
        amount: Double = 0,
        dueDate: Date = Date(),
        logoUrl: String = "",
        isPaid: Bool = false
    ) {
        self.type = type
        self.name = name
        self.subType = subType
        self.amount = amount
        self.dueDate = dueDate
        self.logoUrl = logoUrl
        self.isPaid = isPaid
    }
}

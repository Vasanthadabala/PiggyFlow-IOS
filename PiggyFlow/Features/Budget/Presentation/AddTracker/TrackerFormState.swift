import SwiftUI

/// What kind of thing is being tracked.
///
/// The four types share one screen because they share most of a form — a name, an amount,
/// a date, a reminder, an icon. Splitting them into four screens would duplicate that and
/// make switching between them (which people do while deciding) a navigation problem.
enum TrackerKind: String, CaseIterable, Identifiable, Hashable {
    case budget = "Budget"
    case goal = "Goal"
    case subscription = "Subscription"
    case emi = "EMI / Loan"

    var id: String { rawValue }

    var tabIcon: String {
        switch self {
        case .budget:       return "target"
        case .goal:         return "star.circle"
        case .subscription: return "calendar.badge.clock"
        case .emi:          return "house"
        }
    }

    var screenTitle: String {
        switch self {
        // Every other case names itself; budget was the one generic "Add Tracker" title.
        case .budget:       return "Add Budget"
        case .goal:         return "Add Goal Tracker"
        case .subscription: return "Add Subscription"
        case .emi:          return "Add EMI / Loan Tracker"
        }
    }

    var screenSubtitle: String {
        switch self {
        // Kept short enough to sit on one line beside the back button and Templates action,
        // so the header is the same height whichever tracker type is selected.
        case .budget:       return "Track what matters, stay on target"
        case .goal:         return "Track your goal, celebrate milestones"
        case .subscription: return "Track renewals, never miss one"
        case .emi:          return "Track your loans, never miss an EMI"
        }
    }

    var ctaTitle: String {
        switch self {
        case .budget:       return "Create Budget"
        case .goal:         return "Create Goal Tracker"
        case .subscription: return "Create Subscription"
        case .emi:          return "Create EMI / Loan Tracker"
        }
    }

    /// Value written to `TrackerRecord.type`.
    var storageType: String {
        switch self {
        case .budget:       return "budget"
        case .goal:         return "goal"
        case .subscription: return "subscription"
        case .emi:          return "emi"
        }
    }

    var defaultIcon: String {
        switch self {
        case .budget:       return "cart.fill"
        case .goal:         return "trophy.fill"
        case .subscription: return "play.rectangle.fill"
        case .emi:          return "house.fill"
        }
    }

    /// Icons offered by the picker for this type.
    var iconChoices: [String] {
        switch self {
        case .budget:
            return ["cart.fill", "fork.knife", "car.fill", "bolt.fill", "bag.fill", "heart.fill", "book.fill", "cross.case.fill"]
        case .goal:
            return ["trophy.fill", "airplane", "house.fill", "car.fill", "graduationcap.fill", "heart.fill", "gift.fill", "shield.fill"]
        case .subscription:
            return ["play.rectangle.fill", "music.note", "icloud.fill", "briefcase.fill", "gamecontroller.fill", "book.fill", "newspaper.fill", "dumbbell.fill"]
        case .emi:
            return ["house.fill", "car.fill", "graduationcap.fill", "creditcard.fill", "building.2.fill", "briefcase.fill"]
        }
    }
}

/// A milestone on the way to a goal — "50% of goal, ₹25,000".
struct GoalMilestone: Identifiable, Hashable {
    let id = UUID()
    var percent: Int

    func amount(of target: Double) -> Double {
        target * Double(percent) / 100
    }
}

/// Every field across the four forms.
///
/// One flat struct rather than four: switching tracker type mid-entry keeps what was already
/// typed, so picking "Budget" and then realising it's a Goal doesn't cost the user the title
/// and amount they just entered.
struct TrackerFormState {

    // Shared
    var title: String = ""
    var category: String = "Food & Dining"
    var amount: String = ""
    var currency: String = "INR (₹)"
    var reminder: String = "On due date"
    var notes: String = ""
    var icon: String = TrackerKind.budget.defaultIcon
    var color: Color = Color(red: 147/255, green: 51/255, blue: 234/255)

    // Budget
    var period: String = "Monthly"
    var startDate: Date? = Date()
    var endDate: Date? = nil

    // Goal
    var goalCategory: String = "Shopping"
    var priority: String = "Medium"
    var currentAmount: String = ""
    var targetDate: Date? = Date()
    var milestones: [GoalMilestone] = [
        GoalMilestone(percent: 25),
        GoalMilestone(percent: 50),
        GoalMilestone(percent: 75)
    ]

    // Subscription
    var subscriptionCategory: String = "Entertainment"
    var billingCycle: String = "Monthly"
    var nextBillingDate: Date? = Date()
    var paymentMethod: String = "HDFC Bank •••• 2345"
    var account: String = "Personal Account"
    var vendor: String = ""
    var autoDeducts: Bool = true

    // EMI / Loan
    var loanType: String = "Home Loan"
    var lender: String = "HDFC Bank"
    var loanAmount: String = ""
    var interestRate: String = ""
    var emiAmount: String = ""
    var tenure: String = "20 Years"
    var emiStartDate: Date? = Date()
    var nextEMIDate: Date? = Date()
    var paymentAccount: String = "HDFC Bank •••• 2345"

    // MARK: - Derived values

    var amountValue: Double { Self.number(amount) }
    var currentAmountValue: Double { Self.number(currentAmount) }
    var loanAmountValue: Double { Self.number(loanAmount) }
    var interestRateValue: Double { Self.number(interestRate) }
    var enteredEMIValue: Double { Self.number(emiAmount) }

    /// Tenure in months, parsed from the picker label ("20 Years", "18 Months").
    var tenureMonths: Int {
        let digits = tenure.filter(\.isNumber)
        let value = Int(digits) ?? 0
        return tenure.localizedCaseInsensitiveContains("year") ? value * 12 : value
    }

    /// Standard reducing-balance EMI. Zero interest falls back to simple division so the
    /// summary still reads sensibly while the rate field is empty.
    var computedEMI: Double {
        let principal = loanAmountValue
        let months = Double(tenureMonths)
        guard principal > 0, months > 0 else { return 0 }

        let monthlyRate = interestRateValue / 12 / 100
        guard monthlyRate > 0 else { return principal / months }

        let growth = pow(1 + monthlyRate, months)
        return principal * monthlyRate * growth / (growth - 1)
    }

    /// What the summary card uses — the typed EMI wins, the computed one fills the gap.
    var effectiveEMI: Double {
        enteredEMIValue > 0 ? enteredEMIValue : computedEMI
    }

    var totalPayable: Double { effectiveEMI * Double(tenureMonths) }
    var totalInterest: Double { max(totalPayable - loanAmountValue, 0) }

    /// Billing periods per year, for the subscription's annual cost.
    var billingPeriodsPerYear: Double {
        switch billingCycle {
        case "Weekly":      return 52
        case "Monthly":     return 12
        case "Quarterly":   return 4
        case "Half-Yearly": return 2
        case "Yearly":      return 1
        default:            return 12
        }
    }

    var annualSubscriptionCost: Double { amountValue * billingPeriodsPerYear }

    /// "every month" / "every year" — reads naturally after the amount.
    var billingCadencePhrase: String {
        switch billingCycle {
        case "Weekly":      return "every week"
        case "Monthly":     return "every month"
        case "Quarterly":   return "every quarter"
        case "Half-Yearly": return "every 6 months"
        case "Yearly":      return "every year"
        default:            return "every month"
        }
    }

    /// Whether the primary action can be taken for a given type.
    func isValid(for kind: TrackerKind) -> Bool {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }

        switch kind {
        case .budget, .goal, .subscription:
            return amountValue > 0
        case .emi:
            return loanAmountValue > 0 && effectiveEMI > 0
        }
    }

    /// The date this tracker is due next — what lands in `TrackerRecord.dueDate`.
    func dueDate(for kind: TrackerKind) -> Date {
        switch kind {
        case .budget:       return startDate ?? Date()
        case .goal:         return targetDate ?? Date()
        case .subscription: return nextBillingDate ?? Date()
        case .emi:          return nextEMIDate ?? Date()
        }
    }

    /// The amount stored against the record.
    func storedAmount(for kind: TrackerKind) -> Double {
        kind == .emi ? effectiveEMI : amountValue
    }

    /// The recurrence written to `TrackerRecord.subType`.
    func storedSubType(for kind: TrackerKind) -> String {
        switch kind {
        case .budget:       return period.lowercased()
        case .goal:         return priority.lowercased()
        case .subscription: return billingCycle.lowercased()
        case .emi:          return "monthly"
        }
    }

    /// The spending/goal category written to `TrackerRecord.category` — Budget's own category
    /// picker for budgets, Goal's `goalCategory` for goals, blank for subscription/EMI (neither
    /// has a category concept in the form).
    func storedCategory(for kind: TrackerKind) -> String {
        switch kind {
        case .budget: return category
        case .goal:   return goalCategory
        case .subscription, .emi: return ""
        }
    }

    private static func number(_ text: String) -> Double {
        Double(text.filter { $0.isNumber || $0 == "." }) ?? 0
    }
}

// MARK: - Shared option sets

enum TrackerOptions {
    static let expenseCategories: [TrackerOption] = [
        TrackerOption(name: "Food & Dining", icon: "fork.knife"),
        TrackerOption(name: "Shopping", icon: "cart.fill"),
        TrackerOption(name: "Transport", icon: "car.fill"),
        TrackerOption(name: "Utilities", icon: "bolt.fill"),
        TrackerOption(name: "Entertainment", icon: "play.rectangle.fill"),
        TrackerOption(name: "Health", icon: "cross.case.fill"),
        TrackerOption(name: "Education", icon: "graduationcap.fill"),
        TrackerOption(name: "Rent", icon: "house.fill"),
        TrackerOption(name: "Others", icon: "ellipsis.circle.fill")
    ]

    static let goalCategories: [TrackerOption] = [
        TrackerOption(name: "Shopping", icon: "bag.fill"),
        TrackerOption(name: "Travel", icon: "airplane"),
        TrackerOption(name: "Home", icon: "house.fill"),
        TrackerOption(name: "Vehicle", icon: "car.fill"),
        TrackerOption(name: "Education", icon: "graduationcap.fill"),
        TrackerOption(name: "Emergency Fund", icon: "shield.fill"),
        TrackerOption(name: "Investment", icon: "chart.line.uptrend.xyaxis"),
        TrackerOption(name: "Others", icon: "ellipsis.circle.fill")
    ]

    static let priorities: [TrackerOption] = [
        TrackerOption(name: "High", icon: "exclamationmark.circle.fill", tint: .appExpenseRed),
        TrackerOption(name: "Medium", icon: "equal.circle.fill", tint: .appWarningAmber),
        TrackerOption(name: "Low", icon: "arrow.down.circle.fill", tint: .appGreen)
    ]

    static let periods: [TrackerOption] = [
        TrackerOption(name: "Weekly", icon: "calendar"),
        TrackerOption(name: "Monthly", icon: "calendar"),
        TrackerOption(name: "Quarterly", icon: "calendar"),
        TrackerOption(name: "Half-Yearly", icon: "calendar"),
        TrackerOption(name: "Yearly", icon: "calendar"),
        TrackerOption(name: "One-time", icon: "calendar.badge.clock")
    ]

    static let billingCycles: [TrackerOption] = [
        TrackerOption(name: "Weekly", icon: "calendar.badge.clock"),
        TrackerOption(name: "Monthly", icon: "calendar.badge.clock"),
        TrackerOption(name: "Quarterly", icon: "calendar.badge.clock"),
        TrackerOption(name: "Half-Yearly", icon: "calendar.badge.clock"),
        TrackerOption(name: "Yearly", icon: "calendar.badge.clock")
    ]

    /// Real accounts the user has added — falls back to a single placeholder so `[0]`-indexing
    /// call sites never crash before the user has added their first real account.
    static func accounts() -> [TrackerOption] {
        let real = AccountManager.shared.accounts.map { TrackerOption(name: $0.name, icon: $0.iconName) }
        return real.isEmpty ? [TrackerOption(name: "Cash", icon: "banknote.fill")] : real
    }

    static let paymentMethods: [TrackerOption] = [
        TrackerOption(name: "HDFC Bank •••• 2345", icon: "building.columns.fill"),
        TrackerOption(name: "ICICI Bank •••• 8890", icon: "building.columns.fill"),
        TrackerOption(name: "SBI Credit Card •••• 4412", icon: "creditcard.fill"),
        TrackerOption(name: "UPI", icon: "indianrupeesign.circle.fill"),
        TrackerOption(name: "Cash", icon: "banknote.fill")
    ]

    static let loanTypes: [TrackerOption] = [
        TrackerOption(name: "Home Loan", icon: "house.fill"),
        TrackerOption(name: "Car Loan", icon: "car.fill"),
        TrackerOption(name: "Personal Loan", icon: "person.fill"),
        TrackerOption(name: "Education Loan", icon: "graduationcap.fill"),
        TrackerOption(name: "Business Loan", icon: "briefcase.fill"),
        TrackerOption(name: "Gold Loan", icon: "seal.fill")
    ]

    static let lenders: [TrackerOption] = [
        TrackerOption(name: "HDFC Bank", icon: "building.columns.fill"),
        TrackerOption(name: "ICICI Bank", icon: "building.columns.fill"),
        TrackerOption(name: "State Bank of India", icon: "building.columns.fill"),
        TrackerOption(name: "Axis Bank", icon: "building.columns.fill"),
        TrackerOption(name: "Kotak Mahindra Bank", icon: "building.columns.fill"),
        TrackerOption(name: "Other", icon: "building.2.fill")
    ]

    static let tenures: [TrackerOption] = {
        let years = [1, 2, 3, 5, 7, 10, 15, 20, 25, 30]
        return years.map { TrackerOption(name: "\($0) Year\($0 == 1 ? "" : "s")", icon: "calendar") }
    }()
}

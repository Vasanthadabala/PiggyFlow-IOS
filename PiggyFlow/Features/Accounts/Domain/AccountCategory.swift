import SwiftUI

/// The kind of account a user can add — drives icon, colour and helper caption everywhere
/// an account is picked or displayed. Shared between the `Account` model and every view that
/// renders one, so it can't live inside a single Presentation-layer file.
enum AccountCategory: String, CaseIterable, Identifiable {
    case bank = "Bank Account"
    case creditCard = "Credit Card"
    case eWallet = "E-Wallet"
    case cash = "Cash"
    case business = "Business Account"
    case other = "Other"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .bank: return "building.columns.fill"
        case .creditCard: return "creditcard.fill"
        case .eWallet: return "wallet.pass.fill"
        case .cash: return "banknote.fill"
        case .business: return "briefcase.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }

    var iconBgColor: Color {
        switch self {
        case .bank: return Color.appGreen
        case .creditCard: return Color(red: 153/255, green: 27/255, blue: 60/255)
        case .eWallet: return Color(red: 30/255, green: 64/255, blue: 175/255)
        case .cash: return Color(red: 217/255, green: 119/255, blue: 6/255)
        case .business: return Color(red: 109/255, green: 40/255, blue: 217/255)
        case .other: return Color(.systemGray)
        }
    }

    var caption: String {
        switch self {
        case .bank: return "Savings, Current or Salary Account"
        case .creditCard: return "Add your credit card to track spends and payments"
        case .eWallet: return "UPI, Paytm, PhonePe, Amazon Pay and more"
        case .cash: return "Physical cash in hand"
        case .business: return "Business or company account"
        case .other: return "Investments, Loans, Pocket Money and more"
        }
    }
}

enum AccountSubType: String, CaseIterable {
    case savings = "Savings Account"
    case current = "Current Account"
    case salary = "Salary Account"
    case creditCard = "Credit Card"

    var id: String { rawValue }
}

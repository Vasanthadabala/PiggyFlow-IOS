import SwiftUI
#if os(iOS)
import UIKit
#endif

/// The app's colour palette.
///
/// Green is the brand/primary accent. Red, indigo and amber are *semantic only* —
/// they carry meaning (expense, budget, due-soon) and are never used decoratively.
/// Everything else is drawn from the neutral surface tokens below.
extension Color {
    /// Modern Emerald Brand Green
    static let appGreen = Color(red: 14/255, green: 159/255, blue: 110/255)

    /// Deep gradient partner for the brand green — pairs with appGreen in gradient heroes.
    static let appGreenDeep = Color(red: 8/255, green: 107/255, blue: 74/255)

    /// Deep Ocean Teal Accent
    static let appTeal = Color(red: 20/255, green: 184/255, blue: 166/255)

    /// Crisp Expense Red
    static let appExpenseRed = Color(red: 229/255, green: 81/255, blue: 79/255)

    /// Deep gradient partner for expense red.
    static let appExpenseRedDeep = Color(red: 176/255, green: 48/255, blue: 47/255)

    /// Warning / EMI Amber
    static let appWarningAmber = Color(red: 239/255, green: 162/255, blue: 58/255)

    /// Budget / Financial Insight Indigo
    static let appIndigo = Color(red: 91/255, green: 95/255, blue: 239/255)

    /// Deep gradient partner for indigo.
    static let appIndigoDeep = Color(red: 61/255, green: 64/255, blue: 189/255)

    /// App-wide background canvas color: #F8FAF8 (RGB 248, 250, 248) everywhere in the app
    static let appBackground = Color(red: 248/255, green: 250/255, blue: 248/255)

    /// Elevated card & component surface: Pure White (#FFFFFF) everywhere in the app
    static let appSurface = Color.white
}

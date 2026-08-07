import SwiftUI

/// Every screen that can be pushed onto a navigation stack.
///
/// Screens are currently reached via `NavigationLink(destination:)`, which hardcodes the
/// destination at the call site — so a screen can't be opened from a notification, a deep
/// link, or a sibling tab without duplicating the construction. This enum is the value-typed
/// alternative: push a `NavigationDestination` onto `AppRouter.path` and let
/// `navigationDestination(for:)` build the view.
enum NavigationDestination: Hashable {
    case accounts
    case addAccount
    case notifications
    case profile
    case settings
    case about
    case reports
    case reportDetail
    case insights
    case stats
    case upcomingPayments
    case recentTransactions
    case tracker
    case budgetGoals
    /// Carries the tab to open on — a caller that already knows it's adding a subscription
    /// shouldn't drop the user on the Budget form.
    case addTracker(kind: TrackerKind)
}

extension NavigationDestination {

    /// Builds the screen for a destination.
    ///
    /// `@ViewBuilder` + `hidesTabBarOnPush()` in one place means a pushed screen can never
    /// forget to hide the floating tab bar.
    @ViewBuilder
    var view: some View {
        switch self {
        case .accounts:            AccountsView().hidesTabBarOnPush()
        case .addAccount:          AddAccountView().hidesTabBarOnPush()
        case .notifications:       NotificationView().hidesTabBarOnPush()
        case .profile:             ProfileView().hidesTabBarOnPush()
        case .settings:            SettingsView().hidesTabBarOnPush()
        case .about:               AboutView().hidesTabBarOnPush()
        case .reports:             ReportsView().hidesTabBarOnPush()
        case .reportDetail:        ReportDetailView().hidesTabBarOnPush()
        case .insights:            FinancialInsightsView().hidesTabBarOnPush()
        case .stats:               StatsView().hidesTabBarOnPush()
        case .upcomingPayments:    UpcomingPaymentsView().hidesTabBarOnPush()
        case .recentTransactions:  RecentTransactionsView().hidesTabBarOnPush()
        case .tracker:             TrackerView().hidesTabBarOnPush()
        case .budgetGoals:         BudgetGoalsView().hidesTabBarOnPush()
        case .addTracker(let kind): AddTrackerView(initialKind: kind).hidesTabBarOnPush()
        }
    }
}

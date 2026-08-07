import SwiftUI
import Combine

/// Coordinates the per-tab routers plus the selected tab itself.
///
/// One instance lives at the app root, so anything can address "the Reports tab, showing
/// report detail" regardless of where the request came from — a push notification, a
/// widget tap, or a button three screens deep in another tab.
///
/// Each tab keeps its own `AppRouter` so switching tabs preserves where you were, which is
/// what iOS users expect.
@MainActor
final class NavigationCoordinator: ObservableObject {

    @Published var selectedTab: MainTabView.TabItem = .home

    let home = AppRouter()
    let expenses = AppRouter()
    let tracker = AppRouter()
    let reports = AppRouter()

    /// The router backing the currently visible tab.
    var activeRouter: AppRouter {
        router(for: selectedTab)
    }

    func router(for tab: MainTabView.TabItem) -> AppRouter {
        switch tab {
        case .home:     return home
        case .expenses: return expenses
        case .tracker:  return tracker
        case .reports:  return reports
        }
    }

    /// Switches tab and pushes a destination there — the entry point for deep links.
    func navigate(to destination: NavigationDestination, in tab: MainTabView.TabItem) {
        selectedTab = tab
        router(for: tab).push(destination)
    }

    /// Returns to a tab's root, or switches to it if it isn't selected — the standard
    /// "tap the active tab again" behaviour.
    func selectOrPopToRoot(_ tab: MainTabView.TabItem) {
        if selectedTab == tab {
            router(for: tab).popToRoot()
        } else {
            selectedTab = tab
        }
    }

    /// Clears every tab's stack, e.g. on sign-out.
    func resetAll() {
        [home, expenses, tracker, reports].forEach { $0.popToRoot() }
        selectedTab = .home
    }
}

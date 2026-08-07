import SwiftUI
import Combine

/// Owns the navigation stack for one tab.
///
/// Holding the path as state means code that isn't a view — a notification handler, a deep
/// link, a "view report" action buried in a sheet — can drive navigation, and lets a flow
/// unwind itself (`popToRoot()` after saving) instead of relying on the user tapping Back.
@MainActor
final class AppRouter: ObservableObject {

    /// The pushed screens, in order.
    @Published var path: [NavigationDestination] = []

    /// The sheet currently presented over this stack, if any.
    @Published var presentedSheet: NavigationDestination?

    // MARK: - Stack

    func push(_ destination: NavigationDestination) {
        path.append(destination)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path.removeAll()
    }

    /// Replaces the stack wholesale — used for deep links that land several levels deep.
    func setPath(_ destinations: [NavigationDestination]) {
        path = destinations
    }

    // MARK: - Sheets

    func present(_ destination: NavigationDestination) {
        presentedSheet = destination
    }

    func dismissSheet() {
        presentedSheet = nil
    }
}

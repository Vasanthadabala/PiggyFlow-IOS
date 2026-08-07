import Combine
import SwiftUI

/// Controls whether `MainTabView`'s floating tab bar is shown.
///
/// The tab bar is rendered by `MainTabView` *outside* each tab's own `NavigationStack`,
/// so pushed detail screens (Transaction Details, Profile, About, Notifications) can't
/// hide it via `.toolbar(.hidden, for: .tabBar)`. They set `isHidden` here instead —
/// typically `.onAppear { isHidden = true }` / `.onDisappear { isHidden = false }`.
///
/// Injected into the tab hierarchy by `MainTabView` as an `@EnvironmentObject`.
final class TabBarVisibility: ObservableObject {
    @Published var isHidden: Bool = false
}

/// Apply to every `NavigationLink` destination in the app (including ones that happen to
/// reuse a tab-root view like `TrackerView`/`ReportsView`) so the floating tab bar hides
/// on any pushed screen and only ever shows on the four screens actually selected via the
/// tab bar itself. Centralising this at the push site — rather than inside each destination
/// view — avoids the tab root/pushed-destination ambiguity for views used both ways.
struct HidesTabBarOnPush: ViewModifier {
    @EnvironmentObject private var tabBarVisibility: TabBarVisibility

    func body(content: Content) -> some View {
        content
            .onAppear { tabBarVisibility.isHidden = true }
            .onDisappear { tabBarVisibility.isHidden = false }
    }
}

extension View {
    func hidesTabBarOnPush() -> some View {
        modifier(HidesTabBarOnPush())
    }
}

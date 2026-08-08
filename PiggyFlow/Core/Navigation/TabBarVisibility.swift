import Combine
import SwiftUI

/// Controls whether `MainTabView`'s floating tab bar is shown.
///
/// The tab bar is rendered by `MainTabView` *outside* each tab's own `NavigationStack`,
/// so pushed detail screens (Transaction Details, Profile, About, Notifications) can't
/// hide it via `.toolbar(.hidden, for: .tabBar)`. They register here instead, by way of
/// `.hidesTabBarOnPush()` at the push site.
///
/// Injected into the tab hierarchy by `MainTabView` as an `@EnvironmentObject`.
final class TabBarVisibility: ObservableObject {
    @Published private(set) var isHidden: Bool = false

    /// One entry per pushed screen currently asking for the bar to stay hidden.
    ///
    /// A single `Bool` couldn't survive a push from one hidden screen onto another: SwiftUI
    /// fires the incoming screen's `onAppear` *before* the outgoing screen's `onDisappear`,
    /// so `Profile → Personal Info` set the flag true and then immediately back to false,
    /// floating the bar over that screen and over Profile again on the way back. Tracking the
    /// set of screens means the bar only returns once the last of them is gone, and keying by
    /// screen makes a repeated `onAppear` idempotent rather than an unbalanced increment that
    /// could strand the bar off-screen for good.
    private var hidingScreens: Set<UUID> = []

    func beginHiding(_ screen: UUID) {
        hidingScreens.insert(screen)
        isHidden = !hidingScreens.isEmpty
    }

    func endHiding(_ screen: UUID) {
        hidingScreens.remove(screen)
        isHidden = !hidingScreens.isEmpty
    }

    /// Safety valve for switching tabs, which tears down a whole stack at once: anything left
    /// registered by the outgoing tab has no way to send its own `onDisappear`.
    func reset() {
        hidingScreens.removeAll()
        isHidden = false
    }
}

/// Apply to every `NavigationLink` destination in the app (including ones that happen to
/// reuse a tab-root view like `TrackerView`/`ReportsView`) so the floating tab bar hides
/// on any pushed screen and only ever shows on the four screens actually selected via the
/// tab bar itself. Centralising this at the push site — rather than inside each destination
/// view — avoids the tab root/pushed-destination ambiguity for views used both ways.
struct HidesTabBarOnPush: ViewModifier {
    @EnvironmentObject private var tabBarVisibility: TabBarVisibility

    /// Identifies this particular pushed screen for as long as it keeps its view identity, so
    /// its `onAppear`/`onDisappear` pair can never be mistaken for another screen's.
    @State private var screenID = UUID()

    func body(content: Content) -> some View {
        content
            .onAppear { tabBarVisibility.beginHiding(screenID) }
            .onDisappear { tabBarVisibility.endHiding(screenID) }
    }
}

extension View {
    func hidesTabBarOnPush() -> some View {
        modifier(HidesTabBarOnPush())
    }
}

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: TabItem = .home
    @State private var showAddExpenseSheet: Bool = false
    @StateObject private var tabBarVisibility = TabBarVisibility()

    enum TabItem: String, CaseIterable, Identifiable {
        case home = "Home"
        case expenses = "Expenses"
        case tracker = "Tracker"
        case reports = "Reports"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .home: return "house"
            case .expenses: return "doc.text"
            case .tracker: return "calendar.badge.checkmark"
            case .reports: return "chart.bar"
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .home:
                    HomeView()
                case .expenses:
                    ExpensesView()
                case .tracker:
                    TrackerView()
                case .reports:
                    ReportsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .environmentObject(tabBarVisibility)
            // Switching tabs discards the outgoing tab's whole navigation stack, so any
            // screen still registered there would otherwise keep the bar hidden forever.
            .onChange(of: selectedTab) { _, _ in
                tabBarVisibility.reset()
            }

            // Floating Capsule Bottom Tab Bar — hidden on pushed detail screens
            if !tabBarVisibility.isHidden {
                customTabBar
                    .padding(.horizontal, 20)
                    .padding(.bottom, 14)
                    // Slides down off the edge rather than fading in place: the bar is a
                    // capsule floating over the page, so it should travel back to its resting
                    // spot the way a sheet does. A bare cross-fade made it materialise mid-air
                    // over whichever screen the pop was still animating.
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        // Full screen rather than a sheet: the chooser grid now carries a proper header and
        // fills the page, not a half-height card.
        .fullScreenCover(isPresented: $showAddExpenseSheet) {
            AddExpenseBottomSheetView(itemToEdit: nil)
        }
        // Asymmetric on purpose: leaving, the bar should clear the way promptly so it never
        // competes with the push animation; returning, it settles back with a little weight,
        // which reads as the bar coming home rather than blinking into existence.
        .animation(
            tabBarVisibility.isHidden
                ? .easeOut(duration: 0.13)
                : .spring(response: 0.28, dampingFraction: 0.86),
            value: tabBarVisibility.isHidden
        )
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    /// The capsule's own fill — shared with the FAB's halo ring so the two are guaranteed
    /// to match rather than risk drifting if one is edited without the other. Uses the same
    /// token every other card does, rather than a system grouped-background gray, so the
    /// floating bar — the one surface visible on literally every screen — reads as the same
    /// material as the rest of the UI.
    private var tabBarFill: Color { Color.appSurface }

    private var customTabBar: some View {
        HStack(spacing: 0) {
            // Tab 1: Home
            tabButton(for: .home)

            // Tab 2: Expenses
            tabButton(for: .expenses)

            // Center FAB — a "+" that rotates into an "X" while its sheet is open
            Button {
                Haptics.medium()
                showAddExpenseSheet.toggle()
            } label: {
                ZStack {
                    // Halo ring in the bar's own fill: where it overlaps the capsule it
                    // vanishes into it, and where it floats free above the bar it reads as
                    // a soft cutout the button sits in, rather than a disc simply laid on top.
                    Circle()
                        .fill(tabBarFill)
                        .frame(width: 62, height: 62)

                    // The brand gradient, matching the hero cards elsewhere, plus the same
                    // glossy-highlight / grounding-shadow pair those cards use — so the FAB
                    // reads as the same material rather than a flat single-colour disc.
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.appGreen, .appGreenDeep],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            ZStack {
                                Circle().fill(RadialGradient(colors: [.white.opacity(0.28), .clear], center: .topLeading, startRadius: 2, endRadius: 30))
                                Circle().fill(RadialGradient(colors: [.black.opacity(0.16), .clear], center: .bottomTrailing, startRadius: 2, endRadius: 32))
                            }
                        )
                        .frame(width: 54, height: 54)
                        .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)

                    Image(systemName: "plus")
                        .font(.system(size: 23, weight: .bold))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(showAddExpenseSheet ? 45 : 0))
                }
            }
            .buttonStyle(.plain)
            // Floats clear of the bar so the halo and shadow have room to read as elevation.
            .offset(y: -18)
            .frame(maxWidth: .infinity)
            .animation(.spring(response: 0.3, dampingFraction: 0.65), value: showAddExpenseSheet)

            // Tab 3: Tracker
            tabButton(for: .tracker)

            // Tab 4: Reports
            tabButton(for: .reports)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(tabBarFill)
                .shadow(color: Color.black.opacity(0.1), radius: 16, x: 0, y: 6)
        )
    }

    @ViewBuilder
    private func tabButton(for tab: TabItem) -> some View {
        Button {
            if selectedTab != tab {
                Haptics.light()
            }
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 20, weight: selectedTab == tab ? .bold : .medium))
                    .foregroundColor(selectedTab == tab ? .appGreen : .primary.opacity(0.45))

                Text(tab.rawValue)
                    .font(.system(size: 10.5, weight: selectedTab == tab ? .bold : .medium, design: .rounded))
                    .foregroundColor(selectedTab == tab ? .appGreen : .primary.opacity(0.45))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MainTabView()
}

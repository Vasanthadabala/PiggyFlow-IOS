import SwiftUI
import SwiftData

/// Root UI switch: shows onboarding until the user is signed in, then the main tab bar.
///
/// Also drives cloud sync lifecycle — kicking off the initial restore on login and
/// running the periodic auto-sync check whenever the app returns to the foreground.
///
/// Previously named `RootView` and declared alongside `PiggyFlowApp`; split out so the
/// entry point (`App.swift`) holds only process setup.
struct ContentView: View {
    @EnvironmentObject var appleSignInManager: AppleSignInManager
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppleSignInManager.loginStatusKey) private var isUserLoggedIn: Bool = false
    @AppStorage("autoSyncEnabled") private var autoSyncEnabled: Bool = false
    @AppStorage("firebaseLastSyncDate") private var firebaseLastSyncDate: Double = 0

    /// Auto Sync only fires while the app is open (foreground) — there's no background-task
    /// entitlement wired up, so this checks on every foreground transition rather than truly
    /// running unattended every 12 hours.
    private let autoSyncInterval: TimeInterval = 12 * 60 * 60

    var body: some View {
        Group {
            if isUserLoggedIn || appleSignInManager.isAuthenticated {
                MainTabView()
            } else {
                OnBoardingScreen()
            }
        }
        .onAppear {
            // If Firebase already has a signed-in user, this flips isAuthenticated and opens home.
            appleSignInManager.checkExistingCredentials()
            if isUserLoggedIn || appleSignInManager.isAuthenticated {
                CloudSyncManager.shared.handleLoginIfNeeded(context: context)
            }
            runAutoSyncIfDue()
        }
        .onChange(of: appleSignInManager.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                CloudSyncManager.shared.handleLoginIfNeeded(context: context)
            }
        }
        .onChange(of: isUserLoggedIn) { _, isLoggedIn in
            if isLoggedIn {
                CloudSyncManager.shared.handleLoginIfNeeded(context: context)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                runAutoSyncIfDue()
            }
        }
    }

    private func runAutoSyncIfDue() {
        guard autoSyncEnabled, appleSignInManager.isAuthenticated else { return }
        let elapsed = Date().timeIntervalSince1970 - firebaseLastSyncDate
        guard elapsed >= autoSyncInterval else { return }

        Task {
            let success = await CloudSyncManager.shared.syncNow(context: context)
            if success {
                await MainActor.run {
                    firebaseLastSyncDate = Date().timeIntervalSince1970
                }
            }
        }
    }
}

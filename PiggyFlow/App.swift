import SwiftUI
import SwiftData

#if canImport(FirebaseCore)
import FirebaseCore
#endif

#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

/// Application entry point.
///
/// Owns process-wide setup (Firebase configuration, the SwiftData container, app-level
/// auth state) and hands the UI off to `ContentView`, which decides between onboarding
/// and the main tab bar.
@main
struct PiggyFlowApp: App {
    @StateObject private var appleSignInManager = AppleSignInManager()
    @AppStorage("username") private var userName: String = ""

    init() {
#if canImport(FirebaseCore)
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
#endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(.appGreen)
                .environmentObject(appleSignInManager)
                .environmentObject(DataManager.shared)
                .modelContainer(DataManager.shared.localContainer)
                .onOpenURL { url in
#if canImport(GoogleSignIn)
                    _ = GIDSignIn.sharedInstance.handle(url)
#endif
                }
        }
    }
}

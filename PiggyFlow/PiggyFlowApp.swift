import SwiftUI
import SwiftData

#if canImport(FirebaseCore)
import FirebaseCore
#endif

#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

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
            RootView()
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

struct RootView: View {
    @EnvironmentObject var appleSignInManager: AppleSignInManager
    @Environment(\.modelContext) private var context
    @AppStorage(AppleSignInManager.loginStatusKey) private var isUserLoggedIn: Bool = false
    
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
    }
}

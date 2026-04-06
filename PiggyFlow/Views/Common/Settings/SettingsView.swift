import SwiftUI
import SwiftData
import UserNotifications
import UIKit
import AuthenticationServices
import CryptoKit

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

#if canImport(FirebaseCore)
import FirebaseCore
#endif

#if canImport(GoogleSignIn)
import GoogleSignIn
import Combine
#endif

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage("username") private var userName: String = ""
    @AppStorage("userEmail") private var userEmail: String = ""
    @AppStorage(AccountType.storageKey) private var selectedAccountType: String = AccountType.personal.rawValue
    @AppStorage("firebaseLastSyncDate") private var firebaseLastSyncDate: Double = 0

    @StateObject private var settingsAuth = SettingsAuthService()
    @ObservedObject private var cloudSync = CloudSyncManager.shared
    @State private var showClearLocalDataAlert = false
    @State private var showComingSoonToast = false
    @State private var syncInProgress = false

    private enum ConnectedProvider {
        case google
        case apple
    }

    private var displayName: String {
        let trimmed = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Guest" : trimmed
    }

    private var initials: String {
        String(displayName.prefix(1)).uppercased()
    }

    private var accountTypeTitle: String {
        (AccountType(rawValue: selectedAccountType) ?? .personal).shortTitle
    }

    private var connectionStatusText: String {
        userEmail.isEmpty ? "Not connected" : "Connected"
    }

    private var connectedProvider: ConnectedProvider? {
#if canImport(FirebaseAuth)
        guard let currentUser = Auth.auth().currentUser else { return nil }
        let providerIDs = Set(currentUser.providerData.map(\.providerID))
        if providerIDs.contains("google.com") { return .google }
        if providerIDs.contains("apple.com") { return .apple }
        return nil
#else
        return nil
#endif
    }

    private var connectedEmailText: String {
#if canImport(FirebaseAuth)
        if let email = Auth.auth().currentUser?.email, !email.isEmpty {
            return email
        }
#endif
        let trimmed = userEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Email unavailable" : trimmed
    }

    private var syncSubtitle: String {
        if cloudSync.isRestoringFromCloud {
            return "Restoring backup data from Firebase..."
        }
        if syncInProgress {
            return "Syncing your latest data..."
        }
        guard firebaseLastSyncDate > 0 else {
            return "Sync expenses, income and trackers to Firebase now"
        }
        return "Last synced: \(formattedDate(from: firebaseLastSyncDate))"
    }

    private var syncSectionBusy: Bool {
        syncInProgress || cloudSync.isRestoringFromCloud
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    topSettingsCard

                    Text("Account")
                        .font(.system(size: 24, weight: .semibold))

                    NavigationLink(destination: ProfileView()) {
                        settingsRow(
                            icon: "person.fill",
                            title: "Open Profile",
                            subtitle: "Manage your display name and account details",
                            titleColor: .black.opacity(0.86)
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        showComingSoon()
                    } label: {
                        settingsRow(
                            icon: "arrow.left.arrow.right",
                            title: "Switch to Business",
                            subtitle: "Change app flow and bottom navigation to business mode",
                            titleColor: .black.opacity(0.86)
                        )
                    }
                    .buttonStyle(.plain)

                    if let connectedProvider {
                        settingsRow(
                            icon: connectedProvider == .apple ? "applelogo" : nil,
                            customIconText: connectedProvider == .google ? "G" : nil,
                            title: connectedProvider == .google ? "Google Connected" : "Apple Connected",
                            subtitle: connectedEmailText,
                            titleColor: .black.opacity(0.86)
                        )

                        Button {
                            triggerSyncNow()
                        } label: {
                            settingsRow(
                                icon: "arrow.triangle.2.circlepath",
                                title: cloudSync.isRestoringFromCloud ? "Restoring..." : (syncInProgress ? "Syncing..." : "Sync Now"),
                                subtitle: syncSubtitle,
                                titleColor: .black.opacity(0.86),
                                isLoading: syncSectionBusy
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(syncSectionBusy)
                    } else {
                        Button {
                            connectGoogleFromSettings()
                        } label: {
                            settingsRow(
                                customIconText: "G",
                                title: "Connect Google Account",
                                subtitle: settingsAuth.isAuthInProgress ? "Signing in..." : "Enable backup and restore for your local data",
                                titleColor: .black.opacity(0.86)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(settingsAuth.isAuthInProgress)

                        Button {
                            connectAppleFromSettings()
                        } label: {
                            settingsRow(
                                icon: "applelogo",
                                title: "Connect Apple Account",
                                subtitle: settingsAuth.isAuthInProgress ? "Signing in..." : "Sign in with Apple to sync your app data",
                                titleColor: .black.opacity(0.86)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(settingsAuth.isAuthInProgress)
                    }

                    Text("Data")
                        .font(.system(size: 24, weight: .semibold))

                    Button {
                        clearNotificationHistory()
                    } label: {
                        settingsRow(
                            icon: "bell",
                            title: "Clear Notification History",
                            subtitle: "Reset cleared reminders so hidden tracker alerts appear again",
                            titleColor: .black.opacity(0.86)
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        showClearLocalDataAlert = true
                    } label: {
                        settingsRow(
                            icon: "trash.fill",
                            title: "Clear Local Data",
                            subtitle: "Remove all on-device categories, transactions, tracker and business records",
                            titleColor: .red
                        )
                    }
                    .buttonStyle(.plain)

                    Text("App")
                        .font(.system(size: 24, weight: .semibold))

                    Button {
                    } label: {
                        settingsRow(
                            icon: "shield.fill",
                            title: "Privacy & Security",
                            subtitle: "Your data stays local unless you explicitly sync with Google",
                            titleColor: .black.opacity(0.86)
                        )
                    }
                    .buttonStyle(.plain)

                    Text("Support")
                        .font(.system(size: 24, weight: .semibold))

                    NavigationLink(destination: AboutView()) {
                        settingsRow(
                            icon: "info.circle.fill",
                            title: "About PiggyFlow",
                            subtitle: "Version info and app overview",
                            titleColor: .black.opacity(0.86)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .navigationBarHidden(true)
            .overlay(alignment: .bottom) {
                if showComingSoonToast {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.badge.exclamationmark")
                            .font(.system(size: 14, weight: .bold))
                        Text("Coming soon")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.black.opacity(0.86))
                    )
                    .foregroundColor(.white)
                    .padding(.bottom, 18)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: showComingSoonToast)
            .alert("Clear Local Data?", isPresented: $showClearLocalDataAlert) {
                Button("Clear", role: .destructive) {
                    clearLocalData()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will remove all local transactions and categories from this device.")
            }
            .alert("Authentication Error", isPresented: Binding(
                get: { settingsAuth.authErrorMessage != nil },
                set: { if !$0 { settingsAuth.authErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {
                    settingsAuth.authErrorMessage = nil
                }
            } message: {
                Text(settingsAuth.authErrorMessage ?? "Unknown error")
            }
        }
    }

    private var topSettingsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(initials)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(width: 64, height: 64)
                    .background(Circle().fill(Color.white.opacity(0.13)))

                Spacer()

                Text(accountTypeTitle)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.92))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.white.opacity(0.16)))
            }

            Text("Settings")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)

            Text("\(displayName) · \(connectionStatusText)")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))

            Text("Last synced: Not synced yet")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: colorScheme == .dark
                            ? [Color.gray.opacity(0.15), Color.gray.opacity(0.1)]
                            : [Color.black, Color.black.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    @ViewBuilder
    private func settingsRow(
        icon: String? = nil,
        customIconText: String? = nil,
        title: String,
        subtitle: String,
        titleColor: Color,
        isLoading: Bool = false
    ) -> some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color.green.opacity(0.14))
                .frame(width: 40, height: 40)
                .overlay {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.green)
                    } else if let customIconText {
                        Text(customIconText)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.green)
                    }
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }

            Spacer()

            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .tint(.gray)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.gray)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.gray.opacity(0.1))
        )
    }

    private func clearNotificationHistory() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    private func showComingSoon() {
        withAnimation {
            showComingSoonToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation {
                showComingSoonToast = false
            }
        }
    }

    private func triggerSyncNow() {
        guard !syncSectionBusy else { return }
        syncInProgress = true

        Task {
            let success = await CloudSyncManager.shared.syncNow(context: context)
            await MainActor.run {
                syncInProgress = false
                if success {
                    firebaseLastSyncDate = Date().timeIntervalSince1970
                }
            }
        }
    }

    private func formattedDate(from timestamp: Double) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private func connectGoogleFromSettings() {
        guard let rootController = UIApplication.settingsTopViewController() else {
            settingsAuth.authErrorMessage = "Unable to open Google sign in screen."
            return
        }
        settingsAuth.signInWithGoogle(presentingViewController: rootController)
    }

    private func connectAppleFromSettings() {
        settingsAuth.signInWithApple()
    }

    private func clearLocalData() {
        do {
            let expenses = try context.fetch(FetchDescriptor<Expense>())
            for item in expenses {
                context.delete(item)
            }

            let incomes = try context.fetch(FetchDescriptor<Income>())
            for item in incomes {
                context.delete(item)
            }
            
            let trackers = try context.fetch(FetchDescriptor<TrackerRecord>())
            for item in trackers {
                context.delete(item)
            }

            let categoryContext = UserCategoryManager.shared.container.mainContext
            let categories = try categoryContext.fetch(FetchDescriptor<UserCategory>())
            for item in categories {
                categoryContext.delete(item)
            }

            try context.save()
            try categoryContext.save()
        } catch {
            print("Failed to clear local data: \(error.localizedDescription)")
        }
    }
}

final class SettingsAuthService: NSObject, ObservableObject, ASAuthorizationControllerDelegate {
    @Published var isAuthInProgress = false
    @Published var authErrorMessage: String?

    private var currentNonce: String?

    func signInWithGoogle(presentingViewController: UIViewController) {
        guard !isAuthInProgress else { return }
        authErrorMessage = nil
        isAuthInProgress = true

#if canImport(FirebaseAuth) && canImport(FirebaseCore) && canImport(GoogleSignIn)
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            fail("Firebase is not configured. Add GoogleService-Info.plist and call FirebaseApp.configure().")
            return
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { [weak self] result, error in
            guard let self else { return }

            if let error {
                self.fail(error.localizedDescription)
                return
            }

            guard
                let user = result?.user,
                let idToken = user.idToken?.tokenString
            else {
                self.fail("Unable to fetch Google auth token.")
                return
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: user.accessToken.tokenString
            )

            Auth.auth().signIn(with: credential) { [weak self] authResult, error in
                guard let self else { return }
                if let error {
                    self.fail(error.localizedDescription)
                    return
                }
                self.completeSuccess(displayName: authResult?.user.displayName, email: authResult?.user.email)
            }
        }
#else
        fail("Google/Firebase SDKs are not installed in iOS target yet.")
#endif
    }

    func signInWithApple() {
        guard !isAuthInProgress else { return }
        authErrorMessage = nil
        isAuthInProgress = true

        let nonce = randomNonceString()
        currentNonce = nonce

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.performRequests()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            fail("Unable to read Apple account credentials.")
            return
        }

#if canImport(FirebaseAuth)
        guard
            let nonce = currentNonce,
            let tokenData = credential.identityToken,
            let idTokenString = String(data: tokenData, encoding: .utf8)
        else {
            fail("Unable to read Apple credential token.")
            return
        }

        let firebaseCredential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: credential.fullName
        )

        Auth.auth().signIn(with: firebaseCredential) { [weak self] authResult, error in
            guard let self else { return }
            if let error {
                self.fail(error.localizedDescription)
                return
            }
            let givenName = credential.fullName?.givenName
            self.completeSuccess(
                displayName: givenName?.isEmpty == false ? givenName : authResult?.user.displayName,
                email: credential.email ?? authResult?.user.email
            )
        }
#else
        completeSuccess(displayName: credential.fullName?.givenName, email: credential.email)
#endif
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        fail(error.localizedDescription)
    }

    private func completeSuccess(displayName: String?, email: String?) {
        DispatchQueue.main.async {
            if let displayName, !displayName.isEmpty {
                UserDefaults.standard.set(displayName, forKey: "username")
            }
            if let email, !email.isEmpty {
                UserDefaults.standard.set(email, forKey: "userEmail")
            }
            UserDefaults.standard.set(true, forKey: AppleSignInManager.loginStatusKey)
            CloudSyncManager.shared.handleLoginIfNeeded(context: DataManager.shared.localContainer.mainContext)
            self.authErrorMessage = nil
            self.isAuthInProgress = false
        }
    }

    private func fail(_ message: String) {
        DispatchQueue.main.async {
            self.authErrorMessage = message
            self.isAuthInProgress = false
        }
    }

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if status != errSecSuccess {
                    fatalError("Unable to generate nonce.")
                }
                return random
            }

            randoms.forEach { random in
                if remainingLength == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        return SHA256.hash(data: inputData).map { String(format: "%02x", $0) }.joined()
    }
}

private extension UIApplication {
    static func settingsTopViewController(
        base: UIViewController? = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?
            .rootViewController
    ) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return settingsTopViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController {
            return settingsTopViewController(base: tab.selectedViewController)
        }
        if let presented = base?.presentedViewController {
            return settingsTopViewController(base: presented)
        }
        return base
    }
}

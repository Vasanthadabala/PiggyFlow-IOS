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
    @EnvironmentObject private var appleSignInManager: AppleSignInManager

    @AppStorage("username") private var userName: String = ""
    @AppStorage("userEmail") private var userEmail: String = ""
    @AppStorage("firebaseLastSyncDate") private var firebaseLastSyncDate: Double = 0
    @AppStorage("autoSyncEnabled") private var autoSyncEnabled: Bool = false

    @StateObject private var settingsAuth = SettingsAuthService()
    @ObservedObject private var cloudSync = CloudSyncManager.shared
    @State private var showClearLocalDataAlert = false
    @State private var syncInProgress = false

    @State private var showEditNameSheet = false
    @State private var editedName = ""
    @State private var showLogoutAlert = false
    @State private var showDeleteAccountAlert = false
    @State private var accountActionMessage: String?
    @State private var isDeletingAccount = false

    private enum ConnectedProvider {
        case google
        case apple
    }

    private var displayName: String {
        let trimmed = userName.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Guest" : trimmed
    }

    private var initials: String {
        let clean = displayName.replacingOccurrences(of: "[^A-Za-z0-9]", with: "", options: .regularExpression)
        return String(clean.prefix(1)).uppercased().isEmpty ? "G" : String(clean.prefix(1)).uppercased()
    }

    private var emailText: String {
        let trimmed = userEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Not linked" : trimmed
    }

    private var connectionStatusText: String {
        userEmail.isEmpty ? "Local Account" : "Cloud Connected"
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
            return "Restoring backup data from cloud..."
        }
        if syncInProgress {
            return "Syncing latest changes..."
        }
        guard firebaseLastSyncDate > 0 else {
            return autoSyncEnabled ? "Syncs automatically every 12 hours" : "Turn on to sync automatically"
        }
        return "Last synced: \(formattedDate(from: firebaseLastSyncDate))"
    }

    private var syncSectionBusy: Bool {
        syncInProgress || cloudSync.isRestoringFromCloud
    }

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    topSettingsCard

                    // Account Section Card
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ACCOUNT")
                            .sectionEyebrow()
                            .padding(.leading, 4)

                        VStack(spacing: 0) {
                            // Email Address (inline)
                            HStack(spacing: 14) {
                                TintedIconCircle(color: .appGreen, size: 38, cornerRadius: 12) {
                                    Image(systemName: "envelope.fill")
                                        .font(.system(size: 13, weight: .bold))
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Email Address")
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundColor(.secondary)
                                    Text(emailText)
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)

                            Divider().padding(.leading, 54)

                            if let connectedProvider {
                                settingsRowItem(
                                    icon: connectedProvider == .apple ? "applelogo" : nil,
                                    customIconText: connectedProvider == .google ? "G" : nil,
                                    title: connectedProvider == .google ? "Google Connected" : "Apple Connected",
                                    subtitle: connectedEmailText,
                                    titleColor: .primary
                                )

                                Divider().padding(.leading, 54)

                                // Auto Sync toggle — replaces the manual Sync Now button
                                HStack(spacing: 14) {
                                    TintedIconCircle(color: .appGreen, size: 38, cornerRadius: 12) {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                            .font(.system(size: 14, weight: .bold))
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(cloudSync.isRestoringFromCloud ? "Restoring..." : (syncInProgress ? "Syncing..." : "Auto Sync"))
                                            .font(.system(size: 15, weight: .bold, design: .rounded))
                                            .foregroundColor(.primary)
                                        Text(syncSubtitle)
                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    if syncSectionBusy {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else {
                                        Toggle("", isOn: $autoSyncEnabled)
                                            .labelsHidden()
                                            .tint(.appGreen)
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 14)
                                .onChange(of: autoSyncEnabled) { _, isOn in
                                    if isOn { triggerSyncNow() }
                                }

                                if appleSignInManager.isAuthenticated {
                                    Divider().padding(.leading, 54)

                                    Button {
                                        showDeleteAccountAlert = true
                                    } label: {
                                        settingsRowItem(
                                            icon: "trash.fill",
                                            title: isDeletingAccount ? "Deleting..." : "Delete Account",
                                            subtitle: "Remove local data & cloud account",
                                            titleColor: .appExpenseRed
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(isDeletingAccount)
                                }
                            } else {
                                Button {
                                    connectGoogleFromSettings()
                                } label: {
                                    settingsRowItem(
                                        customIconText: "G",
                                        title: "Connect Google Account",
                                        subtitle: settingsAuth.isAuthInProgress ? "Signing in..." : "Enable backup & cloud restore",
                                        titleColor: .primary
                                    )
                                }
                                .buttonStyle(.plain)
                                .disabled(settingsAuth.isAuthInProgress)

                                Divider().padding(.leading, 54)

                                Button {
                                    connectAppleFromSettings()
                                } label: {
                                    settingsRowItem(
                                        icon: "applelogo",
                                        title: "Connect Apple Account",
                                        subtitle: settingsAuth.isAuthInProgress ? "Signing in..." : "Sign in with Apple to sync data",
                                        titleColor: .primary
                                    )
                                }
                                .buttonStyle(.plain)
                                .disabled(settingsAuth.isAuthInProgress)
                            }
                        }
                        .groupedCard()
                    }

                    // Data Management Section Card
                    VStack(alignment: .leading, spacing: 6) {
                        Text("DATA & PRIVACY")
                            .sectionEyebrow()
                            .padding(.leading, 4)

                        VStack(spacing: 0) {
                            Button {
                                showClearLocalDataAlert = true
                            } label: {
                                settingsRowItem(
                                    icon: "trash.fill",
                                    title: "Clear Local Data",
                                    subtitle: "Remove on-device transactions & category records",
                                    titleColor: .appExpenseRed
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .groupedCard()
                    }

                    // App & Support Section Card
                    VStack(alignment: .leading, spacing: 6) {
                        Text("APP & SUPPORT")
                            .sectionEyebrow()
                            .padding(.leading, 4)

                        VStack(spacing: 0) {
                            // Informational only — no destination, so no chevron and no Button.
                            settingsRowItem(
                                icon: "shield.fill",
                                title: "Privacy & Security",
                                subtitle: "Local data is encrypted and synced only on request",
                                titleColor: .primary,
                                showsChevron: false
                            )

                            Divider().padding(.leading, 54)

                            NavigationLink(destination: AboutView().hidesTabBarOnPush()) {
                                settingsRowItem(
                                    icon: "info.circle.fill",
                                    title: "About PiggyFlow",
                                    subtitle: "Version details & overview",
                                    titleColor: .primary
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .groupedCard()
                    }

                    // Logout — its own section at the bottom of the screen
                    if appleSignInManager.isAuthenticated {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("SESSION")
                                .sectionEyebrow()
                                .padding(.leading, 4)

                            Button {
                                showLogoutAlert = true
                            } label: {
                                settingsRowItem(
                                    icon: "rectangle.portrait.and.arrow.right",
                                    title: "Logout",
                                    subtitle: "Sign out from this device",
                                    titleColor: .appExpenseRed
                                )
                            }
                            .buttonStyle(.plain)
                            .groupedCard()
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 90) }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEditNameSheet) {
            editNameSheet
        }
        .alert("Logout", isPresented: $showLogoutAlert) {
            Button("Logout", role: .destructive) {
                appleSignInManager.signOut()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears all PiggyFlow data on this device — transactions, accounts, budgets and goals. Your cloud backup is kept, so signing back in restores it.")
        }
        .alert("Delete Account", isPresented: $showDeleteAccountAlert) {
            Button("Delete", role: .destructive) {
                isDeletingAccount = true
                clearLocalData()
                appleSignInManager.deleteAccount { success in
                    DispatchQueue.main.async {
                        isDeletingAccount = false
                        accountActionMessage = success
                            ? "Account deleted successfully."
                            : "Account removed locally. Re-login may be required to delete cloud identity fully."
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action will remove your local app data and delete your account.")
        }
        .alert("Account", isPresented: Binding(
            get: { accountActionMessage != nil },
            set: { if !$0 { accountActionMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                accountActionMessage = nil
            }
        } message: {
            Text(accountActionMessage ?? "")
        }
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

    private var topSettingsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                TintedIconCircle(color: .white, size: 54) {
                    Text(initials)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(displayName)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text(connectionStatusText)
                        .tintedPillOnHero()
                }
                Spacer()

                Button {
                    editedName = displayName == "Guest" ? "" : displayName
                    showEditNameSheet = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .padding(9)
                        .background(Color.white.opacity(0.18))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            Divider().overlay(Color.white.opacity(0.25))

            Text(firebaseLastSyncDate > 0 ? "Last synced: \(formattedDate(from: firebaseLastSyncDate))" : "Last synced: Not synced yet")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .gradientHero([.appGreen, .appGreenDeep])
    }

    private var editNameSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextField("Enter display name", text: $editedName)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 16)

                Button {
                    let trimmed = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        userName = trimmed
                    }
                    showEditNameSheet = false
                } label: {
                    Text("Save")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.appGreen)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(.horizontal, 16)

                Spacer()
            }
            .padding(.top, 20)
            .navigationTitle("Edit Name")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.height(220)])
    }

    @ViewBuilder
    /// - Parameter showsChevron: pass `false` for informational rows that don't navigate —
    ///   a chevron on a row that does nothing reads as a broken control.
    private func settingsRowItem(
        icon: String? = nil,
        customIconText: String? = nil,
        title: String,
        subtitle: String,
        titleColor: Color,
        isLoading: Bool = false,
        showsChevron: Bool = true
    ) -> some View {
        HStack(spacing: 14) {
            TintedIconCircle(color: .appGreen, size: 38, cornerRadius: 12) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                } else if let customIconText {
                    Text(customIconText)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(titleColor)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .tint(.gray)
            } else if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.5))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
    }

    private func triggerSyncNow() {
        guard !syncInProgress else { return }
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
        guard let rootController = UIApplication.topViewController() else {
            settingsAuth.authErrorMessage = "Unable to open Google sign in screen."
            return
        }
        settingsAuth.signInWithGoogle(presentingViewController: rootController)
    }

    private func connectAppleFromSettings() {
        settingsAuth.signInWithApple()
    }

    /// Empties the stored records without signing the user out — the shared wipe owns the
    /// details (accounts and receipt files included, which this used to miss).
    private func clearLocalData() {
        DataManager.shared.wipeAllLocalData(includingPreferences: false)
    }
}

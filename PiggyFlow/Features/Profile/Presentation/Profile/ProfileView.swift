import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject var appleSignInManager: AppleSignInManager

    @Query private var expenses: [Expense]
    @Query private var incomes: [Income]

    @AppStorage("username") private var userName: String = "Vasanth Adabala"
    @AppStorage("userEmail") private var userEmail: String = "vasanth.adabala@gmail.com"

    @State private var showEditSheet: Bool = false
    @State private var editedName: String = ""
    @State private var showLogoutAlert: Bool = false
    @State private var showDeleteAlert: Bool = false
    @State private var accountActionMessage: String? = nil
    @State private var isDeletingAccount: Bool = false

    private var displayName: String {
        let trimmed = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Vasanth Adabala" : trimmed
    }

    private var displayEmail: String {
        let trimmed = userEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "vasanth.adabala@gmail.com" : trimmed
    }

    private var totalIncome: Double {
        incomes.reduce(0) { $0 + $1.income }
    }

    private var totalExpenses: Double {
        expenses.reduce(0) { $0 + $1.price }
    }

    private var netBalance: Double {
        totalIncome - totalExpenses
    }

    private var savingsRatePercentage: Double {
        totalIncome > 0 ? max(0, ((totalIncome - totalExpenses) / totalIncome) * 100) : 32.0
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.appBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // 1. Header Bar
                    headerBar

                    // 2. User Profile Banner Card
                    profileBannerCard

                    // 3. Account Overview Card (4 Columns)
                    accountOverviewCard

                    // 4. Section 1: Account
                    accountSectionGroup

                    // 5. Section 2: Preferences
                    preferencesSectionGroup

                    // 6. Section 3: Support
                    supportSectionGroup

                    // 7. Logout Button Card
                    logoutButtonCard

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showEditSheet) {
            editNameSheet
        }
        .alert("Logout", isPresented: $showLogoutAlert) {
            Button("Logout", role: .destructive) {
                appleSignInManager.signOut()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to logout from PiggyFlow?")
        }
        .alert("Delete Account", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                isDeletingAccount = true
                clearLocalData()
                appleSignInManager.deleteAccount { success in
                    DispatchQueue.main.async {
                        isDeletingAccount = false
                        accountActionMessage = success
                            ? "Account deleted successfully."
                            : "Account removed locally."
                        dismiss()
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action will remove your local app data and delete your account.")
        }
    }

    // MARK: - 1. Navigation Header Bar
    private var headerBar: some View {
        HStack(spacing: 12) {
            // Profile is always reached by push (from Home's avatar), never a tab root, but
            // its header had no way back — `.navigationBarHidden(true)` below hides the
            // system chrome, and edge-swipe alone isn't a discoverable substitute.
            Button {
                Haptics.light()
                dismiss()
            } label: {
                Image(systemName: AppIcon.Nav.back)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.appGreenDeep)
                    .frame(width: 40, height: 40)
                    .background(Color.appSurface)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text("Profile")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text("Manage your account and preferences")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            Spacer()

            NavigationLink(destination: SettingsView().hidesTabBarOnPush()) {
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 38, height: 38)
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 2. User Profile Banner Card
    private var profileBannerCard: some View {
        Button {
            editedName = displayName
            showEditSheet = true
        } label: {
            HStack(spacing: 14) {
                // Avatar with Camera Edit Badge
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.appGreen, Color.appGreenDeep],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 72, height: 72)
                        .overlay(
                            Text(String(displayName.prefix(1)).uppercased())
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        )
                        .overlay(Circle().stroke(Color.appGreen, lineWidth: 2))

                    Circle()
                        .fill(Color.appGreenDeep)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Image(systemName: "camera.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .offset(x: 2, y: 2)
                }

                // Name & Email Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Text(displayEmail)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("Premium Member")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(Color.appGreenDeep)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.appGreen.opacity(0.12))
                    .clipShape(Capsule())
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .padding(14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 3. Account Overview Card (4 Columns)
    private var accountOverviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Account Overview")
                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
                NavigationLink(destination: ReportsView().hidesTabBarOnPush()) {
                    HStack(spacing: 2) {
                        Text("View All")
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9.5, weight: .bold))
                    }
                    .foregroundColor(.appGreen)
                }
            }

            HStack(spacing: 0) {
                // Column 1: Net Balance
                overviewMetricColumn(
                    icon: "wallet.pass.fill",
                    iconColor: Color.appGreen,
                    bgColor: Color.appGreen.opacity(0.12),
                    title: "Net Balance",
                    value: "₹\(Int(netBalance > 0 ? netBalance : 120500).formatted())",
                    valueColor: Color.appGreenDeep
                )

                metricDivider

                // Column 2: Total Income
                overviewMetricColumn(
                    icon: "arrow.up",
                    iconColor: .blue,
                    bgColor: Color.blue.opacity(0.12),
                    title: "Total Income",
                    value: "₹\(Int(totalIncome > 0 ? totalIncome : 240000).formatted())",
                    valueColor: .blue
                )

                metricDivider

                // Column 3: Total Expenses
                overviewMetricColumn(
                    icon: "arrow.down",
                    iconColor: Color.appExpenseRed,
                    bgColor: Color.appExpenseRed.opacity(0.12),
                    title: "Total Expenses",
                    value: "₹\(Int(totalExpenses > 0 ? totalExpenses : 119500).formatted())",
                    valueColor: Color.appExpenseRed
                )

                metricDivider

                // Column 4: Savings Rate
                overviewMetricColumn(
                    icon: "target",
                    iconColor: Color.appWarningAmber,
                    bgColor: Color.appWarningAmber.opacity(0.15),
                    title: "Savings Rate",
                    value: "\(Int(savingsRatePercentage))%",
                    valueColor: Color.appWarningAmber
                )
            }
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    @ViewBuilder
    private func overviewMetricColumn(icon: String, iconColor: Color, bgColor: Color, title: String, value: String, valueColor: Color) -> some View {
        NavigationLink(destination: ReportDetailView().hidesTabBarOnPush()) {
            VStack(spacing: 6) {
                Circle()
                    .fill(bgColor)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(iconColor)
                    )

                VStack(spacing: 2) {
                    Text(title)
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    HStack(spacing: 1) {
                        Text(value)
                            .font(.system(size: 12.5, weight: .bold, design: .rounded))
                            .foregroundColor(valueColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(valueColor.opacity(0.8))
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.18))
            .frame(width: 1, height: 38)
    }

    // MARK: - 4. Section 1: Account Group
    private var accountSectionGroup: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Account")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                NavigationLink(destination: EditProfileView().hidesTabBarOnPush()) {
                    profileRow(icon: "person.fill", title: "Personal Information", subtitle: "View and update your personal details")
                }
                .buttonStyle(.plain)

                Divider().padding(.leading, 50)

                NavigationLink(destination: SecurityView().hidesTabBarOnPush()) {
                    profileRow(icon: "shield.checkmark.fill", title: "Security", subtitle: "Password, biometric and security settings")
                }
                .buttonStyle(.plain)

                Divider().padding(.leading, 50)

                NavigationLink(destination: CloudSyncView().hidesTabBarOnPush()) {
                    profileRow(icon: "cloud.fill", title: "Cloud Sync", subtitle: "Backup and sync your data", rightBadge: "Active")
                }
                .buttonStyle(.plain)

                Divider().padding(.leading, 50)

                NavigationLink(destination: AccountsView().hidesTabBarOnPush()) {
                    profileRow(icon: "creditcard.fill", title: "Payment Methods", subtitle: "Manage your cards and accounts")
                }
                .buttonStyle(.plain)

                Divider().padding(.leading, 50)

                NavigationLink(destination: PremiumView().hidesTabBarOnPush()) {
                    profileRow(icon: "crown.fill", title: "Premium Membership", subtitle: "Manage your subscription")
                }
                .buttonStyle(.plain)
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
    }

    // MARK: - 5. Section 2: Preferences Group
    private var preferencesSectionGroup: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Preferences")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                NavigationLink(destination: NotificationSettingsView().hidesTabBarOnPush()) {
                    profileRow(icon: "bell.fill", title: "Notifications", subtitle: "Manage your notification preferences")
                }
                .buttonStyle(.plain)

                Divider().padding(.leading, 50)

                NavigationLink(destination: AppearanceView().hidesTabBarOnPush()) {
                    profileRow(icon: "paintpalette.fill", title: "Appearance", subtitle: "Choose theme and app appearance")
                }
                .buttonStyle(.plain)

                Divider().padding(.leading, 50)

                NavigationLink(destination: CurrencyView().hidesTabBarOnPush()) {
                    profileRow(icon: "indianrupeesign.circle.fill", title: "Currency", subtitle: "Select your preferred currency", rightBadge: "INR (₹)")
                }
                .buttonStyle(.plain)

                Divider().padding(.leading, 50)

                NavigationLink(destination: LanguageView().hidesTabBarOnPush()) {
                    profileRow(icon: "globe", title: "Language", subtitle: "Choose your preferred language", rightBadge: "English")
                }
                .buttonStyle(.plain)
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
    }

    // MARK: - 6. Section 3: Support Group
    private var supportSectionGroup: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Support")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                NavigationLink(destination: HelpCenterView().hidesTabBarOnPush()) {
                    profileRow(icon: "questionmark.circle.fill", title: "Help Center", subtitle: "FAQs and support articles")
                }
                .buttonStyle(.plain)

                Divider().padding(.leading, 50)

                NavigationLink(destination: ContactSupportView().hidesTabBarOnPush()) {
                    profileRow(icon: "envelope.fill", title: "Contact Support", subtitle: "Get in touch with our support team")
                }
                .buttonStyle(.plain)

                Divider().padding(.leading, 50)

                NavigationLink(destination: AboutView().hidesTabBarOnPush()) {
                    profileRow(icon: "info.circle.fill", title: "About PiggyFlow", subtitle: "Version 2.0.0")
                }
                .buttonStyle(.plain)
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
    }

    // MARK: - 7. Logout Button Card
    private var logoutButtonCard: some View {
        Button {
            showLogoutAlert = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color.appExpenseRed)

                Text("Logout")
                    .font(.system(size: 14.5, weight: .bold, design: .rounded))
                    .foregroundColor(Color.appExpenseRed)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helper Profile Row Component
    @ViewBuilder
    private func profileRow(icon: String, title: String, subtitle: String, rightBadge: String? = nil) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.appGreen.opacity(0.12))
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.appGreenDeep)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 4)

            if let badge = rightBadge {
                Text(badge)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(Color.appGreenDeep)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary.opacity(0.5))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
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
                    showEditSheet = false
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

    private func clearLocalData() {
        do {
            let expenses = try context.fetch(FetchDescriptor<Expense>())
            for item in expenses { context.delete(item) }

            let incomes = try context.fetch(FetchDescriptor<Income>())
            for item in incomes { context.delete(item) }

            let trackers = try context.fetch(FetchDescriptor<TrackerRecord>())
            for item in trackers { context.delete(item) }

            try context.save()
        } catch {
            print("❌ Failed to clear local data: \(error.localizedDescription)")
        }
    }
}

// MARK: - Dummy Destination Views for Navigation Links
struct EditProfileView: View {
    var body: some View {
        Text("Personal Information")
            .navigationTitle("Personal Info")
    }
}

struct SecurityView: View {
    var body: some View {
        Text("Security Settings")
            .navigationTitle("Security")
    }
}

struct CloudSyncView: View {
    var body: some View {
        Text("Cloud Sync Settings")
            .navigationTitle("Cloud Sync")
    }
}

struct PremiumView: View {
    var body: some View {
        Text("Premium Membership")
            .navigationTitle("Premium")
    }
}

struct NotificationSettingsView: View {
    var body: some View {
        Text("Notification Preferences")
            .navigationTitle("Notifications")
    }
}

struct AppearanceView: View {
    var body: some View {
        Text("Appearance Options")
            .navigationTitle("Appearance")
    }
}

struct CurrencyView: View {
    var body: some View {
        Text("Currency Options")
            .navigationTitle("Currency")
    }
}

struct LanguageView: View {
    var body: some View {
        Text("Language Options")
            .navigationTitle("Language")
    }
}

struct HelpCenterView: View {
    var body: some View {
        Text("Help Center & FAQs")
            .navigationTitle("Help Center")
    }
}

struct ContactSupportView: View {
    var body: some View {
        Text("Contact Support")
            .navigationTitle("Contact Support")
    }
}

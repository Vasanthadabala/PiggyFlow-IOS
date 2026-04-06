import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var context
    @EnvironmentObject var appleSignInManager: AppleSignInManager

    @AppStorage("username") private var userName: String = ""
    @AppStorage("userEmail") private var userEmail: String = ""
    @AppStorage(AccountType.storageKey) private var selectedAccountType: String = AccountType.personal.rawValue

    @State private var showEditSheet: Bool = false
    @State private var editedName: String = ""
    @State private var showLogoutAlert = false
    @State private var showDeleteAlert = false
    @State private var accountActionMessage: String?
    @State private var isDeletingAccount = false

    private var displayName: String {
        let trimmed = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Guest" : trimmed
    }

    private var firstLetter: String {
        String(displayName.prefix(1)).uppercased()
    }

    private var emailText: String {
        let trimmed = userEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Not linked" : trimmed
    }

    private var accountTypeTitle: String {
        (AccountType(rawValue: selectedAccountType) ?? .personal).shortTitle
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        Text(firstLetter)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                            .frame(width: 64, height: 64)
                            .background(Circle().fill(Color.white.opacity(0.15)))

                        Spacer()

                        Text(accountTypeTitle)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.white.opacity(0.16)))
                    }

                    Text(displayName)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)

                    Text(userEmail.isEmpty ? "Not linked" : "Linked")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))

                    Text(userEmail.isEmpty ? "Local account" : "Cloud account")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal,16)
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

                HStack(spacing: 12) {
                    statCard(title: "Account", value: accountTypeTitle)
                    statCard(title: "Status", value: appleSignInManager.isAuthenticated ? "Online" : "Offline")
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Account Details")
                        .font(.system(size: 18, weight: .semibold))

                    HStack(spacing: 14) {
                        Circle()
                            .fill(Color.green.opacity(0.14))
                            .frame(width: 34, height: 34)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.green)
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Display Name")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                            Text(displayName)
                                .font(.system(size: 18, weight: .semibold))
                        }

                        Spacer()

                        Button {
                            editedName = displayName == "Guest" ? "" : displayName
                            showEditSheet = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.green)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.gray.opacity(0.12))
                    )

                    HStack(spacing: 14) {
                        Circle()
                            .fill(Color.green.opacity(0.14))
                            .frame(width: 34, height: 34)
                            .overlay(
                                Image(systemName: "briefcase.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.green)
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Email")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                            Text(emailText)
                                .font(.system(size: 18, weight: .bold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.65)
                        }

                        Spacer()
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.gray.opacity(0.1))
                    )
                }

                if appleSignInManager.isAuthenticated {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Account Actions")
                            .font(.system(size: 18, weight: .semibold))

                        Button {
                            showLogoutAlert = true
                        } label: {
                            actionRow(
                                icon: "rectangle.portrait.and.arrow.right",
                                title: "Logout",
                                subtitle: "Sign out from this device",
                                titleColor: .orange
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            showDeleteAlert = true
                        } label: {
                            actionRow(
                                icon: "trash.fill",
                                title: isDeletingAccount ? "Deleting..." : "Delete Account",
                                subtitle: "Remove local data and delete your cloud account",
                                titleColor: .red
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isDeletingAccount)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .navigationTitle("Profile")
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
            Text("Are you sure you want to logout?")
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
                            : "Account removed locally. Re-login may be required to delete cloud identity fully."
                        dismiss()
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
    }

    @ViewBuilder
    private func statCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.gray.opacity(0.1))
        )
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
                        .font(.system(size: 18, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.green)
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
    private func actionRow(icon: String, title: String, subtitle: String, titleColor: Color) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(titleColor.opacity(0.12))
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(titleColor)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(titleColor)
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.gray)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.gray.opacity(0.1))
        )
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
            print("❌ Failed to clear local data during account deletion: \(error.localizedDescription)")
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AppleSignInManager())
}

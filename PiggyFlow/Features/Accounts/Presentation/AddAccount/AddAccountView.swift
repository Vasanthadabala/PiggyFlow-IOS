import SwiftUI
import SwiftData

struct AddAccountView: View {
    @Environment(\.dismiss) private var dismiss

    var onSave: ((Account) -> Void)? = nil

    /// Overrides the back button's dismissal. Callers that present this screen as a real
    /// `.fullScreenCover`/push don't need it — `dismiss()` already closes that correctly.
    /// Callers that instead show it as a transitioning overlay (no real presentation of its
    /// own) must supply this, or `dismiss()` would fall through to whatever real presentation
    /// sits further up the hierarchy and close more than just this screen.
    var onBackOverride: (() -> Void)? = nil

    @State private var selectedCategory: AccountCategory = .bank
    @State private var accountName: String = ""
    @State private var accountNumber: String = ""
    @State private var initialBalance: String = ""
    @State private var selectedSubType: String = "Savings Account"
    @State private var includeInNetBalance: Bool = true
    @State private var isSavePressed: Bool = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header Bar
                headerBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Select Account Type Section
                        selectAccountTypeSection

                        // Account Details Form
                        accountDetailsSection

                        Spacer().frame(height: 100)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
            }

            // Bottom Save CTA Button
            bottomSaveCTA
        }
        .navigationBarHidden(true)
    }

    // MARK: - Header Bar
    private var headerBar: some View {
        VStack(spacing: 4) {
            HStack {
                BackButton { onBackOverride?() ?? dismiss() }

                Spacer()

                Text("Add Account")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(Color.appGreen)

                Spacer()

                Button {
                    Haptics.light()
                } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color.appGreen)
                        .frame(width: 40, height: 40)
                        .background(Color.appGreen.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)

            Text("Choose the type of account you want to add")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(Color.appBackground)
    }

    // MARK: - Select Account Type Section
    private var selectAccountTypeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Select Account Type")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            VStack(spacing: 0) {
                ForEach(Array(AccountCategory.allCases.enumerated()), id: \.element.id) { idx, cat in
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            selectedCategory = cat
                        }
                        Haptics.light()
                    } label: {
                        HStack(spacing: 14) {
                            // Icon
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(cat.iconBgColor)
                                    .frame(width: 42, height: 42)
                                Image(systemName: cat.iconName)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                            }

                            // Title & Subtitle
                            VStack(alignment: .leading, spacing: 2) {
                                Text(cat.rawValue)
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundColor(.primary)
                                Text(cat.caption)
                                    .font(.system(size: 12, weight: .regular, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }

                            Spacer()

                            Image(systemName: selectedCategory == cat ? "checkmark.circle.fill" : "chevron.right")
                                .font(.system(size: selectedCategory == cat ? 20 : 14, weight: .semibold))
                                .foregroundColor(selectedCategory == cat ? Color.appGreen : Color.secondary.opacity(0.5))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color(.secondarySystemGroupedBackground))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if idx < AccountCategory.allCases.count - 1 {
                        Divider()
                            .padding(.leading, 72)
                            .background(Color(.secondarySystemGroupedBackground))
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
        }
    }

    // MARK: - Account Details Section
    private var accountDetailsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Account Details")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            VStack(spacing: 0) {
                // Account Name
                VStack(alignment: .leading, spacing: 6) {
                    Text("Account Name")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                    HStack {
                        TextField("e.g., SBI Savings Account", text: $accountName)
                            .font(.system(size: 15, design: .rounded))
                        Image(systemName: "person.text.rectangle")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(.secondarySystemGroupedBackground))

                Divider().padding(.leading, 16)

                // Account Type
                VStack(alignment: .leading, spacing: 6) {
                    Text("Account Type")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                    HStack {
                        Text(selectedSubType)
                            .font(.system(size: 15, design: .rounded))
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(.secondarySystemGroupedBackground))

                Divider().padding(.leading, 16)

                // Currency
                VStack(alignment: .leading, spacing: 6) {
                    Text("Currency")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                    HStack {
                        Text("INR (₹)")
                            .font(.system(size: 15, design: .rounded))
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(.secondarySystemGroupedBackground))

                Divider().padding(.leading, 16)

                // Opening Balance
                VStack(alignment: .leading, spacing: 6) {
                    Text("Opening Balance (Optional)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.appGreen)
                    HStack(alignment: .center, spacing: 4) {
                        Text("₹")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                        TextField("0.00", text: $initialBalance)
                            .font(.system(size: 18, weight: .regular, design: .rounded))
                            .keyboardType(.decimalPad)
                            .foregroundColor(.primary)
                        Spacer()
                        Text(".00")
                            .font(.system(size: 18, weight: .regular, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(.secondarySystemGroupedBackground))
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
        }
    }

    // MARK: - Bottom Save CTA Button
    private var bottomSaveCTA: some View {
        VStack(spacing: 0) {
            Button {
                Haptics.medium()
                saveAccount()
            } label: {
                HStack(spacing: 8) {
                    Text("Add Account")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.appGreenDeep)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 28)
            .background(Color.appBackground.ignoresSafeArea())
        }
    }

    private func saveAccount() {
        let bal = Double(initialBalance) ?? 0
        let isCard = selectedCategory == .creditCard
        let num = accountNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : "•••• \(accountNumber)"
        let name = accountName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? selectedCategory.rawValue : accountName

        let newAccount = Account(
            name: name,
            categoryRaw: selectedCategory.rawValue,
            subType: selectedSubType,
            accountNumber: num,
            balance: isCard ? -abs(bal) : bal,
            isCreditCard: isCard,
            includeInNetBalance: includeInNetBalance
        )

        AccountManager.shared.addAccount(newAccount)
        onSave?(newAccount)
        dismiss()
    }
}

#Preview {
    AddAccountView()
}

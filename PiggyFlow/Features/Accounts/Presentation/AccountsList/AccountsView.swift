import SwiftUI
import SwiftData

struct UserAccountItem: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var type: String
    var accountNumber: String
    var balance: Double
    var isCreditCard: Bool
    var iconName: String
    var iconColor: Color
    var iconBgColor: Color
    var caption: String
}

struct AccountsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var isBalanceHidden: Bool = false
    @State private var showAddAccountSheet: Bool = false
    @State private var selectedAccountForDetail: UserAccountItem?

    @State private var accounts: [UserAccountItem] = [
        UserAccountItem(name: "SBI Bank", type: "Savings Account", accountNumber: "•••• 1234", balance: 48560.00, isCreditCard: false, iconName: "building.columns.fill", iconColor: .white, iconBgColor: Color.appGreen, caption: "Available Balance"),
        UserAccountItem(name: "HDFC Bank", type: "Current Account", accountNumber: "•••• 5678", balance: 57000.00, isCreditCard: false, iconName: "building.2.fill", iconColor: .white, iconBgColor: Color(red: 153/255, green: 27/255, blue: 60/255), caption: "Available Balance"),
        UserAccountItem(name: "HDFC Regalia Credit Card", type: "Credit Card", accountNumber: "•••• 2345", balance: -28340.00, isCreditCard: true, iconName: "creditcard.fill", iconColor: .white, iconBgColor: Color(red: 30/255, green: 64/255, blue: 175/255), caption: "Outstanding"),
        UserAccountItem(name: "PhonePe Wallet", type: "Wallet", accountNumber: "", balance: 5250.00, isCreditCard: false, iconName: "wallet.pass.fill", iconColor: .white, iconBgColor: Color(red: 109/255, green: 40/255, blue: 217/255), caption: "Available Balance"),
        UserAccountItem(name: "Cash", type: "Physical Cash", accountNumber: "", balance: 8660.00, isCreditCard: false, iconName: "banknote.fill", iconColor: .white, iconBgColor: Color(red: 217/255, green: 119/255, blue: 6/255), caption: "Physical Cash")
    ]

    private var bankAccountsTotal: Double {
        accounts.filter { !$0.isCreditCard && $0.type.contains("Account") }.reduce(0) { $0 + $1.balance }
    }

    private var creditCardsTotal: Double {
        accounts.filter { $0.isCreditCard }.reduce(0) { $0 + $1.balance }
    }

    private var walletsTotal: Double {
        accounts.filter { $0.type == "Wallet" }.reduce(0) { $0 + $1.balance }
    }

    private var cashTotal: Double {
        accounts.filter { $0.type.contains("Cash") }.reduce(0) { $0 + $1.balance }
    }

    private var totalBalance: Double {
        accounts.reduce(0) { $0 + $1.balance }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerBar

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Accounts Summary Card
                    accountsSummaryCard

                    // Your Accounts List Section
                    yourAccountsSection

                    // Bottom 2 Quick Action Cards
                    bottomGridCards
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 12)
            }
            // Reserves exactly the CTA's real height as scroll clearance — a hardcoded
            // Spacer guess broke as soon as the account list grew past ~1 screen, letting
            // list content render behind/below the "floating" button.
            .safeAreaInset(edge: .bottom) { stickyBottomCTA }
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .background(Color.appBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .sheet(isPresented: $showAddAccountSheet) {
            AddAccountView(onSave: { newAccount in
                accounts.append(newAccount)
            })
        }
    }

    // MARK: - Header Bar
    private var headerBar: some View {
        VStack(spacing: 4) {
            HStack {
                BackButton { dismiss() }

                Spacer()

                Text("Accounts")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Spacer()

                Button {
                    Haptics.light()
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color.appGreen)
                        .frame(width: 40, height: 40)
                        .background(Color.appGreen.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)

            Text("Manage your cash, bank accounts, cards and wallets")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(Color.appBackground)
    }

    // MARK: - Accounts Summary Card
    private var accountsSummaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Card Title & Hide Balance Toggle
            HStack {
                Text("Accounts Summary")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)

                Spacer()

                Button {
                    isBalanceHidden.toggle()
                    Haptics.light()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isBalanceHidden ? "eye" : "eye.slash")
                            .font(.system(size: 12, weight: .bold))
                        Text(isBalanceHidden ? "Show Balance" : "Hide Balance")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(Color.appGreen)
                }
                .buttonStyle(.plain)
            }

            HStack(alignment: .center, spacing: 14) {
                // Total Balance
                VStack(alignment: .leading, spacing: 8) {
                    Text("Total Balance")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)

                    if isBalanceHidden {
                        Text("••••••••")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("₹\(Int(totalBalance).formatted())")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            Text(".00")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    // Percentage Badge
                    HStack(spacing: 4) {
                        Image(systemName: "triangle.fill")
                            .font(.system(size: 9, weight: .bold))
                        Text("8.5% vs last month")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(Color.appGreen)
                    .lineLimit(1)
                    .fixedSize()
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Donut Chart Ring
                ZStack {
                    Circle()
                        .stroke(Color.appGreen, lineWidth: 13)
                        .frame(width: 76, height: 76)

                    Circle()
                        .trim(from: 0.50, to: 0.72)
                        .stroke(Color(red: 134/255, green: 239/255, blue: 172/255), lineWidth: 13)
                        .frame(width: 76, height: 76)

                    Circle()
                        .trim(from: 0.72, to: 0.86)
                        .stroke(Color.appTeal, lineWidth: 13)
                        .frame(width: 76, height: 76)

                    Circle()
                        .trim(from: 0.86, to: 1.0)
                        .stroke(Color(red: 252/255, green: 211/255, blue: 77/255), lineWidth: 13)
                        .frame(width: 76, height: 76)
                }

                // Breakdown Legend
                VStack(alignment: .leading, spacing: 8) {
                    summaryLegendRow(color: Color.appGreen, label: "Bank Accounts", amount: "₹\(Int(bankAccountsTotal).formatted())", isNegative: false)
                    summaryLegendRow(color: Color(red: 134/255, green: 239/255, blue: 172/255), label: "Credit Cards", amount: "-₹\(abs(Int(creditCardsTotal)).formatted())", isNegative: true)
                    summaryLegendRow(color: Color.appTeal, label: "Wallets", amount: "₹\(Int(walletsTotal).formatted())", isNegative: false)
                    summaryLegendRow(color: Color(red: 252/255, green: 211/255, blue: 77/255), label: "Cash", amount: "₹\(Int(cashTotal).formatted())", isNegative: false)
                }
                .frame(width: 120, alignment: .leading)
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    @ViewBuilder
    private func summaryLegendRow(color: Color, label: String, amount: String, isNegative: Bool) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                Text(label)
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            Text(isBalanceHidden ? "••••" : amount)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(isNegative ? .appExpenseRed : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.leading, 10)
        }
    }

    // MARK: - Your Accounts List Section
    private var yourAccountsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your Accounts")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Spacer()

                Button {
                    Haptics.light()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 11, weight: .bold))
                        Text("Reorder")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(Color.appGreen)
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 10) {
                ForEach(accounts) { acc in
                    accountCardRow(acc)
                }
            }
        }
    }

    @ViewBuilder
    private func accountCardRow(_ acc: UserAccountItem) -> some View {
        HStack(spacing: 14) {
            // Icon Avatar
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(acc.iconBgColor)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: acc.iconName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(acc.iconColor)
                )

            // Name & Subtitle
            VStack(alignment: .leading, spacing: 3) {
                Text(acc.name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(acc.type)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                    if !acc.accountNumber.isEmpty {
                        Text(acc.accountNumber)
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Balance Amount & Caption
            VStack(alignment: .trailing, spacing: 3) {
                if isBalanceHidden {
                    Text("••••••••")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text(acc.balance < 0 ? "-₹\(abs(Int(acc.balance)).formatted())" : "₹\(Int(acc.balance).formatted())")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(acc.balance < 0 ? .appExpenseRed : .primary)
                        Text(".00")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(acc.balance < 0 ? .appExpenseRed.opacity(0.8) : .secondary)
                    }
                }

                if !acc.caption.isEmpty {
                    Text(acc.caption)
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary.opacity(0.5))
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
    }

    // MARK: - Bottom Grid Cards
    private var bottomGridCards: some View {
        HStack(spacing: 12) {
            // Left: Recent Transactions
            VStack(alignment: .leading, spacing: 10) {
                Circle()
                    .fill(Color.appGreen.opacity(0.12))
                    .frame(width: 38, height: 38)
                    .overlay(
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Color.appGreen)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Recent Transactions")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("View recent transactions from all accounts")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                NavigationLink(destination: StatsView().hidesTabBarOnPush()) {
                    HStack(spacing: 4) {
                        Text("View All")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(Color.appGreen)
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 140)
            .background(Color.appGreen.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            // Right: Spending by Account
            VStack(alignment: .leading, spacing: 10) {
                Circle()
                    .fill(Color(red: 254/255, green: 243/255, blue: 199/255))
                    .frame(width: 38, height: 38)
                    .overlay(
                        Image(systemName: "chart.pie.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Color(red: 217/255, green: 119/255, blue: 6/255))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Spending by Account")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("See how much you've spent from each account")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                NavigationLink(destination: StatsView().hidesTabBarOnPush()) {
                    HStack(spacing: 4) {
                        Text("View Report")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(Color.appGreen)
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 140)
            .background(Color(red: 254/255, green: 252/255, blue: 232/255))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    // MARK: - Sticky Bottom CTA
    private var stickyBottomCTA: some View {
        VStack(spacing: 8) {
            Button {
                Haptics.medium()
                showAddAccountSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                    Text("Add Account")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.appGreenDeep)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain)

            HStack(spacing: 4) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10))
                Text("Your data is secure and encrypted")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
            }
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(
            Color.appBackground
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: -4)
        )
    }
}

// MARK: - Add Account Sheet Modal
struct AddAccountModalSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var accountName: String = ""
    @State private var accountType: String = "Savings Account"
    @State private var initialBalance: String = ""
    @State private var accountNumber: String = ""

    let accountTypes = ["Savings Account", "Current Account", "Credit Card", "Wallet", "Physical Cash"]
    let onSave: (UserAccountItem) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Account Name")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                        TextField("e.g. Axis Bank, HDFC Card", text: $accountName)
                            .padding(12)
                            .background(Color.primary.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Account Type")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                        Picker("Type", selection: $accountType) {
                            ForEach(accountTypes, id: \.self) { t in
                                Text(t).tag(t)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Initial Balance (₹)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                        TextField("e.g. 50000", text: $initialBalance)
                            .keyboardType(.numberPad)
                            .padding(12)
                            .background(Color.primary.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Last 4 Digits (Optional)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                        TextField("e.g. 1234", text: $accountNumber)
                            .keyboardType(.numberPad)
                            .padding(12)
                            .background(Color.primary.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)

                Spacer()

                Button {
                    let bal = Double(initialBalance) ?? 0
                    let isCard = accountType == "Credit Card"
                    let num = accountNumber.isEmpty ? "" : "•••• \(accountNumber)"
                    let item = UserAccountItem(
                        name: accountName.isEmpty ? "New Account" : accountName,
                        type: accountType,
                        accountNumber: num,
                        balance: isCard ? -abs(bal) : bal,
                        isCreditCard: isCard,
                        iconName: isCard ? "creditcard.fill" : "building.columns.fill",
                        iconColor: .white,
                        iconBgColor: isCard ? Color.appExpenseRed : Color.appGreen,
                        caption: isCard ? "Outstanding" : "Available Balance"
                    )
                    onSave(item)
                    dismiss()
                } label: {
                    Text("Save Account")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.appGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle("Add New Account")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    AccountsView()
}

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @ObservedObject private var accountManager = AccountManager.shared

    @AppStorage("username") private var userName: String = ""
    @Query private var expenses: [Expense]
    @Query private var incomes: [Income]
    @Query private var trackerRecords: [TrackerRecord]

    @State private var isBalanceVisible: Bool = true
    @State private var showAddAccountSheet: Bool = false
    @State private var selectedTransactionForEdit: TransactionItem?

    private var homeAccounts: [Account] { accountManager.accounts }

    // Time-based dynamic greeting
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Good night"
        }
    }

    private var displayName: String {
        let trimmed = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Vasanth" : trimmed
    }

    enum TransactionItem: Identifiable {
        case expense(Expense)
        case income(Income)
        
        var id: String {
            switch self {
            case .expense(let e): return e.id
            case .income(let i): return i.id
            }
        }
        
        var date: Date {
            switch self {
            case .expense(let e): return e.date
            case .income(let i): return i.date
            }
        }
        
        var title: String {
            switch self {
            case .expense(let e): return e.name
            case .income(let i): return i.name
            }
        }
        
        var type: String {
            switch self {
            case .expense(let e): return e.type
            case .income(let i): return i.type
            }
        }
        
        var emoji: String {
            switch self {
            case .expense(let e): return e.emoji
            case .income: return "💰"
            }
        }
        
        var amount: Double {
            switch self {
            case .expense(let e): return e.price
            case .income(let i): return i.income
            }
        }
        
        var note: String {
            switch self {
            case .expense(let e): return e.note
            case .income(let i): return i.note
            }
        }

        /// Which real account this was paid from/into — empty when the user hasn't picked
        /// one. Every "• HDFC Bank"-style literal in the app should read from this instead.
        var account: String {
            switch self {
            case .expense(let e): return e.account
            case .income(let i): return i.account
            }
        }

        var color: Color {
            switch self {
            case .expense: return .appExpenseRed
            case .income: return .appGreen
            }
        }
    }

    private var allTransactions: [TransactionItem] {
        let expenseItems = expenses.map { TransactionItem.expense($0) }
        let incomeItems = incomes.map { TransactionItem.income($0) }
        return (expenseItems + incomeItems).sorted { $0.date > $1.date }
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

    // MARK: - This Month Overview (real data)

    private var monthExpenses: [Expense] {
        let cal = Calendar.current
        return expenses.filter { cal.isDate($0.date, equalTo: Date(), toGranularity: .month) }
    }

    private var monthTotalSpend: Double { monthExpenses.reduce(0) { $0 + $1.price } }

    private static let monthOverviewPalette: [Color] = [
        .appGreen,
        Color(red: 134/255, green: 239/255, blue: 172/255),
        .appWarningAmber,
        .appTeal,
        .gray.opacity(0.5)
    ]

    private var monthCategoryBreakdown: [CategoryTotal] {
        CalculateExpenseSummaryUseCase.categoryBreakdown(of: monthExpenses, total: monthTotalSpend)
    }

    private var monthCategoryDonutSegments: [(start: CGFloat, end: CGFloat, color: Color)] {
        var cursor: CGFloat = 0
        return monthCategoryBreakdown.enumerated().map { index, cat in
            let fraction = CGFloat(cat.percentage / 100.0)
            let seg = (start: cursor, end: min(1, cursor + fraction), color: Self.monthOverviewPalette[index % Self.monthOverviewPalette.count])
            cursor += fraction
            return seg
        }
    }

    private var monthWeeklyTrend: [SpendingAggregates.WeeklyTotal] {
        SpendingAggregates.weeklyTotals(expenses: expenses, incomes: incomes, month: Date())
    }

    private var monthWeeklyMax: Double {
        monthWeeklyTrend.map(\.expense).max() ?? 0
    }

    private func barHeight(for value: Double) -> CGFloat {
        guard monthWeeklyMax > 0 else { return 4 }
        return 4 + CGFloat(value / monthWeeklyMax) * 44
    }

    private var formattedBalanceInteger: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        let val = abs(netBalance)
        return formatter.string(from: NSNumber(value: val)) ?? "\(Int(val))"
    }

    private var formattedBalanceCents: String {
        let cents = Int(round(abs(netBalance).truncatingRemainder(dividingBy: 1) * 100))
        return String(format: ".%02d", cents)
    }

    private var savingsRatePercentage: Double {
        guard totalIncome > 0 else { return 0 }
        let rate = ((totalIncome - totalExpenses) / totalIncome) * 100
        return max(0, min(100, rate))
    }

    /// Change in net balance against the previous calendar month.
    /// `nil` when there's no prior month to compare against, so the pill can hide
    /// rather than show a hardcoded "12.5%".
    private var monthOverMonthChange: Double? {
        let calendar = Calendar.current
        let now = Date()
        guard let lastMonth = calendar.date(byAdding: .month, value: -1, to: now) else { return nil }

        func net(in month: Date) -> Double {
            let inc = incomes.filter { calendar.isDate($0.date, equalTo: month, toGranularity: .month) }
                .reduce(0) { $0 + $1.income }
            let exp = expenses.filter { calendar.isDate($0.date, equalTo: month, toGranularity: .month) }
                .reduce(0) { $0 + $1.price }
            return inc - exp
        }

        let previous = net(in: lastMonth)
        guard previous != 0 else { return nil }
        return ((net(in: now) - previous) / abs(previous)) * 100
    }

    private var upcomingPayments: [TrackerRecord] {
        let sorted = trackerRecords.filter { !$0.isPaid }.sorted { $0.dueDate < $1.dueDate }
        return Array(sorted.prefix(3))
    }

    /// Unpaid trackers falling due within a week — drives the "N payments due soon" pill,
    /// which was previously hardcoded to "2".
    private var dueSoonCount: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return upcomingPayments.filter { record in
            let days = calendar.dateComponents([.day], from: today,
                                               to: calendar.startOfDay(for: record.dueDate)).day ?? .max
            return days >= 0 && days <= 7
        }.count
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.appBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 1. Header Bar — stays fixed while the rest of the screen scrolls beneath it.
                    headerBar
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 14)
                        .background(Color.appBackground)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            // 2. Green Overview Hero Card
                            heroOverviewCard

                            // 3. Quick Action Buttons Row
                            quickActionsRow

                            // 4. Side-by-Side Cards (Accounts & Upcoming Payments)
                            accountsAndPaymentsGrid

                            // 5. This Month Overview Card
                            monthOverviewCard

                            // 6. Recent Transactions Section
                            recentTransactionsSection
                        }
                        .padding(.horizontal, 16)
                    }
                    // Clears the floating tab bar. A trailing Spacer inside the stack was
                    // being collapsed, leaving the last card underneath the bar.
                    .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 96) }
                }
            }
            .sheet(item: $selectedTransactionForEdit) { item in
                AddExpenseBottomSheetView(itemToEdit: item)
            }
            .navigationDestination(isPresented: $showAddAccountSheet) {
                // A real push, not a sheet, so it slides in like every other full screen in
                // the app instead of covering from the bottom with a sheet's gray letterboxing.
                AddAccountView().hidesTabBarOnPush()
            }
        }
    }

    // MARK: - 1. Header Bar
    private var headerBar: some View {
        HStack(spacing: 10) {
            // Left 1: Settings Menu Icon (Soft Mint Squircle Button)
            NavigationLink(destination: SettingsView().hidesTabBarOnPush()) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.appGreenDeep)
                    .frame(width: 40, height: 40)
                    .background(Color.appGreen.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)

            // Center: Greeting & Subtitle Stack
            VStack(alignment: .leading, spacing: 2) {
                Text("\(greeting), \(displayName)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text("Here’s your financial overview")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .layoutPriority(1)

            Spacer(minLength: 2)

            // Right 1: Notification Bell with Green Badge Dot
            NavigationLink(destination: NotificationView().hidesTabBarOnPush()) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 36, height: 36)

                    Circle()
                        .fill(Color.appGreen)
                        .frame(width: 8, height: 8)
                        .offset(x: -1, y: 1)
                }
            }
            .buttonStyle(.plain)

            // Right 2: Profile Avatar Circle with Green Border
            NavigationLink(destination: ProfileView().hidesTabBarOnPush()) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.appGreen, Color.appGreenDeep],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)

                    Text(String(displayName.prefix(1)).uppercased())
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .overlay(Circle().stroke(Color.appGreen, lineWidth: 1.5))
                .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 2. Green Overview Hero Card
    private var heroOverviewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Month-over-month change leads the card, above the balance it qualifies.
            if let change = monthOverMonthChange {
                monthChangeChip(change)
            }

            // Balance block (with metrics beneath it) and the savings gauge sit side by
            // side, centered against each other so the ring lands mid-height on the right
            // rather than pinned to the top of the balance figure alone.
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    balanceSummary
                    heroMetrics
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                savingsRateRing
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(heroBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 5)
    }

    private var balanceSummary: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("Net Balance")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.94))

                Button {
                    isBalanceVisible.toggle()
                    Haptics.light()
                } label: {
                    Image(systemName: isBalanceVisible ? "eye" : "eye.slash")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.94))
                }
                .buttonStyle(.plain)
            }

            if isBalanceVisible {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("₹\(formattedBalanceInteger)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text(formattedBalanceCents)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
            } else {
                Text("••••••••")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
    }

    private func monthChangeChip(_ change: Double) -> some View {
        HStack(spacing: 7) {
            HStack(spacing: 4) {
                Image(systemName: "triangle.fill")
                    .font(.system(size: 7, weight: .bold))
                    .rotationEffect(.degrees(change >= 0 ? 0 : 180))
                Text("\(String(format: "%.1f", abs(change)))%")
            }
            .foregroundColor(Color(red: 196/255, green: 251/255, blue: 167/255))

            Text("vs last month")
                .foregroundColor(.white.opacity(0.95))
        }
        .font(.system(size: 11.5, weight: .bold, design: .rounded))
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.13))
        .clipShape(Capsule())
    }

    /// Savings gauge: an arc whose gap is centred on six o'clock, like a speedometer, filling
    /// clockwise from the bottom-left end up through the top. The gap belongs at the bottom —
    /// opening it at the top reads as a gauge turned upside down.
    private var savingsRateRing: some View {
        let gapDegrees: Double = 70
        let sweep = CGFloat(1 - gapDegrees / 360)
        let fill = sweep * CGFloat(savingsRatePercentage / 100)
        // Trim starts at three o'clock; turn it so the arc's ends straddle six.
        let rotation = 90 + gapDegrees / 2
        let stroke = StrokeStyle(lineWidth: 9, lineCap: .round)

        return ZStack {
            Circle()
                .trim(from: 0, to: sweep)
                .stroke(Color.white.opacity(0.18), style: stroke)
                .rotationEffect(.degrees(rotation))

            Circle()
                .trim(from: 0, to: fill)
                .stroke(
                    LinearGradient(
                        colors: [Color(red: 248/255, green: 255/255, blue: 237/255), Color(red: 210/255, green: 251/255, blue: 161/255)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: stroke
                )
                .rotationEffect(.degrees(rotation))

            // Sized to clear the stroke: at 21/10.5 the label spanned nearly the full ring and
            // crowded the arc, where the design leaves the text well inside it.
            VStack(spacing: 1) {
                Text("\(String(format: "%.1f", savingsRatePercentage))%")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                Text("Savings Rate")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
            }
            .foregroundColor(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        // Sized close to the balance block beside it: the gauge is the tallest thing in that
        // row, so every extra point here becomes empty space under the balance figure.
        .frame(width: 94, height: 94)
    }

    private var heroMetrics: some View {
        // Columns hug their content rather than taking equal shares of the card, so the gap
        // between them is this fixed spacing instead of whatever slack equal widths left over.
        HStack(alignment: .top, spacing: 15) {
            heroMetric(title: "Income", value: "₹\(Int(totalIncome).formatted())", valueColor: .white)

            heroMetric(title: "Expenses", value: "₹\(Int(totalExpenses).formatted())", valueColor: Color(red: 255/255, green: 107/255, blue: 107/255))

            heroMetric(title: "Savings Rate", value: "\(String(format: "%.1f", savingsRatePercentage))%", valueColor: .white)

            Spacer(minLength: 0)
        }
    }

    private func heroMetric(title: String, value: String, valueColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.62))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var heroBackground: some View {
        ZStack {
            // The brand pair — every other hero gradient in the app (Settings, About,
            // Category detail) already uses these; this card had its own one-off values.
            LinearGradient(
                colors: [.appGreen, .appGreenDeep],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(colors: [.white.opacity(0.11), .clear], center: .topTrailing, startRadius: 10, endRadius: 210)
            RadialGradient(colors: [.black.opacity(0.13), .clear], center: .bottomLeading, startRadius: 12, endRadius: 230)
        }
    }

    // MARK: - 3. Quick Actions Row (5 Action Cards)
    private var quickActionsRow: some View {
        HStack(spacing: 8) {
                // 1. Scan Bill — pushed like items 4 & 5 below, not covered from the bottom:
                // all five belong to the same row and should feel like the same kind of
                // navigation, not three sheets and two pushes.
                NavigationLink(destination: ScanView().hidesTabBarOnPush()) {
                    quickActionContent(
                        icon: "camera.fill",
                        iconColor: Color.appGreen,
                        bgColor: Color.appGreen.opacity(0.12),
                        title: "Scan Bill",
                        subtitle: "AI Extract"
                    )
                }
                .buttonStyle(.plain)

                // 2. Add Expense
                NavigationLink(destination: AddExpenseView().hidesTabBarOnPush()) {
                    quickActionContent(
                        icon: "square.and.pencil",
                        iconColor: Color.appGreen,
                        bgColor: Color.appGreen.opacity(0.12),
                        title: "Add Expense",
                        subtitle: "Manually"
                    )
                }
                .buttonStyle(.plain)

                // 3. Add Income
                NavigationLink(destination: AddIncomeView().hidesTabBarOnPush()) {
                    quickActionContent(
                        icon: "creditcard.fill",
                        iconColor: Color.appGreen,
                        bgColor: Color.appGreen.opacity(0.12),
                        title: "Add Income",
                        subtitle: "Record"
                    )
                }
                .buttonStyle(.plain)

                // 4. Add Tracker
                NavigationLink(destination: AddTrackerView().hidesTabBarOnPush()) {
                    quickActionContent(
                        icon: "calendar",
                        iconColor: Color.appWarningAmber,
                        bgColor: Color.appWarningAmber.opacity(0.15),
                        title: "Add Tracker",
                        subtitle: "EMI, Subs"
                    )
                }
                .buttonStyle(.plain)

                // 5. Budget
                NavigationLink(destination: BudgetGoalsView().hidesTabBarOnPush()) {
                    quickActionContent(
                        icon: "target",
                        iconColor: Color.appExpenseRed,
                        bgColor: Color.appExpenseRed.opacity(0.12),
                        title: "Budget",
                        subtitle: "Set Limit"
                    )
                }
                .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func quickActionContent(icon: String, iconColor: Color, bgColor: Color, title: String, subtitle: String) -> some View {
        VStack(spacing: 7) {
            Circle()
                .fill(bgColor)
                .frame(width: 38, height: 38)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(iconColor)
                )

            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(subtitle)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 4)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 106)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.07), radius: 10, x: 0, y: 4)
    }

    // MARK: - 4. Side-by-Side Cards (Accounts & Upcoming Payments)
    private var accountsAndPaymentsGrid: some View {
        HStack(alignment: .top, spacing: 10) {
            // Left Card: Accounts
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Accounts")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Spacer()
                    NavigationLink(destination: AccountsView().hidesTabBarOnPush()) {
                        Text("View all")
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                            .foregroundColor(.appGreen)
                    }
                }

                if homeAccounts.isEmpty {
                    Text("No accounts yet")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                } else {
                    VStack(spacing: 12) {
                        ForEach(homeAccounts.prefix(3)) { acc in
                            HStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.appGreen)
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        Image(systemName: acc.iconName)
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                    )

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(formattedAccountName(acc.name))
                                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                    Text(acc.subType)
                                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }

                                Spacer(minLength: 4)

                                HStack(spacing: 3) {
                                    Text(acc.balance < 0 ? "-₹\(abs(Int(acc.balance)).formatted())" : "₹\(Int(acc.balance).formatted())")
                                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                                        .foregroundColor(acc.balance < 0 ? .appExpenseRed : .primary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.85)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.secondary.opacity(0.6))
                                }
                                .layoutPriority(1)
                            }
                        }
                    }
                }

                Button {
                    Haptics.medium()
                    showAddAccountSheet = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                        Text("Add Account")
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.appGreen)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.appGreen.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)

            // Right Card: Upcoming Payments
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Upcoming Payments")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 2)
                    NavigationLink(destination: UpcomingPaymentsView().hidesTabBarOnPush()) {
                        Text("View all")
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                            .foregroundColor(.appGreen)
                    }
                }

                if upcomingPayments.isEmpty {
                    Text("No upcoming payments")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                } else {
                    VStack(spacing: 12) {
                        ForEach(upcomingPayments.prefix(3)) { record in
                            HStack(spacing: 8) {
                                trackerIconAvatar(record)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(record.name)
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.75)
                                    Text(record.subType.capitalized)
                                        .font(.system(size: 10, weight: .medium, design: .rounded))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.75)
                                }

                                Spacer(minLength: 2)

                                VStack(alignment: .trailing, spacing: 1) {
                                    Text(record.dueDate.formatted(.dateTime.day().month(.abbreviated)))
                                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                                        .foregroundColor(.secondary)

                                    Text("₹\(Int(record.amount).formatted())")
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                    }
                }

                NavigationLink(destination: UpcomingPaymentsView().hidesTabBarOnPush()) {
                    HStack(spacing: 5) {
                        Image(systemName: "timer")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundColor(.appGreen)
                        Text(upcomingPayments.isEmpty ? "Add a tracker" : "\(upcomingPayments.count) payments due soon")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.appGreen)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.appGreen)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .background(Color.appGreen.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
    }

    @ViewBuilder
    private func trackerIconAvatar(_ record: TrackerRecord) -> some View {
        if record.name.lowercased().contains("netflix") {
            ZStack {
                Circle().fill(Color.black)
                Text("N")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundColor(.red)
            }
            .frame(width: 28, height: 28)
        } else if record.name.lowercased().contains("spotify") {
            ZStack {
                Circle().fill(Color.black)
                Image(systemName: "wave.3.forward.circle.fill")
                    .font(.system(size: 17))
                    .foregroundColor(Color(red: 30/255, green: 215/255, blue: 96/255))
            }
            .frame(width: 28, height: 28)
        } else {
            Circle()
                .fill(Color.appGreen.opacity(0.12))
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: "house.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.appGreen)
                )
        }
    }

    // MARK: - 5. This Month Overview Card (Full Width)
    private var monthOverviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("This Month Overview")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
                NavigationLink(destination: ReportDetailView().hidesTabBarOnPush()) {
                    HStack(spacing: 3) {
                        Text("View Report")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.appGreen)
                }
            }

            HStack(alignment: .top, spacing: 14) {
                // Left Column: Total Spend + Bar Chart
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Total Spend")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                        Text("₹\(Int(monthTotalSpend).formatted())")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }

                    // Mini Bar Chart with a dashed average-spend reference line
                    ZStack(alignment: .top) {
                        GeometryReader { geo in
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: 0))
                                path.addLine(to: CGPoint(x: geo.size.width, y: 0))
                            }
                            .stroke(Color.secondary.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        }
                        .frame(height: 1)
                        .padding(.top, 12)

                        HStack(alignment: .bottom, spacing: 3) {
                            ForEach(monthWeeklyTrend) { point in
                                miniBar(height: barHeight(for: point.expense), label: point.label, isHighlighted: point.expense > 0)
                            }
                        }
                    }
                    .frame(height: 68)
                }
                .frame(width: 104, alignment: .leading)

                Divider()

                // Right Column: Top Categories + Donut Chart & Legend
                VStack(alignment: .leading, spacing: 10) {
                    Text("Top Categories")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)

                    HStack(alignment: .center, spacing: 8) {
                        // Multi-color Donut Ring Chart
                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.15), lineWidth: 9)
                            ForEach(Array(monthCategoryDonutSegments.enumerated()), id: \.offset) { _, seg in
                                Circle()
                                    .trim(from: seg.start, to: seg.end)
                                    .stroke(seg.color, lineWidth: 9)
                            }
                        }
                        .rotationEffect(.degrees(-90))
                        .frame(width: 46, height: 46)

                        // Category List Breakdown
                        if monthCategoryBreakdown.isEmpty {
                            Text("No spending yet")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            VStack(alignment: .leading, spacing: 9) {
                                ForEach(Array(monthCategoryBreakdown.prefix(5).enumerated()), id: \.offset) { index, cat in
                                    categoryLegendRow(
                                        color: Self.monthOverviewPalette[index % Self.monthOverviewPalette.count],
                                        name: cat.name,
                                        amount: AppFormatter.currencyRounded(cat.amount),
                                        percent: "\(String(format: "%.0f", cat.percentage))%"
                                    )
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Bottom Button: View All Insights
            NavigationLink(destination: FinancialInsightsView().hidesTabBarOnPush()) {
                HStack(spacing: 5) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 11, weight: .bold))
                    Text("View All Insights")
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundColor(.appGreen)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.appGreen.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    @ViewBuilder
    private func miniBar(height: CGFloat, label: String, isHighlighted: Bool) -> some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3)
                .fill(isHighlighted ? Color.appGreen : Color.appGreen.opacity(0.3))
                .frame(width: 7, height: height)
            Text(label)
                .font(.system(size: 7, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func formattedAccountName(_ name: String) -> String {
        if name.count > 14 {
            return String(name.prefix(12)) + ".."
        }
        return name
    }

    private func formattedCategoryName(_ name: String) -> String {
        if name.count > 18 {
            return String(name.prefix(16)) + ".."
        }
        return name
    }

    @ViewBuilder
    private func categoryLegendRow(color: Color, name: String, amount: String, percent: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
            Text(formattedCategoryName(name))
                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .layoutPriority(1)
            Spacer(minLength: 2)
            Text(amount)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(percent)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    // MARK: - 6. Recent Transactions Section
    private var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Transactions")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
                NavigationLink(destination: RecentTransactionsView().hidesTabBarOnPush()) {
                    Text("View all")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.appGreen)
                }
            }

            if allTransactions.isEmpty {
                Text("No transactions yet")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            } else {
                // Resolved once — `allTransactions` maps, concatenates and sorts every
                // record, so reading it inside the loop repeated that per row.
                let recent = Array(allTransactions.prefix(5))

                VStack(spacing: 0) {
                    ForEach(Array(recent.enumerated()), id: \.element.id) { pair in
                        let item = pair.element
                        NavigationLink(destination: TransactionDetailView(item: item).hidesTabBarOnPush()) {
                            ExpenseItemCard(
                                emoji: item.emoji,
                                title: item.title.isEmpty ? item.type : item.title,
                                date: item.date,
                                amount: item.amount,
                                color: item.color,
                                isIncome: item.color == .appGreen
                            )
                        }
                        .buttonStyle(.plain)

                        if pair.offset != recent.count - 1 {
                            Divider()
                                .padding(.leading, 64)
                        }
                    }
                }
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
            }
        }
    }

}

#Preview {
    HomeView()
}

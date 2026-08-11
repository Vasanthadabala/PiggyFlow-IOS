import SwiftUI
import SwiftData

struct ExpensesView: View {
    @Environment(\.modelContext) private var context
    @Query private var expenses: [Expense]
    @Query private var incomes: [Income]

    @State private var selectedPeriod: PeriodFilter = .allTime

    /// The label used to read "May 1 – May 31, 2025" no matter what the data covered, while
    /// the totals underneath were computed over every expense ever recorded. Now the chip both
    /// states the real period and controls it.
    enum PeriodFilter: String, CaseIterable, Identifiable {
        case thisMonth = "This Month"
        case lastMonth = "Last Month"
        case thisYear = "This Year"
        case allTime = "All Time"

        var id: String { rawValue }

        func interval(now: Date = Date()) -> DateInterval? {
            let cal = Calendar.current
            switch self {
            case .allTime: return nil
            case .thisMonth: return cal.dateInterval(of: .month, for: now)
            case .lastMonth:
                guard let prev = cal.date(byAdding: .month, value: -1, to: now) else { return nil }
                return cal.dateInterval(of: .month, for: prev)
            case .thisYear: return cal.dateInterval(of: .year, for: now)
            }
        }

        var rangeText: String {
            guard let interval = interval() else { return "All Time" }
            let end = Calendar.current.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
            let from = DateFormatter(); from.dateFormat = "MMM d"
            let to = DateFormatter(); to.dateFormat = "MMM d, yyyy"
            return "\(from.string(from: interval.start)) – \(to.string(from: end))"
        }
    }
    @State private var showSearchSheet: Bool = false
    @State private var showFilterSheet: Bool = false
    @State private var activeSheet: ActionSheetType?

    enum ActionSheetType: Identifiable {
        case insights, categories, recurring, export
        var id: Int { hashValue }
    }

    /// Expenses inside the selected period — the single funnel every figure on this screen
    /// reads, so the header chip can never disagree with the numbers below it.
    private var periodExpenses: [Expense] {
        guard let interval = selectedPeriod.interval() else { return expenses }
        return expenses.filter { interval.contains($0.date) }
    }

    private var totalExpensesAmount: Double {
        periodExpenses.reduce(0) { $0 + $1.price }
    }

    // MARK: - Real data

    private static let categoryPalette: [Color] = [
        .appGreen,
        Color(red: 132/255, green: 204/255, blue: 22/255),
        Color(red: 234/255, green: 179/255, blue: 8/255),
        Color(red: 249/255, green: 115/255, blue: 22/255),
        Color(red: 236/255, green: 72/255, blue: 153/255),
        Color(red: 59/255, green: 130/255, blue: 246/255)
    ]

    private var categoryBreakdown: [CategoryTotal] {
        CalculateExpenseSummaryUseCase.categoryBreakdown(of: periodExpenses, total: totalExpensesAmount)
    }

    private var topCategory: CategoryTotal? { categoryBreakdown.first }
    private var expenseChange: Double? { SpendingAggregates.monthOverMonthChange(in: expenses) }
    private var topMerchants: [SpendingAggregates.MerchantTotal] { SpendingAggregates.topMerchants(in: periodExpenses, limit: 5) }

    private var recentExpenses: [Expense] {
        periodExpenses.sorted { $0.date > $1.date }.prefix(4).map { $0 }
    }

    private var categoryDonutSegments: [(start: CGFloat, end: CGFloat, color: Color)] {
        var cursor: CGFloat = 0
        return categoryBreakdown.enumerated().map { index, cat in
            let fraction = CGFloat(cat.percentage / 100.0)
            let seg = (start: cursor, end: min(1, cursor + fraction), color: Self.categoryPalette[index % Self.categoryPalette.count])
            cursor += fraction
            return seg
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.appBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 1. Top Header Bar — stays fixed while the rest of the screen scrolls beneath it.
                    headerBar
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 14)
                        .background(Color.appBackground)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 22) {
                            // 2. Total Expenses Overview Card
                            totalExpensesHeroCard

                            // 3. Action Shortcuts Row (5 Circle Action Buttons)
                            actionShortcutsRow

                            // 4. Recent Transactions Card Section
                            recentTransactionsSection

                            // 5. Expenses by Category Horizontal Section
                            expensesByCategorySection

                            // 6. Top Merchants Horizontal Section
                            topMerchantsSection
                        }
                        .padding(.horizontal, 16)
                    }
                    .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 96) }
                }
            }
            .sheet(item: $activeSheet) { type in
                switch type {
                case .insights:
                    FinancialInsightsView()
                case .categories:
                    ReportsView()
                case .recurring:
                    TrackerView()
                case .export:
                    ReportsView()
                }
            }
            .sheet(isPresented: $showSearchSheet) {
                RecentTransactionsView()
            }
            .sheet(isPresented: $showFilterSheet) {
                ReportsView()
            }
        }
    }

    // MARK: - 1. Top Header Bar
    private var headerBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Expenses")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 20/255, green: 70/255, blue: 40/255))

                Text("Track, manage and analyze your expenses")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 10) {
                // Search Button
                Button {
                    Haptics.light()
                    showSearchSheet = true
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color.appGreenDeep)
                        .frame(width: 40, height: 40)
                        .background(Color.appGreen.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                // Filter Button
                Button {
                    Haptics.light()
                    showFilterSheet = true
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color.appGreenDeep)
                        .frame(width: 40, height: 40)
                        .background(Color.appGreen.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 2. Total Expenses Overview Card
    private var totalExpensesHeroCard: some View {
        HStack(alignment: .center, spacing: 14) {
            // Left Details Column
            VStack(alignment: .leading, spacing: 8) {
                Text("Total Expenses")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)

                Text("₹\(Int(totalExpensesAmount).formatted())")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 20/255, green: 40/255, blue: 25/255))

                // Date Selector Dropdown Button
                Menu {
                    Picker("Period", selection: $selectedPeriod) {
                        ForEach(PeriodFilter.allCases) { Text($0.rawValue).tag($0) }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(selectedPeriod.rangeText)
                            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                // Month-over-Month Comparison Label
                if let expenseChange {
                    HStack(spacing: 4) {
                        Image(systemName: expenseChange <= 0 ? "arrow.down" : "arrow.up")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(expenseChange <= 0 ? Color.appGreen : Color.appExpenseRed)

                        Text("\(String(format: "%.1f", abs(expenseChange)))% \(expenseChange <= 0 ? "less" : "more") than last month")
                            .font(.system(size: 11.5, weight: .bold, design: .rounded))
                            .foregroundColor(expenseChange <= 0 ? Color.appGreen : Color.appExpenseRed)
                    }
                }
            }

            Spacer(minLength: 4)

            // Right Column: Donut Pie Chart + Center Text
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.15), lineWidth: 11)
                    .frame(width: 98, height: 98)

                ForEach(Array(categoryDonutSegments.enumerated()), id: \.offset) { _, seg in
                    Circle()
                        .trim(from: seg.start, to: seg.end)
                        .stroke(seg.color, lineWidth: 11)
                        .frame(width: 98, height: 98)
                }

                // Center Text inside Donut
                VStack(spacing: 1) {
                    Text("Top Category")
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                    Text(topCategory?.name ?? "No spending")
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if let topCategory {
                        Text("\(String(format: "%.1f", topCategory.percentage))%")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(Color.appGreen)
                    }
                }
                .frame(width: 74)
            }
        }
        .padding(18)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    // MARK: - 3. Action Shortcuts Row (5 Circle Buttons)
    private var actionShortcutsRow: some View {
        HStack(spacing: 0) {
            shortcutButton(
                icon: "chart.line.uptrend.xyaxis",
                iconColor: Color.appGreen,
                bgColor: Color(red: 232/255, green: 247/255, blue: 238/255),
                title: "View Insights"
            ) {
                activeSheet = .insights
            }

            // Pushes rather than presenting a sheet — this is the entry point the hero
            // card's donut used to own before it was made non-interactive.
            NavigationLink(destination: ReportsView().hidesTabBarOnPush()) {
                shortcutContent(
                    icon: "doc.text",
                    iconColor: Color(red: 249/255, green: 115/255, blue: 22/255),
                    bgColor: Color(red: 254/255, green: 243/255, blue: 235/255),
                    title: "View Report"
                )
            }
            .buttonStyle(.plain)

            shortcutButton(
                icon: "tag",
                iconColor: Color(red: 147/255, green: 51/255, blue: 234/255),
                bgColor: Color(red: 243/255, green: 232/255, blue: 255/255),
                title: "Categories"
            ) {
                activeSheet = .categories
            }

            shortcutButton(
                icon: "arrow.triangle.2.circlepath",
                iconColor: Color(red: 37/255, green: 99/255, blue: 235/255),
                bgColor: Color(red: 239/255, green: 246/255, blue: 255/255),
                title: "Recurring"
            ) {
                activeSheet = .recurring
            }

            shortcutButton(
                icon: "square.and.arrow.down",
                iconColor: Color.appGreen,
                bgColor: Color(red: 232/255, green: 247/255, blue: 238/255),
                title: "Export"
            ) {
                activeSheet = .export
            }
        }
    }

    @ViewBuilder
    private func shortcutButton(icon: String, iconColor: Color, bgColor: Color, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            shortcutContent(icon: icon, iconColor: iconColor, bgColor: bgColor, title: title)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func shortcutContent(icon: String, iconColor: Color, bgColor: Color, title: String) -> some View {
        VStack(spacing: 8) {
            Circle()
                .fill(bgColor)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(iconColor)
                )

            Text(title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 4. Recent Transactions Card Section
    private var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Transactions")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Spacer()

                NavigationLink(destination: RecentTransactionsView().hidesTabBarOnPush()) {
                    HStack(spacing: 2) {
                        Text("View All")
                            .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(.appGreen)
                }
            }

            if recentExpenses.isEmpty {
                Text("No transactions yet")
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color.appSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recentExpenses.enumerated()), id: \.element.id) { index, expense in
                        transactionRow(expense)
                        if index != recentExpenses.count - 1 {
                            Divider().padding(.leading, 64)
                        }
                    }
                }
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
            }
        }
    }

    @ViewBuilder
    private func transactionRow(_ expense: Expense) -> some View {
        let merchantName = expense.name.isEmpty ? expense.type : expense.name
        let categoryAndAccount = expense.account.isEmpty ? expense.type : "\(expense.type)  •  \(expense.account)"

        NavigationLink(destination: TransactionDetailView(item: .expense(expense)).hidesTabBarOnPush()) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.appExpenseRed.opacity(0.10))
                        .frame(width: 42, height: 42)
                    Text(expense.emoji.isEmpty ? String(merchantName.prefix(2)).uppercased() : expense.emoji)
                        .font(.system(size: 16))
                }

                // Middle Info
                VStack(alignment: .leading, spacing: 3) {
                    Text(merchantName)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Text(categoryAndAccount)
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)

                    Text(expense.date.formatted(.dateTime.month(.abbreviated).day().year().hour().minute()))
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.8))
                }

                Spacer()

                // Right Amount & Chevron
                HStack(spacing: 4) {
                    Text(AppFormatter.signedCurrency(expense.price, isIncome: false))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 5. Expenses by Category Horizontal Section
    private var expensesByCategorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Expenses by Category")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Spacer()

                NavigationLink(destination: ReportsView().hidesTabBarOnPush()) {
                    HStack(spacing: 2) {
                        Text("View All")
                            .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(.appGreen)
                }
            }

            if categoryBreakdown.isEmpty {
                Text("No spending yet")
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Array(categoryBreakdown.prefix(6).enumerated()), id: \.offset) { index, cat in
                                let color = Self.categoryPalette[index % Self.categoryPalette.count]
                                categoryCard(
                                    icon: "tag.fill",
                                    iconColor: color,
                                    bgColor: color.opacity(0.12),
                                    title: cat.name,
                                    amount: AppFormatter.currencyRounded(cat.amount),
                                    percent: "\(String(format: "%.1f", cat.percentage))%"
                                )
                            }
                        }
                        .padding(.vertical, 2)
                    }

                    // Highlights how much of total spend the top category alone accounts for.
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.gray.opacity(0.15))
                            .frame(height: 3)
                        GeometryReader { geo in
                            Capsule()
                                .fill(Color.appGreen)
                                .frame(width: geo.size.width * CGFloat((topCategory?.percentage ?? 0) / 100), height: 3)
                        }
                        .frame(height: 3)
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
    }

    @ViewBuilder
    private func categoryCard(icon: String, iconColor: Color, bgColor: Color, title: String, amount: String, percent: String) -> some View {
        NavigationLink(destination: ReportsView().hidesTabBarOnPush()) {
            VStack(spacing: 6) {
                Circle()
                    .fill(bgColor)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(iconColor)
                    )

                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(amount)
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text(percent)
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .foregroundColor(Color.appGreen)
            }
            .frame(width: 96, height: 122)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 6. Top Merchants Horizontal Section
    private var topMerchantsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Top Merchants")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Spacer()

                NavigationLink(destination: RecentTransactionsView().hidesTabBarOnPush()) {
                    HStack(spacing: 2) {
                        Text("View All")
                            .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(.appGreen)
                }
            }

            if topMerchants.isEmpty {
                Text("No merchants yet")
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(topMerchants.enumerated()), id: \.offset) { index, merchant in
                            merchantCard(
                                name: merchant.name,
                                amount: AppFormatter.currencyRounded(merchant.amount),
                                percent: "\(String(format: "%.1f", merchant.percentage))%",
                                color: Self.categoryPalette[index % Self.categoryPalette.count]
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    @ViewBuilder
    private func merchantCard(name: String, amount: String, percent: String, color: Color) -> some View {
        NavigationLink(destination: RecentTransactionsView().hidesTabBarOnPush()) {
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(color.opacity(0.14))
                        .frame(width: 24, height: 24)
                        .overlay(
                            Text(String(name.prefix(1)).uppercased())
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .foregroundColor(color)
                        )

                    Text(name)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Text(amount)
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text(percent)
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .foregroundColor(Color.appGreen)
            }
            .frame(width: 104, height: 96)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ExpensesView()
}

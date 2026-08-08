import SwiftUI
import SwiftData

struct TrackerView: View {
    @Environment(\.modelContext) private var context
    @Query private var trackerRecords: [TrackerRecord]
    @Query private var expenses: [Expense]

    // Not yet wired to what renders below — every section always shows its full real data
    // regardless of which tab is selected. Filtering each section to its matching tab is a
    // larger change (four separate tab-scoped lists) than this pass's scope.
    @State private var selectedTab: TrackerTab = .overview
    @State private var selectedGoalForFunds: TrackerRecord?

    enum TrackerTab: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case budgets = "Budgets"
        case subscriptions = "Subscriptions"
        case emis = "EMIs"
        case goals = "Goals"

        var id: String { rawValue }
    }

    // MARK: - Real data

    private var budgetTrackers: [TrackerRecord] { trackerRecords.filter { $0.type == "budget" } }
    private var goalTrackers: [TrackerRecord] { trackerRecords.filter { $0.type == "goal" } }

    private var upcomingTrackers: [TrackerRecord] {
        Array(trackerRecords.filter { !$0.isPaid }.sorted { $0.dueDate < $1.dueDate }.prefix(4))
    }

    private var currentMonthRangeText: String {
        Date().formatted(.dateTime.month(.wide).year())
    }

    /// Sum of this category's expenses in the given month — how "spent" is computed against
    /// a budget tracker's `category`.
    private func spent(for category: String, in month: Date = Date()) -> Double {
        guard !category.isEmpty else { return 0 }
        let cal = Calendar.current
        return expenses
            .filter { $0.type == category && cal.isDate($0.date, equalTo: month, toGranularity: .month) }
            .reduce(0) { $0 + $1.price }
    }

    private var monthTotalExpenses: Double {
        let cal = Calendar.current
        return expenses.filter { cal.isDate($0.date, equalTo: Date(), toGranularity: .month) }.reduce(0) { $0 + $1.price }
    }

    private var totalBudgeted: Double { budgetTrackers.reduce(0) { $0 + $1.amount } }
    private var totalBudgetSpent: Double { budgetTrackers.reduce(0) { $0 + spent(for: $1.category) } }

    private var budgetProgressRatio: Double {
        guard totalBudgeted > 0 else { return 0 }
        return min(1, totalBudgetSpent / totalBudgeted)
    }

    private var daysElapsedInMonth: Int { Calendar.current.component(.day, from: Date()) }
    private var daysInCurrentMonth: Int { Calendar.current.range(of: .day, in: .month, for: Date())?.count ?? 30 }

    private var dailyAverageSpend: Double {
        daysElapsedInMonth > 0 ? monthTotalExpenses / Double(daysElapsedInMonth) : 0
    }

    private var dailyBudgetTarget: Double {
        totalBudgeted > 0 ? totalBudgeted / Double(daysInCurrentMonth) : 0
    }

    private func dueText(for date: Date) -> String {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: date)).day ?? 0
        if days < 0 { return "Overdue" }
        if days == 0 { return "Today" }
        if days == 1 { return "Tomorrow" }
        return "In \(days) days"
    }

    private let budgetPalette: [Color] = [
        .appGreen,
        Color(red: 59/255, green: 130/255, blue: 246/255),
        Color(red: 147/255, green: 51/255, blue: 234/255),
        Color(red: 249/255, green: 115/255, blue: 22/255),
        Color(red: 239/255, green: 68/255, blue: 68/255),
        Color.gray.opacity(0.6)
    ]

    private let goalPalette: [(color: Color, bg: Color)] = [
        (.appGreen, Color(red: 232/255, green: 247/255, blue: 238/255)),
        (Color(red: 249/255, green: 115/255, blue: 22/255), Color(red: 254/255, green: 243/255, blue: 235/255)),
        (Color(red: 147/255, green: 51/255, blue: 234/255), Color(red: 243/255, green: 232/255, blue: 255/255))
    ]

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
                        VStack(spacing: 20) {
                            // 2. Segmented Pill Picker Tabs
                            segmentedTabPicker

                            // 3. Monthly Progress Card
                            monthlyProgressCard

                            // 4. Upcoming Payments Section
                            upcomingPaymentsSection

                            // 5. Budget Overview Section
                            budgetOverviewSection

                            // 6. Goal Progress Section
                            goalProgressSection
                        }
                        .padding(.horizontal, 16)
                    }
                    .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 96) }
                }
            }
            .sheet(item: $selectedGoalForFunds) { goal in
                AddGoalFundsSheet(goal: goal)
            }
        }
    }

    // MARK: - 1. Top Header Bar
    private var headerBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Tracker")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(Color.appGreenDeep)

                Text("Stay on top of your finances")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 10) {
                // Add Tracker Button — pushed via NavigationLink rather than opened as a
                // modal cover, matching how Home's own "Add Tracker" quick-action card reaches
                // this same screen. A fullScreenCover here read as a different, disconnected
                // flow next to every other way into this screen.
                NavigationLink(destination: AddTrackerView().hidesTabBarOnPush()) {
                    Image(systemName: AppIcon.Action.add)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color.appGreenDeep)
                        .frame(width: 40, height: 40)
                        .background(Color.appGreen.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded { Haptics.light() })

                // Notification Bell with Red Count Badge
                NavigationLink(destination: NotificationView().hidesTabBarOnPush()) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color.appGreenDeep)
                            .frame(width: 40, height: 40)
                            .background(Color.appGreen.opacity(0.12))
                            .clipShape(Circle())

                        ZStack {
                            Circle()
                                .fill(Color.appExpenseRed)
                                .frame(width: 16, height: 16)
                            Text("3")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .offset(x: 2, y: -2)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 2. Segmented Pill Picker Tabs
    private var segmentedTabPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(TrackerTab.allCases) { tab in
                    Button {
                        Haptics.light()
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            selectedTab = tab
                        }
                    } label: {
                        Text(tab.rawValue)
                            .font(.system(size: 13, weight: selectedTab == tab ? .bold : .medium, design: .rounded))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .foregroundColor(selectedTab == tab ? Color(red: 20/255, green: 90/255, blue: 50/255) : .secondary)
                            .background(
                                Capsule()
                                    .fill(selectedTab == tab ? Color(red: 228/255, green: 247/255, blue: 236/255) : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(
                Capsule()
                    .fill(Color.appSurface)
                    .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
            )
        }
    }

    // MARK: - 3. Monthly Progress Card
    private var monthlyProgressCard: some View {
        VStack(spacing: 16) {
            // Header Row
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Monthly Progress")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Text(currentMonthRangeText)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                }

                Spacer()

                NavigationLink(destination: BudgetGoalsView().hidesTabBarOnPush()) {
                    Text("Edit Budget")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.appGreen)
                }
            }

            // Metrics Row (3 columns)
            HStack(spacing: 0) {
                // Column 1: Spent
                VStack(alignment: .leading, spacing: 3) {
                    Text("Spent")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                    Text(AppFormatter.currencyRounded(totalBudgeted > 0 ? totalBudgetSpent : monthTotalExpenses))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text(totalBudgeted > 0 ? "\(Int(budgetProgressRatio * 100))% of \(AppFormatter.currencyRounded(totalBudgeted))" : "No budget set")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Rectangle()
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 1, height: 42)

                // Column 2: Remaining
                VStack(alignment: .leading, spacing: 3) {
                    Text("Remaining")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                    Text(AppFormatter.currencyRounded(max(0, totalBudgeted - totalBudgetSpent)))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 14)

                Rectangle()
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 1, height: 42)

                // Column 3: Daily Average
                VStack(alignment: .leading, spacing: 3) {
                    Text("Daily Average")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                    Text(AppFormatter.currencyRounded(dailyAverageSpend))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    if totalBudgeted > 0 {
                        Text("of \(AppFormatter.currencyRounded(dailyBudgetTarget))")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 14)
            }

            // Green Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 8)
                    Capsule()
                        .fill(Color.appGreen)
                        .frame(width: geo.size.width * budgetProgressRatio, height: 8)
                }
            }
            .frame(height: 8)

            // Insight Callout Banner
            if totalBudgeted > 0 {
                let remaining = totalBudgeted - totalBudgetSpent
                NavigationLink(destination: FinancialInsightsView().hidesTabBarOnPush()) {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.appGreen.opacity(0.16))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: remaining >= 0 ? "chart.line.uptrend.xyaxis" : "exclamationmark.triangle.fill")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.appGreen)
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(remaining >= 0 ? "You're on track!" : "Over budget")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            Text(remaining >= 0
                                ? "You're spending \(AppFormatter.currencyRounded(remaining)) less than your planned budget."
                                : "You've spent \(AppFormatter.currencyRounded(abs(remaining))) more than your planned budget.")
                                .font(.system(size: 11.5, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                    .padding(12)
                    .background(Color(red: 240/255, green: 250/255, blue: 244/255))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                NavigationLink(destination: AddTrackerView(initialKind: .budget).hidesTabBarOnPush()) {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.appGreen.opacity(0.16))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: "target")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.appGreen)
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Set a budget to track your progress")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            Text("Add a category budget to see how you're doing this month.")
                                .font(.system(size: 11.5, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                    .padding(12)
                    .background(Color(red: 240/255, green: 250/255, blue: 244/255))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    // MARK: - 4. Upcoming Payments Section
    private var upcomingPaymentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Upcoming Payments")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Spacer()

                NavigationLink(destination: UpcomingPaymentsView().hidesTabBarOnPush()) {
                    Text("View All")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.appGreen)
                }
            }

            if upcomingTrackers.isEmpty {
                Text("No upcoming payments")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.appSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(upcomingTrackers.enumerated()), id: \.element.id) { index, record in
                        paymentRow(record)
                        if index < upcomingTrackers.count - 1 {
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
    private func trackerAvatar(_ record: TrackerRecord) -> some View {
        let (icon, tint): (String, Color) = {
            switch record.type {
            case "subscription": return ("repeat.circle.fill", .appIndigo)
            case "emi": return ("building.2.fill", .appWarningAmber)
            case "goal": return ("target", .appGreen)
            case "budget": return ("chart.pie.fill", .appGreen)
            default: return ("bell.fill", .appGreen)
            }
        }()
        Circle()
            .fill(tint.opacity(0.14))
            .frame(width: 42, height: 42)
            .overlay(
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(tint)
            )
    }

    @ViewBuilder
    private func paymentRow(_ record: TrackerRecord) -> some View {
        NavigationLink(destination: UpcomingPaymentsView().hidesTabBarOnPush()) {
            HStack(spacing: 12) {
                trackerAvatar(record)

                VStack(alignment: .leading, spacing: 3) {
                    Text(record.name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Text("\(record.dueDate.formatted(.dateTime.month(.abbreviated).day().year()))  •  \(record.subType.capitalized)")
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }

                Spacer()

                HStack(spacing: 6) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(AppFormatter.currency(record.amount))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)

                        Text(dueText(for: record.dueDate))
                            .font(.system(size: 11.5, weight: .bold, design: .rounded))
                            .foregroundColor(.appGreen)
                    }

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

    // MARK: - 5. Budget Overview Section
    private var budgetOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Budget Overview")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Spacer()

                NavigationLink(destination: BudgetGoalsView().hidesTabBarOnPush()) {
                    Text("View All")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.appGreen)
                }
            }

            if budgetTrackers.isEmpty {
                VStack(spacing: 10) {
                    Text("No budgets set yet")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                    NavigationLink(destination: AddTrackerView(initialKind: .budget).hidesTabBarOnPush()) {
                        Text("Add Budget")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.appGreen)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
            } else {
                // Donut sits above the breakdown rather than beside it: side-by-side left the
                // rows ~185pt for ~245pt of content, so every amount and percent wrapped
                // vertically one character at a time.
                VStack(spacing: 18) {
                    // Multi-color Donut Ring — each budget's share of what's actually been
                    // spent so far, not of the budget limit (that ratio drives the centre %).
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.15), lineWidth: 14)
                            .frame(width: 110, height: 110)

                        ForEach(Array(donutSegments.enumerated()), id: \.offset) { _, segment in
                            Circle()
                                .trim(from: segment.start, to: segment.end)
                                .stroke(segment.color, lineWidth: 14)
                                .frame(width: 110, height: 110)
                        }

                        VStack(spacing: 1) {
                            Text("\(Int(budgetProgressRatio * 100))%")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)

                            Text("of budget\nused")
                                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }

                    // Breakdown List
                    VStack(spacing: 11) {
                        ForEach(Array(budgetTrackers.enumerated()), id: \.element.id) { index, tracker in
                            let categorySpent = spent(for: tracker.category)
                            let ratio = tracker.amount > 0 ? min(1, categorySpent / tracker.amount) : 0
                            budgetRow(
                                color: budgetPalette[index % budgetPalette.count],
                                category: tracker.category.isEmpty ? tracker.name : tracker.category,
                                amount: AppFormatter.currencyRounded(categorySpent),
                                percent: "\(Int(ratio * 100))%",
                                ratio: ratio
                            )
                        }
                    }
                }
                .padding(16)
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
            }
        }
    }

    /// Each budget's slice of total spending so far, as trim ranges for the donut ring.
    private var donutSegments: [(start: CGFloat, end: CGFloat, color: Color)] {
        let total = budgetTrackers.reduce(0.0) { $0 + max(0, spent(for: $1.category)) }
        guard total > 0 else { return [] }
        var cursor: CGFloat = 0
        var result: [(CGFloat, CGFloat, Color)] = []
        for (index, tracker) in budgetTrackers.enumerated() {
            let value = max(0, spent(for: tracker.category))
            guard value > 0 else { continue }
            let fraction = CGFloat(value / total)
            let start = cursor
            let end = min(1, cursor + fraction)
            result.append((start, end, budgetPalette[index % budgetPalette.count]))
            cursor = end
        }
        return result
    }

    @ViewBuilder
    private func budgetRow(color: Color, category: String, amount: String, percent: String, ratio: CGFloat) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)

            Text(category)
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .layoutPriority(1)

            Spacer(minLength: 6)

            Text(amount)
                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
                .fixedSize()

            Text(percent)
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .fixedSize()
                .frame(width: 34, alignment: .trailing)

            // Mini Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 5)
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * ratio, height: 5)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(width: 56, height: 5)
        }
    }

    // MARK: - 6. Goal Progress Section
    private var goalProgressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Goal Progress")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Spacer()

                NavigationLink(destination: BudgetGoalsView().hidesTabBarOnPush()) {
                    Text("View All")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.appGreen)
                }
            }

            if goalTrackers.isEmpty {
                HStack {
                    Text("No goals yet")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                    Spacer()
                    NavigationLink(destination: AddTrackerView(initialKind: .goal).hidesTabBarOnPush()) {
                        Text("Add Goal")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.appGreen)
                    }
                }
                .padding(16)
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Color.black.opacity(0.04), radius: 5, x: 0, y: 2)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(goalTrackers.enumerated()), id: \.element.id) { index, tracker in
                            goalCard(tracker, colorIndex: index)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    @ViewBuilder
    private func goalCard(_ tracker: TrackerRecord, colorIndex: Int) -> some View {
        let palette = goalPalette[colorIndex % goalPalette.count]
        let ratio = tracker.amount > 0 ? min(1, tracker.currentAmount / tracker.amount) : 0

        Button {
            Haptics.light()
            selectedGoalForFunds = tracker
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(palette.bg)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: tracker.logoUrl.isEmpty ? "target" : tracker.logoUrl)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(palette.color)
                        )

                    VStack(alignment: .leading, spacing: 1) {
                        Text(tracker.name)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Text("\(AppFormatter.currencyRounded(tracker.currentAmount)) of \(AppFormatter.currencyRounded(tracker.amount))")
                            .font(.system(size: 10.5, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }

                VStack(alignment: .trailing, spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.gray.opacity(0.15))
                                .frame(height: 5)
                            Capsule()
                                .fill(palette.color)
                                .frame(width: geo.size.width * ratio, height: 5)
                        }
                    }
                    .frame(height: 5)

                    Text("\(Int(ratio * 100))%")
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .foregroundColor(palette.color)
                }
            }
            .padding(12)
            .frame(width: 165, height: 98)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

}

#Preview {
    TrackerView()
}

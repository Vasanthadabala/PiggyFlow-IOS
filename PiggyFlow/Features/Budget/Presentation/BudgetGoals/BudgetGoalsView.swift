import SwiftUI
import SwiftData

/// One category budget for the period being viewed.
struct BudgetGoalItem: Identifiable, Hashable {
    let id: String
    var name: String
    /// "Needs" or "Wants" — the split people actually plan against.
    var group: String
    var spent: Double
    var budget: Double
    var icon: String
    var tint: Color

    init(
        id: String = UUID().uuidString,
        name: String,
        group: String,
        spent: Double,
        budget: Double,
        icon: String,
        tint: Color
    ) {
        self.id = id
        self.name = name
        self.group = group
        self.spent = spent
        self.budget = budget
        self.icon = icon
        self.tint = tint
    }

    var ratio: Double { budget > 0 ? spent / budget : 0 }

    /// Negative once the budget is blown — the row shows that as "Over by".
    var remaining: Double { budget - spent }

    var status: BudgetGoalStatus {
        if ratio > 1 { return .overBudget }
        if ratio == 1 { return .completed }
        if ratio >= 0.8 { return .atRisk }
        return .onTrack
    }
}

/// Where a budget stands. Ordering doubles as the "Sort: Status" order — the budgets that
/// need attention sort to the top, which is the only reason to open this screen in a hurry.
enum BudgetGoalStatus: Int, CaseIterable {
    case overBudget
    case atRisk
    case completed
    case onTrack

    var label: String {
        switch self {
        case .overBudget: return "Over Budget"
        case .atRisk:     return "At Risk"
        case .completed:  return "Completed"
        case .onTrack:    return "On Track"
        }
    }

    var tint: Color {
        switch self {
        case .overBudget: return .appExpenseRed
        case .atRisk:     return .appWarningAmber
        case .completed:  return .appGreen
        case .onTrack:    return .appGreen
        }
    }
}

/// Monthly category budgets, their progress, and how much is left.
struct BudgetGoalsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var trackerRecords: [TrackerRecord]
    @Query private var expenses: [Expense]

    enum SortOrder: String, CaseIterable, Identifiable {
        case status = "Status"
        case name = "Name"
        case spent = "Spent"
        case remaining = "Remaining"

        var id: String { rawValue }
    }

    /// Filter applied by tapping the On Track / At Risk summary cards, or the filter menu.
    enum GoalFilter: Hashable {
        case all
        case status(BudgetGoalStatus)

        var label: String {
            switch self {
            case .all:                 return "All"
            case .status(let status):  return status.label
            }
        }
    }

    @State private var sortOrder: SortOrder = .status
    @State private var filter: GoalFilter = .all
    @State private var showAddTracker = false
    @State private var monthLabel = Date().formatted(.dateTime.month(.wide).year())

    // MARK: - Real data

    private var budgetTrackers: [TrackerRecord] { trackerRecords.filter { $0.type == "budget" } }

    private func spent(for category: String, in month: Date = Date()) -> Double {
        guard !category.isEmpty else { return 0 }
        let cal = Calendar.current
        return expenses
            .filter { $0.type == category && cal.isDate($0.date, equalTo: month, toGranularity: .month) }
            .reduce(0) { $0 + $1.price }
    }

    /// Palette cycled by index — `TrackerRecord` has no colour of its own to persist, same
    /// approach `StatsView`'s category breakdown already uses.
    private let goalPalette: [Color] = [
        .appGreen,
        Color(red: 249/255, green: 115/255, blue: 22/255),
        Color(red: 147/255, green: 51/255, blue: 234/255),
        Color(red: 236/255, green: 72/255, blue: 153/255),
        Color(red: 59/255, green: 130/255, blue: 246/255),
        Color(red: 245/255, green: 197/255, blue: 66/255),
        .appTeal
    ]

    /// Derived fresh from `@Query`'d trackers/expenses every render — no manual refresh needed,
    /// and the budget created by this screen's own "Add Budget" flow shows up immediately.
    private var goals: [BudgetGoalItem] {
        budgetTrackers.enumerated().map { index, tracker in
            BudgetGoalItem(
                id: tracker.id,
                name: tracker.category.isEmpty ? tracker.name : tracker.category,
                group: tracker.subType.capitalized,
                spent: spent(for: tracker.category),
                budget: tracker.amount,
                icon: tracker.logoUrl.isEmpty ? "target" : tracker.logoUrl,
                tint: goalPalette[index % goalPalette.count]
            )
        }
    }

    // MARK: - Derived totals

    private var totalBudget: Double { goals.reduce(0) { $0 + $1.budget } }
    private var totalSpent: Double { goals.reduce(0) { $0 + $1.spent } }
    private var totalRemaining: Double { totalBudget - totalSpent }
    private var spentRatio: Double { totalBudget > 0 ? totalSpent / totalBudget : 0 }

    private var onTrackCount: Int { goals.filter { $0.status == .onTrack }.count }
    private var atRiskCount: Int { goals.filter { $0.status == .atRisk || $0.status == .overBudget }.count }

    private var visibleGoals: [BudgetGoalItem] {
        let filtered: [BudgetGoalItem]
        switch filter {
        case .all:
            filtered = goals
        case .status(.atRisk):
            // The At Risk card counts anything past 80%, over-budget included — filtering to
            // strictly "at risk" would show fewer rows than the card's own number.
            filtered = goals.filter { $0.status == .atRisk || $0.status == .overBudget }
        case .status(let status):
            filtered = goals.filter { $0.status == status }
        }

        switch sortOrder {
        case .status:    return filtered.sorted { ($0.status.rawValue, -$0.ratio) < ($1.status.rawValue, -$1.ratio) }
        case .name:      return filtered.sorted { $0.name < $1.name }
        case .spent:     return filtered.sorted { $0.ratio > $1.ratio }
        case .remaining: return filtered.sorted { $0.remaining < $1.remaining }
        }
    }

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        overviewCard

                        statusCards

                        goalsSection

                        insightsBanner
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                // No tab-bar clearance: every entry point pushes this screen with
                // `hidesTabBarOnPush()`, so the old 96pt inset was just an empty band
                // under the insights banner.
            }
        }
        .navigationBarHidden(true)
        // Pushed onto this screen's own ambient NavigationStack rather than covered from the
        // bottom as a modal — this screen is itself always reached that way (every caller
        // pushes it with `hidesTabBarOnPush()`), so "Add Budget" going deeper should feel like
        // the same kind of navigation, not a sheet stacked on top of a pushed screen.
        .navigationDestination(isPresented: $showAddTracker) {
            // Locked to Budget: this screen is budgets only, so the Goal/Subscription/EMI
            // tabs would just be a way to leave it by accident.
            // `.hidesTabBarOnPush()` again here, not just on this screen — a pushed screen's
            // own `onDisappear` fires as soon as it's covered by the next push, which would
            // otherwise flip the tab bar back on behind this one.
            AddTrackerView(initialKind: .budget, lockedToInitialKind: true)
                .hidesTabBarOnPush()
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        ScreenHeader(
            title: "Budget",
            subtitle: "Set monthly budgets and stay on track",
            onBack: { dismiss() }
        ) {
            ScreenHeaderAction(icon: AppIcon.Action.addCircle, title: "Add Budget") {
                showAddTracker = true
            }
        }
    }

    // MARK: - Overview

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Menu {
                ForEach(monthOptions, id: \.self) { option in
                    Button(option) {
                        monthLabel = option
                        Haptics.light()
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Text("\(monthLabel) Overview")
                        .font(.system(size: 15.5, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Image(systemName: AppIcon.Nav.expand)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 0) {
                overviewColumn(
                    label: "Total Budget",
                    value: AppFormatter.currencyRounded(totalBudget),
                    caption: "across \(goals.count) goals"
                )

                columnDivider

                overviewColumn(
                    label: "Total Spent",
                    value: AppFormatter.currencyRounded(totalSpent),
                    caption: "\(percentText(spentRatio)) of budget"
                )
                .padding(.leading, 12)

                columnDivider

                overviewColumn(
                    label: "Remaining",
                    value: AppFormatter.currencyRounded(abs(totalRemaining)),
                    caption: totalRemaining < 0 ? "over budget" : "\(percentText(1 - spentRatio)) left",
                    valueColor: totalRemaining < 0 ? .appExpenseRed : .appGreen
                )
                .padding(.leading, 12)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 8)

                    Capsule()
                        .fill(totalRemaining < 0 ? Color.appExpenseRed : Color.appGreen)
                        .frame(width: geo.size.width * min(spentRatio, 1), height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding(16)
        .background(Color(red: 240/255, green: 250/255, blue: 244/255))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var columnDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(width: 1, height: 44)
    }

    @ViewBuilder
    private func overviewColumn(label: String, value: String, caption: String, valueColor: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 11.5, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)

            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            Text(caption)
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Status cards

    private var statusCards: some View {
        HStack(spacing: 12) {
            statusCard(
                icon: "target",
                tint: .appGreen,
                title: "On Track",
                count: onTrackCount,
                caption: "Within budget",
                filterValue: .status(.onTrack)
            )

            statusCard(
                icon: AppIcon.Status.warning,
                tint: .appWarningAmber,
                title: "At Risk",
                count: atRiskCount,
                caption: "Above 80%",
                filterValue: .status(.atRisk)
            )
        }
    }

    @ViewBuilder
    private func statusCard(
        icon: String,
        tint: Color,
        title: String,
        count: Int,
        caption: String,
        filterValue: GoalFilter
    ) -> some View {
        let isActive = filter == filterValue

        Button {
            Haptics.light()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                filter = isActive ? .all : filterValue
            }
        } label: {
            HStack(spacing: 12) {
                TintedIconCircle(color: tint, size: 44, cornerRadius: 14) {
                    Image(systemName: icon)
                        .font(.system(size: 19, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12.5, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)

                    Text("\(count)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Text(caption)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: 2)

                Image(systemName: isActive ? AppIcon.Nav.close : AppIcon.Nav.forward)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(tint, lineWidth: 1.5)
                    .opacity(isActive ? 1 : 0)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Goals list

    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text("Budget")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Spacer(minLength: 4)

                Menu {
                    ForEach(SortOrder.allCases) { order in
                        Button {
                            sortOrder = order
                            Haptics.light()
                        } label: {
                            Label(order.rawValue, systemImage: sortOrder == order ? "checkmark" : "")
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text("Sort: \(sortOrder.rawValue)")
                            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                        Image(systemName: AppIcon.Nav.expand)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .liftedControl(cornerRadius: 14)
                }
                .buttonStyle(.plain)

                Menu {
                    Button("All Goals") { filter = .all }
                    Divider()
                    ForEach(BudgetGoalStatus.allCases, id: \.rawValue) { status in
                        Button(status.label) { filter = .status(status) }
                    }
                } label: {
                    Image(systemName: AppIcon.Nav.filter)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(filter == .all ? .primary : .appGreen)
                        .frame(width: 40, height: 38)
                        .liftedControl(cornerRadius: 14)
                }
                .buttonStyle(.plain)
            }

            if filter != .all {
                activeFilterChip
            }

            if visibleGoals.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(visibleGoals.enumerated()), id: \.element.id) { index, goal in
                        goalRow(goal)

                        if index < visibleGoals.count - 1 {
                            RowDivider(leadingInset: 14)
                        }
                    }
                }
                .groupedCard()
            }
        }
    }

    private var activeFilterChip: some View {
        Button {
            Haptics.light()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) { filter = .all }
        } label: {
            HStack(spacing: 6) {
                Text(filter.label)
                Image(systemName: AppIcon.Nav.close)
                    .font(.system(size: 9, weight: .bold))
            }
            .tintedPill(color: .appGreen)
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 26, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.5))

            Text("No budgets match this filter")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .groupedCard()
    }

    @ViewBuilder
    private func goalRow(_ goal: BudgetGoalItem) -> some View {
        // This screen's own onDisappear fires the moment it's covered by this push (see the
        // Add Budget push above), which would otherwise flip the tab bar back on behind it.
        NavigationLink(destination: BudgetGoalDetailPlaceholder(goal: goal).hidesTabBarOnPush()) {
            HStack(spacing: 12) {
                TintedIconCircle(color: goal.tint, size: 44, cornerRadius: 14) {
                    Image(systemName: goal.icon)
                        .font(.system(size: 18, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(goal.name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text(goal.group)
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.primary.opacity(0.08))
                                    .frame(height: 5)

                                Capsule()
                                    .fill(goal.status.tint)
                                    .frame(width: geo.size.width * min(goal.ratio, 1), height: 5)
                            }
                            .frame(maxHeight: .infinity, alignment: .center)
                        }
                        .frame(height: 5)

                        Text(percentText(goal.ratio))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(goal.status.tint)
                            .frame(width: 42, alignment: .trailing)
                    }

                    Text("\(AppFormatter.currencyRounded(goal.spent)) of \(AppFormatter.currencyRounded(goal.budget))")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                VStack(alignment: .trailing, spacing: 4) {
                    Text(AppFormatter.currencyRounded(abs(goal.remaining)))
                        .font(.system(size: 14.5, weight: .bold, design: .rounded))
                        .foregroundColor(goal.remaining < 0 ? .appExpenseRed : goal.status.tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text(goal.remaining < 0 ? "Over by" : "Remaining")
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)

                    Text(goal.status.label)
                        .tintedPill(color: goal.status.tint)
                }
                .frame(width: 96, alignment: .trailing)

                Image(systemName: AppIcon.Nav.forward)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .flatRow(vertical: 12, horizontal: 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Insights banner

    private var insightsBanner: some View {
        HStack(spacing: 14) {
            TintedIconCircle(color: .appGreen, size: 46, cornerRadius: 14) {
                Image(systemName: AppIcon.Chart.insight)
                    .font(.system(size: 19, weight: .semibold))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Stay in control of your spending")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Review your budgets regularly and adjust to reach your financial goals.")
                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)

            NavigationLink(destination: FinancialInsightsView().hidesTabBarOnPush()) {
                HStack(spacing: 5) {
                    Image(systemName: AppIcon.Chart.bar)
                        .font(.system(size: 11, weight: .bold))
                    Text("Insights")
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                }
                .foregroundColor(.appGreen)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Color.appSurface)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color(red: 240/255, green: 250/255, blue: 244/255))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Helpers

    private func percentText(_ ratio: Double) -> String {
        let value = max(ratio, 0) * 100
        // Whole percents read cleaner in the dense row; the header keeps one decimal because
        // "61.7% of budget" is a figure people check against their own arithmetic.
        return value >= 100 || value == value.rounded() ? "\(Int(value.rounded()))%" : String(format: "%.1f%%", value)
    }

    private var monthOptions: [String] {
        let calendar = Calendar.current
        return (0..<6).compactMap { offset in
            calendar.date(byAdding: .month, value: -offset, to: Date())?
                .formatted(.dateTime.month(.wide).year())
        }
    }

}

/// Detail screen for a single budget goal isn't built yet — this keeps the row tappable
/// without pretending there's more to show.
private struct BudgetGoalDetailPlaceholder: View {
    let goal: BudgetGoalItem

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 14) {
                TintedIconCircle(color: goal.tint, size: 66, cornerRadius: 20) {
                    Image(systemName: goal.icon)
                        .font(.system(size: 28, weight: .semibold))
                }

                Text(goal.name)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text("\(AppFormatter.currencyRounded(goal.spent)) spent of \(AppFormatter.currencyRounded(goal.budget))")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)

                Text(goal.status.label)
                    .tintedPill(color: goal.status.tint)
            }
            .padding(24)
        }
        .navigationTitle("Budget")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        BudgetGoalsView()
    }
}

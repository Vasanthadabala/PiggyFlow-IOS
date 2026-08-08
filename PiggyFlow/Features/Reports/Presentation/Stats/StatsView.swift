import SwiftUI
import Charts
import SwiftData

enum StatsFlow: String, CaseIterable, Identifiable {
    case expense = "Expense"
    case income = "Income"
    var id: String { rawValue }
}

struct CategoryData: Identifiable {
    var id: String { category }
    let category: String
    let amount: Double
    let emoji: String
}

struct FinancialData: Identifiable {
    var id: String { type }
    let type: String
    let amount: Double
    let color: Color
}

struct DailyExpense: Identifiable {
    var id: Date { date }
    let date: Date
    let amount: Double
}

struct StatsView: View {
    @Environment(\.modelContext) private var context

    @Query private var expenses: [Expense]
    @Query private var incomes: [Income]

    @State private var selectedMonth: Date = Date()
    @State private var showingDatePicker = false
    @State private var selectedCategory: CategoryData? = nil

    // MARK: - Computed Properties

    private var filteredExpenses: [Expense] {
        let calendar = Calendar.current
        return expenses.filter { calendar.isDate($0.date, equalTo: selectedMonth, toGranularity: .month) }
    }

    private var filteredIncomes: [Income] {
        let calendar = Calendar.current
        return incomes.filter { calendar.isDate($0.date, equalTo: selectedMonth, toGranularity: .month) }
    }

    private var totalExpenses: Double {
        filteredExpenses.reduce(0) { $0 + $1.price }
    }

    private var totalIncome: Double {
        filteredIncomes.reduce(0) { $0 + $1.income }
    }

    private var monthOverMonthChange: Double? {
        SpendingAggregates.monthOverMonthChange(in: expenses, from: selectedMonth)
    }

    private var monthOverMonthText: String? {
        guard let change = monthOverMonthChange else { return nil }
        let direction = change <= 0 ? "less" : "more"
        return "\(String(format: "%.1f", abs(change)))% \(direction) than last month"
    }

    private var allTransactions: [HomeView.TransactionItem] {
        let expItems = filteredExpenses.map { HomeView.TransactionItem.expense($0) }
        let incItems = filteredIncomes.map { HomeView.TransactionItem.income($0) }
        return (expItems + incItems).sorted { $0.date > $1.date }
    }

    private var recentTransactions: [HomeView.TransactionItem] {
        Array(allTransactions.prefix(4))
    }

    private struct CategoryStat: Identifiable {
        var id: String { name }
        let name: String; let amount: Double; let percent: Double
        let color: Color; let icon: String
    }

    private static let categoryPalette: [(color: Color, icon: String)] = [
        (Color.appGreen, "fork.knife"),
        (Color(red: 59/255, green: 130/255, blue: 246/255), "bag.fill"),
        (Color.appWarningAmber, "fuelpump.fill"),
        (Color(red: 168/255, green: 85/255, blue: 247/255), "bolt.fill"),
        (Color.appExpenseRed, "film.fill"),
        (Color(red: 107/255, green: 114/255, blue: 128/255), "ellipsis")
    ]

    private var categoryStats: [CategoryStat] {
        let breakdown = CalculateExpenseSummaryUseCase.categoryBreakdown(of: filteredExpenses, total: totalExpenses)
        return Array(breakdown.enumerated().map { idx, total -> CategoryStat in
            let style = Self.categoryPalette[idx % Self.categoryPalette.count]
            return CategoryStat(name: total.name, amount: total.amount, percent: total.percentage, color: style.color, icon: style.icon)
        }.prefix(6))
    }

    private typealias MerchantStat = SpendingAggregates.MerchantTotal
    private var topMerchants: [MerchantStat] {
        SpendingAggregates.topMerchants(in: filteredExpenses)
    }

    private var topCategory: CategoryStat? { categoryStats.first }

    private var monthRangeString: String {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: selectedMonth)
        guard let start = cal.date(from: comps),
              let end = cal.date(byAdding: DateComponents(month: 1, day: -1), to: start) else { return "" }
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        let dy = DateFormatter(); dy.dateFormat = "MMM d, yyyy"
        return "\(df.string(from: start)) – \(dy.string(from: end))"
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Title header
                    headerBar

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 20) {
                            summaryCard
                            quickActionsRow
                            recentTransactionsSection
                            expensesByCategorySection
                            topMerchantsSection
                            Spacer().frame(height: 100)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    }
                    .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 90) }
                }
            }
            .fullScreenCover(item: $selectedCategory) { category in
                CategoryDetailSheet(
                    categoryName: category.category,
                    selectedFlow: .expense,
                    expenses: filteredExpenses,
                    incomes: filteredIncomes
                )
            }
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Expenses")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text("Track, manage and analyze your expenses")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
            Spacer()
            HStack(spacing: 10) {
                Button { } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.appGreen)
                        .frame(width: 38, height: 38)
                        .background(Color.appGreen.opacity(0.10))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                Button { } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.appGreen)
                        .frame(width: 38, height: 38)
                        .background(Color.appGreen.opacity(0.10))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Color.appBackground)
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        HStack(alignment: .center, spacing: 0) {
            // Left: numbers
            VStack(alignment: .leading, spacing: 8) {
                Text("Total Expenses")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)

                Text("₹\(formatAmount(totalExpenses))")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                // Date range + picker
                Button {
                    withAnimation { showingDatePicker.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Text(monthRangeString)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)

                if let monthOverMonthText {
                    HStack(spacing: 4) {
                        Image(systemName: (monthOverMonthChange ?? 0) <= 0 ? "arrow.down.right" : "arrow.up.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.appGreen)
                        Text(monthOverMonthText)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.appGreen)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Right: donut chart
            ZStack {
                ForEach(Array(donutSegments(categoryStats).enumerated()), id: \.offset) { _, seg in
                    Circle()
                        .trim(from: seg.start, to: seg.end)
                        .stroke(seg.color, style: StrokeStyle(lineWidth: 22, lineCap: .butt))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 110, height: 110)
                }
                if let topCategory {
                    VStack(spacing: 2) {
                        Text("Top Category")
                            .font(.system(size: 10.5, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                        Text(topCategory.name)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                        Text("\(String(format: "%.1f", topCategory.percent))%")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.appGreen)
                    }
                    .frame(width: 76)
                } else {
                    Text("No spend yet")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                        .frame(width: 76)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(width: 120, height: 120)
            .onTapGesture {
                guard let topCategory else { return }
                selectedCategory = CategoryData(category: topCategory.name, amount: topCategory.amount, emoji: "")
            }
        }
        // Depth from the shadow alone — the border here was redundant on top of it, and the
        // app's elevation system is shadow-only (see CardStyles.swift).
        .padding(18)
        .background(Color.appGreen.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    // MARK: - Quick Actions Row

    private var quickActionsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                quickAction(icon: "chart.line.uptrend.xyaxis", label: "View Insights")
                quickAction(icon: "doc.text.fill", label: "View Report")
                quickAction(icon: "tag.fill", label: "Categories")
                quickAction(icon: "repeat.circle.fill", label: "Recurring")
                quickAction(icon: "arrow.down.circle.fill", label: "Export")
            }
        }
    }

    @ViewBuilder
    private func quickAction(icon: String, label: String) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.appGreen.opacity(0.10))
                    .frame(width: 50, height: 50)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.appGreen)
            }
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(width: 64)
        }
    }

    // MARK: - Recent Transactions Section

    private var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Transactions")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Spacer()
                NavigationLink(destination: RecentTransactionsView().hidesTabBarOnPush()) {
                    HStack(spacing: 2) {
                        Text("View All")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.appGreen)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.appGreen)
                    }
                }
                .buttonStyle(.plain)
            }

            if recentTransactions.isEmpty {
                Text("No transactions yet this month")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recentTransactions.enumerated()), id: \.element.id) { idx, item in
                        NavigationLink(destination: TransactionDetailView(item: item).hidesTabBarOnPush()) {
                            transactionRow(item)
                        }
                        .buttonStyle(.plain)
                        if idx < recentTransactions.count - 1 {
                            Divider().padding(.leading, 60)
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
            }
        }
    }

    @ViewBuilder
    private func transactionRow(_ item: HomeView.TransactionItem) -> some View {
        let title = item.title.isEmpty ? item.type : item.title
        let isIncome = item.color == .appGreen
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isIncome ? Color.appGreen.opacity(0.12) : Color(.tertiarySystemGroupedBackground))
                    .frame(width: 44, height: 44)
                Text(item.emoji.isEmpty ? String(title.prefix(1)).uppercased() : item.emoji)
                    .font(.system(size: 18))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text(item.account.isEmpty ? (item.type.isEmpty ? "General" : item.type) : "\(item.type.isEmpty ? "General" : item.type) • \(item.account)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                Text(item.date.formattedFull)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text((isIncome ? "+₹" : "-₹") + String(format: "%.2f", item.amount))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(isIncome ? .appGreen : .appExpenseRed)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.5))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Expenses by Category Section

    private var expensesByCategorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Expenses by Category")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Spacer()
                Button { } label: {
                    HStack(spacing: 2) {
                        Text("View All")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.appGreen)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.appGreen)
                    }
                }
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(categoryStats) { cat in
                        Button {
                            selectedCategory = CategoryData(category: cat.name, amount: cat.amount, emoji: "")
                        } label: {
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(cat.color.opacity(0.12))
                                        .frame(width: 48, height: 48)
                                    Image(systemName: cat.icon)
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(cat.color)
                                }
                                Text(cat.name)
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.center)
                                    .frame(width: 70)
                                    .lineLimit(2)
                                Text("₹\(formatAmountShort(cat.amount))")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                Text("\(String(format: "%.1f", cat.percent))%")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundColor(.secondary)
                                // Progress bar
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Color.primary.opacity(0.06)).frame(height: 4)
                                        Capsule().fill(cat.color).frame(width: geo.size.width * CGFloat(cat.percent / 100.0), height: 4)
                                    }
                                }
                                .frame(width: 70, height: 4)
                            }
                            .padding(12)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Top Merchants Section

    private var topMerchantsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Top Merchants")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Spacer()
                Button { } label: {
                    HStack(spacing: 2) {
                        Text("View All")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.appGreen)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.appGreen)
                    }
                }
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    if topMerchants.isEmpty {
                        Text("No merchant spending yet")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    ForEach(topMerchants) { m in
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(Color.appGreen.opacity(0.10))
                                    .frame(width: 52, height: 52)
                                Image(systemName: "storefront.fill")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(.appGreen)
                            }
                            Text(m.name)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                                .frame(width: 70)
                                .lineLimit(2)
                            Text("₹\(formatAmountShort(m.amount))")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            Text("\(String(format: "%.1f", m.percentage))%")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        .padding(12)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Helpers

    private struct DonutSeg {
        let start: CGFloat; let end: CGFloat; let color: Color
    }

    private func donutSegments(_ cats: [CategoryStat]) -> [DonutSeg] {
        var cursor: CGFloat = 0
        return cats.map { cat in
            let frac = CGFloat(cat.percent / 100.0)
            let seg = DonutSeg(start: cursor, end: cursor + frac, color: cat.color)
            cursor += frac
            return seg
        }
    }

    private func formatAmount(_ v: Double) -> String {
        if v >= 100_000 { return String(format: "%.0f", v / 100_000) + " L" }
        return "\(Int(v).formatted())"
    }

    private func formatAmountShort(_ v: Double) -> String {
        if v >= 1_000 { return String(format: "%.0f", v / 1_000) + "K" }
        return "\(Int(v))"
    }
}

#Preview {
    StatsView()
}

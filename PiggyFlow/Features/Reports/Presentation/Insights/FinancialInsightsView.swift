import SwiftUI
import SwiftData
import Charts

struct FinancialInsightsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query private var expenses: [Expense]
    @Query private var incomes: [Income]
    @Query private var userCategories: [UserCategory]

    @State private var showBudgetSheet: Bool = false
    @State private var selectedPeriod: InsightsPeriod = .thisMonth

    enum InsightsPeriod: String, CaseIterable {
        case thisMonth = "This Month"
        case lastMonth = "Last Month"
        case thisYear = "This Year"
        case custom = "Custom"
    }

    // MARK: - Computed Properties

    private var filteredExpenses: [Expense] {
        let calendar = Calendar.current
        switch selectedPeriod {
        case .thisMonth:
            return expenses.filter { calendar.isDate($0.date, equalTo: Date(), toGranularity: .month) }
        case .lastMonth:
            guard let lm = calendar.date(byAdding: .month, value: -1, to: Date()) else { return expenses }
            return expenses.filter { calendar.isDate($0.date, equalTo: lm, toGranularity: .month) }
        case .thisYear:
            return expenses.filter { calendar.isDate($0.date, equalTo: Date(), toGranularity: .year) }
        case .custom:
            return expenses
        }
    }

    private var totalExpenses: Double {
        filteredExpenses.reduce(0) { $0 + $1.price }
    }

    private var totalIncome: Double {
        incomes.reduce(0) { $0 + $1.income }
    }

    private var savingsRate: Double {
        guard totalIncome > 0 else { return 0 }
        return max(0, min(100, ((totalIncome - totalExpenses) / totalIncome) * 100))
    }

    private var monthOverMonthChange: Double? {
        SpendingAggregates.monthOverMonthChange(in: expenses)
    }

    private var transactionCountChange: Int {
        let calendar = Calendar.current
        guard let lastMonth = calendar.date(byAdding: .month, value: -1, to: Date()) else { return 0 }
        let thisMonthCount = expenses.filter { calendar.isDate($0.date, equalTo: Date(), toGranularity: .month) }.count
        let lastMonthCount = expenses.filter { calendar.isDate($0.date, equalTo: lastMonth, toGranularity: .month) }.count
        return thisMonthCount - lastMonthCount
    }

    /// The category whose spend increased the most vs. last month — `nil` when nothing rose,
    /// so the fourth insight card can be skipped rather than forcing a claim.
    private var risingCategory: (name: String, change: Double)? {
        let categories = Set(filteredExpenses.map { $0.type.isEmpty ? "General" : $0.type })
        return categories
            .compactMap { category -> (String, Double)? in
                guard let change = SpendingAggregates.categoryMonthOverMonthChange(in: expenses, category: category), change > 0 else { return nil }
                return (category, change)
            }
            .max { $0.1 < $1.1 }
    }

    private var highestExpense: Expense? { filteredExpenses.max { $0.price < $1.price } }
    private var lowestExpense: Expense? { filteredExpenses.min { $0.price < $1.price } }

    private var moneySaved: Double { max(0, totalIncome - totalExpenses) }

    private var dailyAverageSpend: Double {
        let daysElapsed = Calendar.current.component(.day, from: Date())
        return daysElapsed > 0 ? totalExpenses / Double(daysElapsed) : 0
    }

    struct CategorySlice: Identifiable {
        var id: String { name }
        let name: String; let amount: Double; let percent: Double; let color: Color
    }

    private static let categoryPalette: [Color] = [
        Color.appGreen,
        Color(red: 134/255, green: 239/255, blue: 172/255),
        Color.appWarningAmber,
        Color.appTeal,
        Color(red: 168/255, green: 85/255, blue: 247/255),
        Color(red: 59/255, green: 130/255, blue: 246/255),
        Color.gray.opacity(0.5)
    ]

    private var categorySlices: [CategorySlice] {
        let breakdown = CalculateExpenseSummaryUseCase.categoryBreakdown(of: filteredExpenses, total: totalExpenses)
        return breakdown.enumerated().map { idx, total in
            CategorySlice(name: total.name, amount: total.amount, percent: total.percentage, color: Self.categoryPalette[idx % Self.categoryPalette.count])
        }
    }

    private typealias MerchantItem = SpendingAggregates.MerchantTotal
    private var topMerchants: [MerchantItem] {
        SpendingAggregates.topMerchants(in: filteredExpenses)
    }

    private typealias TrendPoint = SpendingAggregates.WeeklyTotal
    private var trendPoints: [TrendPoint] {
        SpendingAggregates.weeklyTotals(expenses: filteredExpenses, incomes: [], month: Date())
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        periodPicker
                        heroSpendingCard
                        keyInsightsSection
                        spendingByCategoryCard
                        merchantsAndTrendRow
                        personalizedInsightCard
                        bottomStatsBar
                        Spacer().frame(height: 110)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showBudgetSheet) { SetCategoryBudgetModalSheet() }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        VStack(spacing: 3) {
            HStack {
                BackButton { dismiss() }
                Spacer()
                VStack(spacing: 2) {
                    Text("Insights")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("Smart insights into your spending")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button { } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.appGreen)
                        .frame(width: 40, height: 40)
                        .background(Color.appGreen.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(Color.appBackground)
    }

    // MARK: - Period Picker

    private var periodPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(InsightsPeriod.allCases, id: \.self) { period in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedPeriod = period }
                        Haptics.light()
                    } label: {
                        Text(period.rawValue)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(selectedPeriod == period ? .white : .primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedPeriod == period ? Color.appGreen : Color(.secondarySystemGroupedBackground))
                            .clipShape(Capsule())
                            .shadow(color: selectedPeriod == period ? Color.appGreen.opacity(0.35) : Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Hero Spending Card

    private var heroSpendingCard: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.appGreen.opacity(0.12))
                    .frame(width: 52, height: 52)
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.appGreen)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("You've spent ₹\(formatAmount(totalExpenses)) this month")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                if let monthOverMonthChange {
                    HStack(spacing: 4) {
                        Image(systemName: monthOverMonthChange <= 0 ? "arrow.down.right" : "arrow.up.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.appGreen)
                        Text("That's \(String(format: "%.1f", abs(monthOverMonthChange)))% \(monthOverMonthChange <= 0 ? "less" : "more") than last month.")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()
        }
        // A flat tinted card, matching every other insight banner in the app (fill only,
        // no border) — this was the one with a redundant hairline stroke on top of the fill.
        .padding(16)
        .background(Color.appGreen.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Key Insights Section

    private struct KeyInsight: Identifiable {
        let id = UUID()
        let icon: String
        let color: Color
        let boldText: String
        let description: String
    }

    /// Every card here is derivable-or-absent — nothing is shown unless there's a real
    /// comparison behind it (a prior month to compare against, an actual top category, etc.).
    private var keyInsightCards: [KeyInsight] {
        var cards: [KeyInsight] = []

        if let change = monthOverMonthChange {
            cards.append(KeyInsight(
                icon: change <= 0 ? "arrow.down.circle.fill" : "arrow.up.circle.fill",
                color: .appGreen,
                boldText: "\(String(format: "%.1f", abs(change)))% \(change <= 0 ? "less" : "more")",
                description: "than last month"
            ))
        }

        if let top = categorySlices.first {
            cards.append(KeyInsight(
                icon: "exclamationmark.circle.fill",
                color: .appWarningAmber,
                boldText: top.name,
                description: "is your highest expense category"
            ))
        }

        if transactionCountChange != 0 {
            cards.append(KeyInsight(
                icon: "calendar.badge.plus",
                color: .appIndigo,
                boldText: "\(abs(transactionCountChange)) \(transactionCountChange > 0 ? "more" : "fewer")",
                description: "transactions than last month"
            ))
        }

        if let rising = risingCategory {
            cards.append(KeyInsight(
                icon: "bolt.fill",
                color: Color(red: 59/255, green: 130/255, blue: 246/255),
                boldText: "\(String(format: "%.0f", rising.change))%",
                description: "\(rising.name) spending increased by"
            ))
        }

        return cards
    }

    private var keyInsightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.appGreen)
                    Text("Key Insights")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                Spacer()
                if !keyInsightCards.isEmpty {
                    Text("\(keyInsightCards.count) Insight\(keyInsightCards.count == 1 ? "" : "s")")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.appGreen)
                }
            }

            if keyInsightCards.isEmpty {
                Text("Add a few more transactions to unlock insights here.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(keyInsightCards) { card in
                            keyInsightCard(
                                icon: card.icon,
                                iconColor: card.color,
                                iconBg: card.color.opacity(0.12),
                                boldText: card.boldText,
                                boldColor: card.color,
                                description: card.description,
                                accentLineColor: card.color
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    @ViewBuilder
    private func keyInsightCard(icon: String, iconColor: Color, iconBg: Color, boldText: String, boldColor: Color, description: String, accentLineColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                Circle().fill(iconBg).frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(iconColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Great! You spent")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Text(boldText)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(boldColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(description)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 6)
            // Accent line at bottom
            RoundedRectangle(cornerRadius: 2)
                .fill(accentLineColor)
                .frame(height: 3)
        }
        .padding(14)
        .frame(width: 142, height: 172)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
    }

    // MARK: - Spending by Category Card

    private var spendingByCategoryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Spending by Category")
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

            HStack(alignment: .center, spacing: 16) {
                // Donut Chart
                ZStack {
                    ForEach(Array(donutSegments(categorySlices).enumerated()), id: \.offset) { _, seg in
                        Circle()
                            .trim(from: seg.start, to: seg.end)
                            .stroke(seg.color, style: StrokeStyle(lineWidth: 28, lineCap: .butt))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 110, height: 110)
                    }
                    VStack(spacing: 2) {
                        Text("Total")
                            .font(.system(size: 10.5, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                        Text("₹\(formatAmount(totalExpenses))")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .minimumScaleFactor(0.7)
                    }
                }
                .frame(width: 120, height: 120)

                // Legend
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(categorySlices) { cat in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(cat.color)
                                .frame(width: 9, height: 9)
                            Text(cat.name)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .layoutPriority(1)
                            Spacer(minLength: 4)
                            Text("₹\(formatAmountShort(cat.amount))")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .fixedSize()
                            Text("\(String(format: "%.1f", cat.percent))%")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .fixedSize()
                                .frame(width: 38, alignment: .trailing)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
    }

    // MARK: - Merchants & Trend Row

    private var merchantsAndTrendRow: some View {
        HStack(alignment: .top, spacing: 12) {
            // Top Merchants
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Top Merchants")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    Spacer()
                    Button { } label: {
                        HStack(spacing: 2) {
                            Text("View All")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.appGreen)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.appGreen)
                        }
                    }
                    .buttonStyle(.plain)
                }

                if topMerchants.isEmpty {
                    Text("No merchant spending yet")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                } else {
                    VStack(spacing: 10) {
                        ForEach(topMerchants) { m in
                            HStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(Color.appGreen.opacity(0.10))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: "storefront.fill")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.appGreen)
                                }
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(m.name)
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                        // This column is roughly half the screen's width minus an
                                        // icon and a percent label — even a name as ordinary as
                                        // "Reliance BP" truncated to "Relianc…" with no shrink
                                        // allowance at all.
                                        .minimumScaleFactor(0.75)
                                    Text("₹\(formatAmountShort(m.amount))")
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text("\(String(format: "%.1f", m.percentage))%")
                                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                Button { } label: {
                    Text("View All Merchants")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.appGreen)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.appGreen.opacity(0.08))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
            .frame(maxWidth: .infinity)

            // Spending Trend
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Spending Trend")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    Spacer()
                    Button { } label: {
                        HStack(spacing: 2) {
                            Text("View All")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.appGreen)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.appGreen)
                        }
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily average this month")
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                    Text("₹\(formatAmountShort(dailyAverageSpend))")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }

                if let monthOverMonthChange {
                    HStack(spacing: 4) {
                        Image(systemName: monthOverMonthChange <= 0 ? "arrow.down.right" : "arrow.up.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.appGreen)
                        Text("\(String(format: "%.1f", abs(monthOverMonthChange)))%")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.appGreen)
                        Text("vs last month")
                            .font(.system(size: 10.5, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }

                // Mini area chart — real weekly buckets from SpendingAggregates, not an
                // invented curve.
                if trendPoints.contains(where: { $0.expense > 0 }) {
                    GeometryReader { geo in
                        let pts = trendPoints
                        let maxV = pts.map(\.expense).max() ?? 1
                        let w = geo.size.width
                        let h = geo.size.height
                        let stepX = pts.count > 1 ? w / CGFloat(pts.count - 1) : 0

                        Path { path in
                            for (i, pt) in pts.enumerated() {
                                let x = CGFloat(i) * stepX
                                let y = h - CGFloat(pt.expense / maxV) * h
                                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                                else { path.addLine(to: CGPoint(x: x, y: y)) }
                            }
                        }
                        .stroke(Color.appGreen, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                        Path { path in
                            for (i, pt) in pts.enumerated() {
                                let x = CGFloat(i) * stepX
                                let y = h - CGFloat(pt.expense / maxV) * h
                                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                                else { path.addLine(to: CGPoint(x: x, y: y)) }
                            }
                            path.addLine(to: CGPoint(x: w, y: h))
                            path.addLine(to: CGPoint(x: 0, y: h))
                            path.closeSubpath()
                        }
                        .fill(LinearGradient(colors: [Color.appGreen.opacity(0.25), Color.appGreen.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                    }
                    .frame(height: 70)

                    // X-axis labels
                    HStack {
                        ForEach(Array(trendPoints.enumerated()), id: \.offset) { index, point in
                            Text(point.label)
                                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                            if index < trendPoints.count - 1 { Spacer() }
                        }
                    }
                } else {
                    Text("No spending recorded yet this month")
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .frame(height: 70)
                }
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Personalized Insight Card

    private struct PersonalizedInsight {
        let icon: String
        let headline: String
        let detail: String
    }

    /// The category that rose the most vs. last month, if any; otherwise just the current top
    /// category. `nil` (card hidden entirely) when there's nothing to say — no invented "cafe
    /// spending" claim standing in for a sub-category the data model doesn't track.
    private var personalizedInsight: PersonalizedInsight? {
        if let rising = risingCategory, totalExpenses > 0 {
            let categoryTotal = filteredExpenses.filter { $0.type == rising.name }.reduce(0) { $0 + $1.price }
            let shareOfTotal = (categoryTotal / totalExpenses) * 100
            return PersonalizedInsight(
                icon: "arrow.up.right.circle.fill",
                headline: "You spent ₹\(formatAmount(categoryTotal)) on \(rising.name) this month.",
                detail: "That's \(String(format: "%.0f", shareOfTotal))% of your total spending, up \(String(format: "%.0f", rising.change))% from last month. Consider setting a budget to keep it in check."
            )
        }
        if let top = categorySlices.first {
            return PersonalizedInsight(
                icon: "chart.pie.fill",
                headline: "\(top.name) is your biggest expense this month.",
                detail: "It makes up \(String(format: "%.0f", top.percent))% of your total spending. Set a budget to keep it on track."
            )
        }
        return nil
    }

    @ViewBuilder
    private var personalizedInsightCard: some View {
        if let insight = personalizedInsight {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.appWarningAmber)
                    Text("Personalized Insight")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }

                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.appWarningAmber.opacity(0.12))
                            .frame(width: 56, height: 56)
                        Image(systemName: insight.icon)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.appWarningAmber)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(insight.headline)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Text(insight.detail)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                            .lineSpacing(2)
                    }
                    Button {
                        showBudgetSheet = true
                    } label: {
                        Text("Set Budget")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.appGreen)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
        }
    }

    // MARK: - Bottom Stats Bar

    private var bottomStatsBar: some View {
        HStack(spacing: 0) {
            bottomStatItem(
                icon: "arrow.up.circle.fill", iconColor: Color.appExpenseRed, title: "Highest Expense",
                value: highestExpense.map { AppFormatter.currencyRounded($0.price) } ?? "—",
                sub: highestExpense.map { $0.date.formatted(.dateTime.month(.abbreviated).day()) } ?? "No data"
            )
            Divider().frame(height: 44)
            bottomStatItem(
                icon: "arrow.down.circle.fill", iconColor: Color.appGreen, title: "Lowest Expense",
                value: lowestExpense.map { AppFormatter.currencyRounded($0.price) } ?? "—",
                sub: lowestExpense.map { $0.date.formatted(.dateTime.month(.abbreviated).day()) } ?? "No data"
            )
            Divider().frame(height: 44)
            bottomStatItem(
                icon: "list.bullet.rectangle.fill", iconColor: Color.appIndigo, title: "Total Transactions",
                value: "\(filteredExpenses.count)",
                sub: transactionCountChange == 0 ? "Same as last month" : "\(transactionCountChange > 0 ? "+" : "")\(transactionCountChange) vs last month"
            )
            Divider().frame(height: 44)
            bottomStatItem(
                icon: "banknote.fill", iconColor: Color.appWarningAmber, title: "Money Saved",
                value: AppFormatter.currencyRounded(moneySaved),
                sub: "So far this month"
            )
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
    }

    @ViewBuilder
    private func bottomStatItem(icon: String, iconColor: Color, title: String, value: String, sub: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(iconColor)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            Text(sub)
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func formatAmount(_ v: Double) -> String {
        if v >= 100_000 { return String(format: "%.2f L", v / 100_000) }
        return "\(Int(v).formatted())"
    }

    private func formatAmountShort(_ v: Double) -> String {
        if v >= 1_000 { return String(format: "%.2f", v / 1_000) + "K" }
        return "\(Int(v))"
    }

    struct DonutSegment {
        let start: CGFloat; let end: CGFloat; let color: Color
    }

    private func donutSegments(_ slices: [CategorySlice]) -> [DonutSegment] {
        var cursor: CGFloat = 0
        return slices.map { s in
            let frac = CGFloat(s.percent / 100.0)
            let seg = DonutSegment(start: cursor, end: cursor + frac, color: s.color)
            cursor += frac
            return seg
        }
    }
}

// MARK: - Modal Sheet to Set Category Budget
struct SetCategoryBudgetModalSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var categoryName: String = "Food & Dining"
    @State private var limitAmount: String = "25000"
    let categories = ["Food & Dining", "Shopping", "Fuel", "Utilities", "Entertainment"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Category")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                        Picker("Category", selection: $categoryName) {
                            ForEach(categories, id: \.self) { c in Text(c).tag(c) }
                        }
                        .pickerStyle(.menu)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Monthly Spending Limit (₹)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                        TextField("e.g. 25000", text: $limitAmount)
                            .keyboardType(.numberPad)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .padding(14)
                            .background(Color.primary.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                Spacer()
                Button { dismiss() } label: {
                    Text("Save Budget Limit")
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
            .navigationTitle("Set Category Budget Limit")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    FinancialInsightsView()
}

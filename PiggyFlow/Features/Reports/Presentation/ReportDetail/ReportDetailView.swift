import SwiftUI
import SwiftData
import UIKit

struct ReportDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query private var expenses: [Expense]
    @Query private var incomes: [Income]

    @State private var selectedTrendPeriod: String = "Weekly"
    @State private var showShareSheet: Bool = false
    @State private var pdfURLToShare: URL? = nil

    private let trendPeriods = ["Daily", "Weekly", "Monthly"]

    // MARK: - Real data

    private static let categoryPalette: [Color] = [
        .appGreen,
        Color(red: 59/255, green: 130/255, blue: 246/255),
        Color(red: 147/255, green: 51/255, blue: 234/255),
        Color(red: 249/255, green: 115/255, blue: 22/255),
        Color.appExpenseRed,
        Color.gray.opacity(0.55)
    ]

    private var reportMonth: Date { Date() }

    private var monthExpenses: [Expense] {
        let cal = Calendar.current
        return expenses.filter { cal.isDate($0.date, equalTo: reportMonth, toGranularity: .month) }
    }

    private var monthIncomes: [Income] {
        let cal = Calendar.current
        return incomes.filter { cal.isDate($0.date, equalTo: reportMonth, toGranularity: .month) }
    }

    private var summary: ExpenseSummary {
        CalculateExpenseSummaryUseCase.summary(expenses: monthExpenses, incomes: monthIncomes)
    }

    private var categoryBreakdown: [CategoryTotal] { summary.categoryBreakdown }
    private var topMerchants: [SpendingAggregates.MerchantTotal] { SpendingAggregates.topMerchants(in: monthExpenses) }

    private func incomeTotal(monthsAgo: Int) -> Double {
        let cal = Calendar.current
        guard let target = cal.date(byAdding: .month, value: -monthsAgo, to: reportMonth) else { return 0 }
        return incomes.filter { cal.isDate($0.date, equalTo: target, toGranularity: .month) }.reduce(0) { $0 + $1.income }
    }

    private var incomeChange: Double? {
        let current = incomeTotal(monthsAgo: 0)
        let previous = incomeTotal(monthsAgo: 1)
        guard previous > 0 else { return nil }
        return ((current - previous) / previous) * 100
    }
    private var expenseChange: Double? { SpendingAggregates.monthOverMonthChange(in: expenses, from: reportMonth) }

    private var highestExpense: Expense? { monthExpenses.max { $0.price < $1.price } }

    /// The category with the biggest month-over-month decrease — the "top saving category".
    private var topSavingCategory: (name: String, change: Double)? {
        let categories = Set(monthExpenses.map { $0.type.isEmpty ? "Uncategorised" : $0.type })
        return categories
            .compactMap { category -> (String, Double)? in
                guard let change = SpendingAggregates.categoryMonthOverMonthChange(in: expenses, category: category, from: reportMonth), change < 0 else { return nil }
                return (category, change)
            }
            .min { $0.1 < $1.1 }
    }

    /// The category with the biggest month-over-month increase, in absolute rupees — for the
    /// "you spent more on X" insight line.
    private var risingCategory: (name: String, amountChange: Double)? {
        let categories = Set(monthExpenses.map { $0.type.isEmpty ? "Uncategorised" : $0.type })
        let cal = Calendar.current
        guard let lastMonth = cal.date(byAdding: .month, value: -1, to: reportMonth) else { return nil }
        return categories
            .compactMap { category -> (String, Double)? in
                let current = monthExpenses.filter { $0.type == category }.reduce(0) { $0 + $1.price }
                let previous = expenses
                    .filter { $0.type == category && cal.isDate($0.date, equalTo: lastMonth, toGranularity: .month) }
                    .reduce(0) { $0 + $1.price }
                let delta = current - previous
                guard previous > 0, delta > 0 else { return nil }
                return (category, delta)
            }
            .max { $0.1 < $1.1 }
    }

    private var reportMonthTitle: String { reportMonth.formatted(.dateTime.month(.wide).year()) + " Report" }
    private var reportMonthRange: String {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: reportMonth)
        guard let start = cal.date(from: comps),
              let end = cal.date(byAdding: DateComponents(month: 1, day: -1), to: start) else { return "" }
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        let dy = DateFormatter(); dy.dateFormat = "MMM d, yyyy"
        return "\(df.string(from: start)) – \(dy.string(from: end))"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 1. Navigation Header Bar
                headerBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        // 2. Top Metric Cards Row (3 Cards)
                        topMetricsRow

                        // 3. Income vs Expense Trend Section (Line Chart with Toggle)
                        trendChartSection

                        // 4. Side-by-Side Section (Expenses by Category & Top Merchants)
                        sideBySideSection

                        // 5. Category Insights Grid (3 Cards)
                        categoryInsightsSection

                        // 6. Spending Summary Section (2 Columns with Progress Bars)
                        spendingSummarySection

                        // 7. Smart Insights Banner
                        smartInsightsBanner

                        // 8. Export Buttons Bar (Export PDF & Export Excel)
                        exportButtonsBar
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showShareSheet) {
            if let pdfURL = pdfURLToShare {
                ActivityViewController(activityItems: [pdfURL])
            }
        }
    }

    // MARK: - 1. Navigation Header Bar
    private var headerBar: some View {
        HStack {
            BackButton { dismiss() }

            Spacer()

            VStack(spacing: 2) {
                Text(reportMonthTitle)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text(reportMonthRange)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                Haptics.medium()
                exportPDFReport()
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color.appGreenDeep)
                    .frame(width: 40, height: 40)
                    .background(Color.appGreen.opacity(0.12))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(Color.appBackground)
    }

    // MARK: - 2. Top Metric Cards Row (3 Cards)
    private var topMetricsRow: some View {
        HStack(spacing: 10) {
            // Card 1: Total Income
            metricCard(
                icon: "wallet.pass.fill",
                iconColor: Color.appGreen,
                bgColor: Color.appGreen.opacity(0.12),
                title: "Total Income",
                amount: AppFormatter.currencyRounded(summary.totalIncome),
                comparison: incomeChange.map { "\($0 >= 0 ? "↑" : "↓") \(String(format: "%.1f", abs($0)))% vs last month" },
                comparisonColor: Color.appGreen
            )

            // Card 2: Total Expenses
            metricCard(
                icon: "creditcard.fill",
                iconColor: Color.appExpenseRed,
                bgColor: Color.appExpenseRed.opacity(0.12),
                title: "Total Expenses",
                amount: AppFormatter.currencyRounded(summary.totalSpent),
                comparison: expenseChange.map { "\($0 >= 0 ? "↑" : "↓") \(String(format: "%.1f", abs($0)))% vs last month" },
                comparisonColor: Color.appExpenseRed
            )

            // Card 3: Savings
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Circle()
                        .fill(Color(red: 243/255, green: 232/255, blue: 255/255))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "circle.hexagonpath.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color(red: 147/255, green: 51/255, blue: 234/255))
                        )
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("Savings")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)

                    Text(AppFormatter.currencyRounded(summary.netBalance))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                VStack(alignment: .leading, spacing: 0) {
                    Text("Savings Rate")
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)

                    Text("\(String(format: "%.1f", summary.savingsRate))%")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 5, x: 0, y: 2)
        }
    }

    @ViewBuilder
    private func metricCard(icon: String, iconColor: Color, bgColor: Color, title: String, amount: String, comparison: String?, comparisonColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Circle()
                .fill(bgColor)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(iconColor)
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)

                Text(amount)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            if let comparison {
                Text(comparison)
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .foregroundColor(comparisonColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 5, x: 0, y: 2)
    }

    // MARK: - 3. Income vs Expense Trend Section (Line Chart with Toggle)
    private var trendChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Income vs Expense Trend")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Spacer()

                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Rectangle().fill(Color.appGreen).frame(width: 8, height: 8)
                            Text("Income").font(.system(size: 10.5, weight: .semibold, design: .rounded)).foregroundColor(.secondary)
                        }
                        HStack(spacing: 4) {
                            Rectangle().fill(Color.appExpenseRed).frame(width: 8, height: 8)
                            Text("Expense").font(.system(size: 10.5, weight: .semibold, design: .rounded)).foregroundColor(.secondary)
                        }
                    }
                }

                // 3-Pill Switch
                HStack(spacing: 2) {
                    ForEach(trendPeriods, id: \.self) { period in
                        Button {
                            Haptics.light()
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                selectedTrendPeriod = period
                            }
                        } label: {
                            Text(period)
                                .font(.system(size: 11, weight: selectedTrendPeriod == period ? .bold : .medium, design: .rounded))
                                .lineLimit(1)
                                .fixedSize()
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .foregroundColor(selectedTrendPeriod == period ? Color.appGreenDeep : .secondary)
                                .background(
                                    Capsule()
                                        .fill(selectedTrendPeriod == period ? Color.appGreen.opacity(0.12) : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer(minLength: 0)
                }
                .padding(3)
                .background(Capsule().fill(Color.gray.opacity(0.1)))
            }

            // Dual Curved Line Chart
            GeometryReader { geo in
                let width = geo.size.width
                let height = geo.size.height
                let incomePoints = trendPoints(fractionsY: incomeFractionsY, width: width, height: height)
                let expensePoints = trendPoints(fractionsY: expenseFractionsY, width: width, height: height)

                ZStack {
                    // Background Grid Lines
                    VStack(spacing: 0) {
                        ForEach(Array(trendGridLabels.enumerated()), id: \.offset) { index, label in
                            gridLine(label: label)
                            if index < trendGridLabels.count - 1 { Spacer() }
                        }
                    }

                    // Income Gradient & Line (Green)
                    curvePath(points: incomePoints, height: height, closeToBottom: true)
                        .fill(LinearGradient(colors: [Color.appGreen.opacity(0.18), Color.appGreen.opacity(0.01)], startPoint: .top, endPoint: .bottom))

                    curvePath(points: incomePoints, height: height, closeToBottom: false)
                        .stroke(Color.appGreen, lineWidth: 2.2)

                    ForEach(0..<incomePoints.count, id: \.self) { idx in
                        Circle().fill(Color.appSurface).frame(width: 6, height: 6)
                            .overlay(Circle().stroke(Color.appGreen, lineWidth: 2))
                            .position(incomePoints[idx])
                    }

                    // Expense Gradient & Line (Red)
                    curvePath(points: expensePoints, height: height, closeToBottom: true)
                        .fill(LinearGradient(colors: [Color.red.opacity(0.12), Color.red.opacity(0.01)], startPoint: .top, endPoint: .bottom))

                    curvePath(points: expensePoints, height: height, closeToBottom: false)
                        .stroke(Color.appExpenseRed, lineWidth: 2.2)

                    ForEach(0..<expensePoints.count, id: \.self) { idx in
                        Circle().fill(Color.appSurface).frame(width: 6, height: 6)
                            .overlay(Circle().stroke(Color.appExpenseRed, lineWidth: 2))
                            .position(expensePoints[idx])
                    }
                }
            }
            .frame(height: 150)

            // X-Axis Labels
            HStack {
                ForEach(weeklyTrend) { point in
                    Text(point.label).frame(maxWidth: .infinity)
                }
            }
            .font(.system(size: 9.5, weight: .medium, design: .rounded))
            .foregroundColor(.secondary)
            // Same 32pt gutter as the curve above, so the date labels line up under the
            // points they actually correspond to instead of drifting 4pt out of register.
            .padding(.leading, 32)
        }
        .padding(16)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    // Fractional x/y positions for the two curves — derived from real weekly sums
    // (`SpendingAggregates.weeklyTotals`), not invented. `fy` is inverted (0 = top of the
    // chart) and given 5%/10% headroom top and bottom so the peak never touches the frame.
    private var weeklyTrend: [SpendingAggregates.WeeklyTotal] {
        SpendingAggregates.weeklyTotals(expenses: monthExpenses, incomes: monthIncomes, month: reportMonth)
    }

    private var trendMaxValue: Double {
        max(weeklyTrend.map(\.income).max() ?? 0, weeklyTrend.map(\.expense).max() ?? 0, 1)
    }

    private var trendGridLabels: [String] {
        (0...5).reversed().map { step in
            "₹" + formatAmountShort(trendMaxValue * Double(step) / 5.0)
        }
    }

    private var incomeFractionsY: [CGFloat] {
        weeklyTrend.map { 0.05 + (1 - CGFloat($0.income / trendMaxValue)) * 0.85 }
    }
    private var expenseFractionsY: [CGFloat] {
        weeklyTrend.map { 0.05 + (1 - CGFloat($0.expense / trendMaxValue)) * 0.85 }
    }
    private var trendFractionsX: [CGFloat] {
        let count = weeklyTrend.count
        guard count > 1 else { return [0.5] }
        return (0..<count).map { 0.05 + (0.90 * CGFloat($0) / CGFloat(count - 1)) }
    }

    private func formatAmountShort(_ v: Double) -> String {
        if v >= 100_000 { return String(format: "%.1fL", v / 100_000) }
        if v >= 1_000 { return String(format: "%.0fK", v / 1_000) }
        return "\(Int(v))"
    }

    /// Maps fractional positions into the plot area, inset by `labelGutter` on the left —
    /// matching `gridLine`'s own reserved label column (26pt text + 6pt spacing). Without this
    /// inset the curve is plotted against the full width while the axis labels sit in their
    /// own leading gutter, so the leftmost data point lands directly on the "₹10K" label
    /// instead of clear of it.
    private func trendPoints(fractionsY: [CGFloat], width: CGFloat, height: CGFloat) -> [CGPoint] {
        let labelGutter: CGFloat = 32
        let plotWidth = width - labelGutter
        return zip(trendFractionsX, fractionsY).map { fx, fy in
            CGPoint(x: labelGutter + plotWidth * fx, y: height * fy)
        }
    }

    private func gridLine(label: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .frame(width: 26, alignment: .leading)
            Rectangle()
                .fill(Color.gray.opacity(0.12))
                .frame(height: 1)
        }
    }

    private func curvePath(points: [CGPoint], height: CGFloat, closeToBottom: Bool) -> Path {
        Path { path in
            // `points` comes from zipping the X and Y fraction arrays, and those can disagree
            // in length — `trendFractionsX` substitutes a single mid-point when there's less
            // than two weeks of data, while `fractionsY` follows `weeklyTrend` and can be
            // empty. The zip then yields nothing and the subscripts below crash, so bail out
            // to an empty path instead.
            guard let first = points.first, let last = points.last else { return }

            if closeToBottom { path.move(to: CGPoint(x: first.x, y: height)) }
            path.move(to: first)
            for i in 1..<points.count {
                let prev = points[i-1]
                let current = points[i]
                let control1 = CGPoint(x: (prev.x + current.x) / 2, y: prev.y)
                let control2 = CGPoint(x: (prev.x + current.x) / 2, y: current.y)
                path.addCurve(to: current, control1: control1, control2: control2)
            }
            if closeToBottom {
                path.addLine(to: CGPoint(x: last.x, y: height))
                path.closeSubpath()
            }
        }
    }

    // MARK: - 4. Side-by-Side Section (Expenses by Category & Top Merchants)
    private var sideBySideSection: some View {
        HStack(alignment: .top, spacing: 10) {
            // Left Card: Expenses by Category
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Expenses by Category")
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Spacer(minLength: 2)

                    Text("View Details")
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundColor(.appGreen)
                }

                if categoryBreakdown.isEmpty {
                    Text("No expenses yet this month")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 100)
                } else {
                    VStack(alignment: .center, spacing: 10) {
                        // Donut Chart — real per-category share of this month's spending.
                        ZStack {
                            Circle().stroke(Color.gray.opacity(0.15), lineWidth: 10).frame(width: 68, height: 68)
                            ForEach(Array(categoryDonutSegments.enumerated()), id: \.offset) { _, seg in
                                Circle()
                                    .trim(from: seg.start, to: seg.end)
                                    .stroke(seg.color, lineWidth: 10)
                                    .frame(width: 68, height: 68)
                            }

                            VStack(spacing: 0) {
                                Text("Total")
                                    .font(.system(size: 8.5, weight: .medium, design: .rounded))
                                    .foregroundColor(.secondary)

                                Text(AppFormatter.currencyRounded(summary.totalSpent))
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            .frame(width: 46)
                        }

                        // Legend Column
                        VStack(spacing: 6) {
                            ForEach(Array(categoryBreakdown.prefix(6).enumerated()), id: \.offset) { index, cat in
                                categoryLegend(
                                    color: Self.categoryPalette[index % Self.categoryPalette.count],
                                    name: cat.name,
                                    percent: "\(String(format: "%.1f", cat.percentage))%"
                                )
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 240)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 5, x: 0, y: 2)

            // Right Card: Top Merchants
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Top Merchants")
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Spacer(minLength: 2)

                    HStack(spacing: 2) {
                        Text("View All")
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(.appGreen)
                }

                if topMerchants.isEmpty {
                    Text("No merchant spending yet")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                } else {
                    VStack(spacing: 6) {
                        ForEach(topMerchants) { m in
                            merchantRow(name: m.name, amount: AppFormatter.currencyRounded(m.amount), percent: "\(String(format: "%.1f", m.percentage))%")
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 240)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 5, x: 0, y: 2)
        }
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

    @ViewBuilder
    private func categoryLegend(color: Color, name: String, percent: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(name)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .layoutPriority(1)
            Spacer(minLength: 4)
            Text(percent)
                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .fixedSize()
        }
    }

    @ViewBuilder
    private func merchantRow(name: String, amount: String, percent: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(Color.appGreen.opacity(0.12)).frame(width: 20, height: 20)
                .overlay(Image(systemName: "storefront.fill").font(.system(size: 9, weight: .bold)).foregroundColor(.appGreen))

            Text(name)
                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 2)

            VStack(alignment: .trailing, spacing: 1) {
                Text(amount)
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .fixedSize()
                Text(percent)
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
    }

    // MARK: - 5. Category Insights Grid (3 Cards)
    private var categoryInsightsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.appGreen.opacity(0.16))
                        .frame(width: 26, height: 26)
                        .overlay(
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.appGreen)
                        )
                    Text("Category Insights")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }

                Spacer()

                HStack(spacing: 2) {
                    Text("View All")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(.appGreen)
            }

            HStack(spacing: 8) {
                // Card 1: Top Category
                insightCard(
                    icon: "cart.fill",
                    iconColor: Color(red: 37/255, green: 99/255, blue: 235/255),
                    bgColor: Color(red: 239/255, green: 246/255, blue: 255/255),
                    header: "Top Category",
                    mainText: categoryBreakdown.first?.name ?? "—",
                    detailText: categoryBreakdown.first.map { "\(AppFormatter.currencyRounded($0.amount)) (\(String(format: "%.1f", $0.percentage))%)" } ?? "No spending yet",
                    detailColor: Color.appGreen
                )

                // Card 2: Highest Expense
                insightCard(
                    icon: "creditcard.fill",
                    iconColor: Color(red: 249/255, green: 115/255, blue: 22/255),
                    bgColor: Color(red: 254/255, green: 243/255, blue: 235/255),
                    header: "Highest Expense",
                    mainText: highestExpense.map { AppFormatter.currencyRounded($0.price) } ?? "—",
                    detailText: highestExpense.map { "at \($0.merchant.isEmpty ? ($0.name.isEmpty ? $0.type : $0.name) : $0.merchant)" } ?? "No expenses yet",
                    detailColor: .secondary
                )

                // Card 3: Top Saving Category
                insightCard(
                    icon: "percent",
                    iconColor: Color.appGreen,
                    bgColor: Color.appGreen.opacity(0.12),
                    header: "Top Saving Category",
                    mainText: topSavingCategory?.name ?? "—",
                    detailText: topSavingCategory.map { "\(String(format: "%.1f", abs($0.change)))% less than last month" } ?? "Nothing decreased yet",
                    detailColor: Color.appGreen
                )
            }
        }
    }

    @ViewBuilder
    private func insightCard(icon: String, iconColor: Color, bgColor: Color, header: String, mainText: String, detailText: String, detailColor: Color) -> some View {
        VStack(spacing: 6) {
            Circle()
                .fill(bgColor)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(iconColor)
                )

            Text(header)
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)

            Text(mainText)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(detailText)
                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                .foregroundColor(detailColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 116)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 5, x: 0, y: 2)
    }

    // MARK: - 6. Spending Summary Section (2 Columns with Progress Bars)
    private var spendingSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spending Summary")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            if categoryBreakdown.isEmpty {
                Text("No expenses yet this month")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.appSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
            } else {
                let items = Array(categoryBreakdown.prefix(6).enumerated())
                let maxAmount = categoryBreakdown.first?.amount ?? 1
                let leftColumn = items.filter { $0.offset.isMultiple(of: 2) }
                let rightColumn = items.filter { !$0.offset.isMultiple(of: 2) }

                HStack(alignment: .top, spacing: 14) {
                    VStack(spacing: 12) {
                        ForEach(leftColumn, id: \.offset) { index, cat in
                            summaryCategoryRow(
                                icon: "tag.fill",
                                bgColor: Self.categoryPalette[index % Self.categoryPalette.count].opacity(0.12),
                                iconColor: Self.categoryPalette[index % Self.categoryPalette.count],
                                name: cat.name,
                                amountText: "\(AppFormatter.currencyRounded(cat.amount)) (\(String(format: "%.1f", cat.percentage))%)",
                                progressColor: Self.categoryPalette[index % Self.categoryPalette.count],
                                ratio: CGFloat(cat.amount / maxAmount)
                            )
                        }
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 12) {
                        ForEach(rightColumn, id: \.offset) { index, cat in
                            summaryCategoryRow(
                                icon: "tag.fill",
                                bgColor: Self.categoryPalette[index % Self.categoryPalette.count].opacity(0.12),
                                iconColor: Self.categoryPalette[index % Self.categoryPalette.count],
                                name: cat.name,
                                amountText: "\(AppFormatter.currencyRounded(cat.amount)) (\(String(format: "%.1f", cat.percentage))%)",
                                progressColor: Self.categoryPalette[index % Self.categoryPalette.count],
                                ratio: CGFloat(cat.amount / maxAmount)
                            )
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(14)
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
            }
        }
    }

    @ViewBuilder
    private func summaryCategoryRow(icon: String, bgColor: Color, iconColor: Color, name: String, amountText: String, progressColor: Color, ratio: CGFloat) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(bgColor)
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(iconColor)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(amountText)
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.gray.opacity(0.15))
                            .frame(height: 5)
                        Capsule()
                            .fill(progressColor)
                            .frame(width: geo.size.width * ratio, height: 5)
                    }
                }
                .frame(height: 5)
            }
        }
    }

    // MARK: - 7. Smart Insights Banner
    private var smartInsightsBanner: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.appGreen.opacity(0.16))
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.appGreen)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text("Smart Insights")
                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                if let rising = risingCategory {
                    Text("• You spent \(AppFormatter.currencyRounded(rising.amountChange)) more on \(rising.name) compared to last month.")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }

                if let saving = topSavingCategory {
                    Text("• \(saving.name) spending has decreased by \(String(format: "%.1f", abs(saving.change)))%.")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }

                if risingCategory == nil && topSavingCategory == nil {
                    Text("Add a few more months of data to see spending trends here.")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary.opacity(0.6))
        }
        .padding(14)
        .background(Color.appGreen.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - 8. Export Buttons Bar (Export PDF & Export Excel)
    private var exportButtonsBar: some View {
        HStack(spacing: 12) {
            // Export PDF Button (Outline Style)
            Button {
                Haptics.medium()
                exportPDFReport()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.appGreen)

                    Text("Export PDF")
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        .foregroundColor(.appGreen)
                }
                // The app's own secondary-action style — a tinted fill, no hairline border.
                // This was the one other bordered control left after the same fix on Scan Bill.
                .secondaryButton(tint: .appGreen, cornerRadius: 14)
            }
            .buttonStyle(.plain)

            // Export Excel Button (Filled Style)
            Button {
                Haptics.medium()
                exportPDFReport()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "tablecells.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)

                    Text("Export Excel")
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.appGreenDeep)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: Color.appGreenDeep.opacity(0.25), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - PDF Export Helper
    private func exportPDFReport() {
        let reportTitle = "Financial Report - \(reportMonth.formatted(.dateTime.month(.wide).year()))"
        let pdfMetaData = [
            kCGPDFContextCreator: "PiggyFlow",
            kCGPDFContextAuthor: "PiggyFlow User",
            kCGPDFContextTitle: reportTitle
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let data = renderer.pdfData { context in
            context.beginPage()
            var y: CGFloat = 40
            "PiggyFlow \(reportTitle)".draw(at: CGPoint(x: 40, y: y), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 22)])
            y += 40
            y = PDFTableRenderer.drawHeader(y: y)
            for exp in expenses.prefix(20) {
                let name = exp.name.isEmpty ? "Expense" : exp.name
                let dateStr = exp.date.formatted(.dateTime.month(.abbreviated).day().year())
                y = PDFTableRenderer.drawRow(name: name, amount: "₹\(Int(exp.price))", date: dateStr, y: y)
            }
        }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("PiggyFlow_Report.pdf")
        try? data.write(to: tempURL)
        pdfURLToShare = tempURL
        showShareSheet = true
    }
}

#Preview {
    ReportDetailView()
}

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
        let actual = filteredExpenses.reduce(0) { $0 + $1.price }
        return actual > 0 ? actual : 120_440
    }

    private var totalIncome: Double {
        let actual = incomes.reduce(0) { $0 + $1.income }
        return actual > 0 ? actual : 245_000
    }

    private var savingsRate: Double {
        guard totalIncome > 0 else { return 50.7 }
        return max(0, min(100, ((totalIncome - totalExpenses) / totalIncome) * 100))
    }

    struct CategorySlice: Identifiable {
        var id: String { name }
        let name: String; let amount: Double; let percent: Double; let color: Color
    }

    private var categorySlices: [CategorySlice] {
        let palette: [Color] = [
            Color.appGreen,
            Color(red: 134/255, green: 239/255, blue: 172/255),
            Color.appWarningAmber,
            Color.appTeal,
            Color(red: 168/255, green: 85/255, blue: 247/255),
            Color(red: 59/255, green: 130/255, blue: 246/255),
            Color.gray.opacity(0.5)
        ]
        if !filteredExpenses.isEmpty {
            var dict: [String: Double] = [:]
            for e in filteredExpenses { dict[e.type.isEmpty ? "General" : e.type, default: 0] += e.price }
            let total = dict.values.reduce(0, +)
            return dict.enumerated().map { idx, pair in
                CategorySlice(name: pair.key, amount: pair.value, percent: total > 0 ? (pair.value / total) * 100 : 0, color: palette[idx % palette.count])
            }.sorted { $0.amount > $1.amount }
        }
        return [
            CategorySlice(name: "Food & Dining",  amount: 32_450, percent: 26.9, color: palette[0]),
            CategorySlice(name: "Shopping",        amount: 22_300, percent: 18.5, color: palette[1]),
            CategorySlice(name: "Fuel",            amount: 18_650, percent: 15.5, color: palette[2]),
            CategorySlice(name: "Utilities",       amount: 12_450, percent: 10.3, color: palette[3]),
            CategorySlice(name: "Entertainment",   amount: 8_900,  percent: 7.4,  color: palette[4]),
            CategorySlice(name: "Travel",          amount: 7_850,  percent: 6.5,  color: palette[5]),
            CategorySlice(name: "Others",          amount: 17_840, percent: 14.9, color: palette[6])
        ]
    }

    struct MerchantItem: Identifiable {
        var id: String { name }
        let name: String; let amount: Double; let percent: Double; let icon: String
    }

    private let topMerchants: [MerchantItem] = [
        MerchantItem(name: "Amazon",     amount: 12_450, percent: 10.3, icon: "cart.fill"),
        MerchantItem(name: "Zomato",     amount: 7_890,  percent: 6.5,  icon: "fork.knife"),
        MerchantItem(name: "Reliance BP",amount: 6_250,  percent: 5.2,  icon: "fuelpump.fill"),
        MerchantItem(name: "Swiggy",     amount: 5_430,  percent: 4.5,  icon: "bag.fill"),
        MerchantItem(name: "DMart",      amount: 4_980,  percent: 4.1,  icon: "storefront.fill")
    ]

    struct TrendPoint: Identifiable {
        var id: String { label }
        let label: String; let value: Double
    }

    private let trendPoints: [TrendPoint] = [
        TrendPoint(label: "1 May",  value: 2_100),
        TrendPoint(label: "8 May",  value: 3_400),
        TrendPoint(label: "15 May", value: 4_520),
        TrendPoint(label: "22 May", value: 2_800),
        TrendPoint(label: "31 May", value: 3_200)
    ]

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
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.appGreen)
                    Text("That's 8.5% less than last month.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
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
                Button { } label: {
                    HStack(spacing: 2) {
                        Text("4 New Insights")
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
                HStack(spacing: 12) {
                    keyInsightCard(
                        icon: "arrow.down.circle.fill",
                        iconColor: Color.appGreen,
                        iconBg: Color.appGreen.opacity(0.12),
                        boldText: "8.5% less",
                        boldColor: Color.appGreen,
                        description: "than last month",
                        accentLineColor: Color.appGreen
                    )
                    keyInsightCard(
                        icon: "exclamationmark.circle.fill",
                        iconColor: Color.appWarningAmber,
                        iconBg: Color.appWarningAmber.opacity(0.12),
                        boldText: "Food & Dining",
                        boldColor: Color.appWarningAmber,
                        description: "is your highest expense category",
                        accentLineColor: Color.appWarningAmber
                    )
                    keyInsightCard(
                        icon: "calendar.badge.plus",
                        iconColor: Color.appIndigo,
                        iconBg: Color.appIndigo.opacity(0.12),
                        boldText: "12 more",
                        boldColor: Color.appIndigo,
                        description: "transactions than last month",
                        accentLineColor: Color.appIndigo
                    )
                    keyInsightCard(
                        icon: "bolt.fill",
                        iconColor: Color(red: 59/255, green: 130/255, blue: 246/255),
                        iconBg: Color(red: 59/255, green: 130/255, blue: 246/255).opacity(0.12),
                        boldText: "18%",
                        boldColor: Color(red: 59/255, green: 130/255, blue: 246/255),
                        description: "Utilities spending increased by",
                        accentLineColor: Color(red: 59/255, green: 130/255, blue: 246/255)
                    )
                }
                .padding(.vertical, 2)
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

                VStack(spacing: 10) {
                    ForEach(topMerchants) { m in
                        HStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(Color.appGreen.opacity(0.10))
                                    .frame(width: 32, height: 32)
                                Image(systemName: m.icon)
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
                            Text("\(String(format: "%.1f", m.percent))%")
                                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
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
                    Text("₹3,885")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }

                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.appGreen)
                    Text("6.4%")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.appGreen)
                    Text("vs last month")
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }

                // Mini area chart
                GeometryReader { geo in
                    let pts = trendPoints
                    let maxV = pts.map(\.value).max() ?? 1
                    let w = geo.size.width
                    let h = geo.size.height
                    let stepX = w / CGFloat(pts.count - 1)

                    Path { path in
                        for (i, pt) in pts.enumerated() {
                            let x = CGFloat(i) * stepX
                            let y = h - CGFloat(pt.value / maxV) * h
                            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                            else { path.addLine(to: CGPoint(x: x, y: y)) }
                        }
                    }
                    .stroke(Color.appGreen, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                    Path { path in
                        for (i, pt) in pts.enumerated() {
                            let x = CGFloat(i) * stepX
                            let y = h - CGFloat(pt.value / maxV) * h
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
                    ForEach(["1", "8", "15", "22", "31"], id: \.self) { label in
                        Text(label)
                            .font(.system(size: 9.5, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                        if label != "31" { Spacer() }
                    }
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

    private var personalizedInsightCard: some View {
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
                // Coffee icon
                ZStack {
                    Circle()
                        .fill(Color.appWarningAmber.opacity(0.12))
                        .frame(width: 56, height: 56)
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.appWarningAmber)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("You spent ₹4,350 on cafes this month.")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("That's 21% of your Food & Dining spending. Consider setting a budget to save more!")
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

            // Carousel dots
            HStack(spacing: 6) {
                Spacer()
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .fill(i == 0 ? Color.appGreen : Color.primary.opacity(0.15))
                        .frame(width: i == 0 ? 10 : 6, height: 6)
                }
                Spacer()
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
    }

    // MARK: - Bottom Stats Bar

    private var bottomStatsBar: some View {
        HStack(spacing: 0) {
            bottomStatItem(icon: "arrow.up.circle.fill", iconColor: Color.appExpenseRed, title: "Highest Expense", value: "₹8,560", sub: "May 12")
            Divider().frame(height: 44)
            bottomStatItem(icon: "arrow.down.circle.fill", iconColor: Color.appGreen, title: "Lowest Expense", value: "₹45", sub: "May 5")
            Divider().frame(height: 44)
            bottomStatItem(icon: "list.bullet.rectangle.fill", iconColor: Color.appIndigo, title: "Total Transactions", value: "42", sub: "+12 vs last month")
            Divider().frame(height: 44)
            bottomStatItem(icon: "banknote.fill", iconColor: Color.appWarningAmber, title: "Money Saved", value: "₹10,240", sub: "So far this month")
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

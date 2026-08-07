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
                Text("May Report")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text("May 1 – May 31, 2025")
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
                amount: "₹1,20,440",
                comparison: "↑ 12.5% vs Apr",
                comparisonColor: Color.appGreen
            )

            // Card 2: Total Expenses
            metricCard(
                icon: "creditcard.fill",
                iconColor: Color.appExpenseRed,
                bgColor: Color.appExpenseRed.opacity(0.12),
                title: "Total Expenses",
                amount: "₹99,560",
                comparison: "↑ 8.5% vs Apr",
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

                    Text("₹20,880")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                VStack(alignment: .leading, spacing: 0) {
                    Text("Savings Rate")
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)

                    Text("17.4%")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 5, x: 0, y: 2)
        }
    }

    @ViewBuilder
    private func metricCard(icon: String, iconColor: Color, bgColor: Color, title: String, amount: String, comparison: String, comparisonColor: Color) -> some View {
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

            Text(comparison)
                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                .foregroundColor(comparisonColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .background(Color.white)
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
                        gridLine(label: "₹25K")
                        Spacer()
                        gridLine(label: "₹20K")
                        Spacer()
                        gridLine(label: "₹15K")
                        Spacer()
                        gridLine(label: "₹10K")
                        Spacer()
                        gridLine(label: "₹5K")
                        Spacer()
                        gridLine(label: "₹0")
                    }

                    // Income Gradient & Line (Green)
                    curvePath(points: incomePoints, height: height, closeToBottom: true)
                        .fill(LinearGradient(colors: [Color.appGreen.opacity(0.18), Color.appGreen.opacity(0.01)], startPoint: .top, endPoint: .bottom))

                    curvePath(points: incomePoints, height: height, closeToBottom: false)
                        .stroke(Color.appGreen, lineWidth: 2.2)

                    ForEach(0..<incomePoints.count, id: \.self) { idx in
                        Circle().fill(Color.white).frame(width: 6, height: 6)
                            .overlay(Circle().stroke(Color.appGreen, lineWidth: 2))
                            .position(incomePoints[idx])
                    }

                    // Expense Gradient & Line (Red)
                    curvePath(points: expensePoints, height: height, closeToBottom: true)
                        .fill(LinearGradient(colors: [Color.red.opacity(0.12), Color.red.opacity(0.01)], startPoint: .top, endPoint: .bottom))

                    curvePath(points: expensePoints, height: height, closeToBottom: false)
                        .stroke(Color.appExpenseRed, lineWidth: 2.2)

                    ForEach(0..<expensePoints.count, id: \.self) { idx in
                        Circle().fill(Color.white).frame(width: 6, height: 6)
                            .overlay(Circle().stroke(Color.appExpenseRed, lineWidth: 2))
                            .position(expensePoints[idx])
                    }
                }
            }
            .frame(height: 150)

            // X-Axis Labels
            HStack {
                Text("May 1").frame(maxWidth: .infinity)
                Text("May 8").frame(maxWidth: .infinity)
                Text("May 15").frame(maxWidth: .infinity)
                Text("May 22").frame(maxWidth: .infinity)
                Text("May 29").frame(maxWidth: .infinity)
            }
            .font(.system(size: 9.5, weight: .medium, design: .rounded))
            .foregroundColor(.secondary)
            // Same 32pt gutter as the curve above, so the date labels line up under the
            // points they actually correspond to instead of drifting 4pt out of register.
            .padding(.leading, 32)
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    // Fractional x/y positions for the two curves — invented to draw a plausible-looking
    // trend rather than derived from real weekly sums, but kept as named constants (not
    // inline in the view body) so the type-checker isn't asked to solve the whole chart,
    // gutter offset included, as one expression.
    private let incomeFractionsY: [CGFloat] = [0.35, 0.20, 0.32, 0.10, 0.24, 0.40, 0.22]
    private let expenseFractionsY: [CGFloat] = [0.60, 0.48, 0.54, 0.42, 0.46, 0.52, 0.40]
    private let trendFractionsX: [CGFloat] = [0.05, 0.20, 0.35, 0.50, 0.65, 0.80, 0.95]

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
            if closeToBottom { path.move(to: CGPoint(x: points[0].x, y: height)) }
            path.move(to: points[0])
            for i in 1..<points.count {
                let prev = points[i-1]
                let current = points[i]
                let control1 = CGPoint(x: (prev.x + current.x) / 2, y: prev.y)
                let control2 = CGPoint(x: (prev.x + current.x) / 2, y: current.y)
                path.addCurve(to: current, control1: control1, control2: control2)
            }
            if closeToBottom {
                path.addLine(to: CGPoint(x: points.last!.x, y: height))
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

                VStack(alignment: .center, spacing: 10) {
                    // Donut Chart
                    ZStack {
                        Circle()
                            .stroke(Color.appGreen, lineWidth: 10)
                            .frame(width: 68, height: 68)

                        Circle().trim(from: 0.27, to: 0.455)
                            .stroke(Color(red: 59/255, green: 130/255, blue: 246/255), lineWidth: 10)
                            .frame(width: 68, height: 68)

                        Circle().trim(from: 0.455, to: 0.56)
                            .stroke(Color(red: 147/255, green: 51/255, blue: 234/255), lineWidth: 10)
                            .frame(width: 68, height: 68)

                        Circle().trim(from: 0.56, to: 0.635)
                            .stroke(Color(red: 249/255, green: 115/255, blue: 22/255), lineWidth: 10)
                            .frame(width: 68, height: 68)

                        Circle().trim(from: 0.635, to: 0.706)
                            .stroke(Color.appExpenseRed, lineWidth: 10)
                            .frame(width: 68, height: 68)

                        Circle().trim(from: 0.706, to: 1.0)
                            .stroke(Color.gray.opacity(0.55), lineWidth: 10)
                            .frame(width: 68, height: 68)

                        VStack(spacing: 0) {
                            Text("Total")
                                .font(.system(size: 8.5, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)

                            Text("₹99,560")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(width: 46)
                    }

                    // Legend Column
                    VStack(spacing: 6) {
                        categoryLegend(color: Color.appGreen, name: "Food & Dining", percent: "26.9%")
                        categoryLegend(color: Color(red: 59/255, green: 130/255, blue: 246/255), name: "Shopping", percent: "18.5%")
                        categoryLegend(color: Color(red: 147/255, green: 51/255, blue: 234/255), name: "Utilities", percent: "10.3%")
                        categoryLegend(color: Color(red: 249/255, green: 115/255, blue: 22/255), name: "Transport", percent: "7.4%")
                        categoryLegend(color: Color.appExpenseRed, name: "Entertainment", percent: "7.1%")
                        categoryLegend(color: Color.gray.opacity(0.6), name: "Others", percent: "14.8%")
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 240)
            .background(Color.white)
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

                VStack(spacing: 6) {
                    merchantRow(name: "DMart", amount: "₹12,450", percent: "12.5%", avatarType: .dmart)
                    merchantRow(name: "Zomato", amount: "₹7,890", percent: "7.9%", avatarType: .zomato)
                    merchantRow(name: "Amazon", amount: "₹6,450", percent: "6.5%", avatarType: .amazon)
                    merchantRow(name: "HP Petrol Pump", amount: "₹4,330", percent: "4.4%", avatarType: .fuel)
                    merchantRow(name: "Others", amount: "₹12,430", percent: "12.5%", avatarType: .others)
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 240)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 5, x: 0, y: 2)
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

    enum MerchantAvatar {
        case dmart, zomato, amazon, fuel, others
    }

    @ViewBuilder
    private func merchantRow(name: String, amount: String, percent: String, avatarType: MerchantAvatar) -> some View {
        HStack(spacing: 6) {
            Group {
                switch avatarType {
                case .dmart:
                    Circle().fill(Color.appGreen.opacity(0.12)).frame(width: 20, height: 20)
                        .overlay(Text("D").font(.system(size: 9, weight: .black, design: .rounded)).foregroundColor(Color.appGreenDeep))
                case .zomato:
                    Circle().fill(Color.appExpenseRed.opacity(0.12)).frame(width: 20, height: 20)
                        .overlay(Text("z").font(.system(size: 9, weight: .black, design: .rounded)).foregroundColor(.red))
                case .amazon:
                    Circle().fill(Color.orange.opacity(0.14)).frame(width: 20, height: 20)
                        .overlay(Text("a").font(.system(size: 11, weight: .black, design: .serif)).foregroundColor(.orange))
                case .fuel:
                    Circle().fill(Color(red: 224/255, green: 242/255, blue: 254/255)).frame(width: 20, height: 20)
                        .overlay(Image(systemName: "fuelpump.fill").font(.system(size: 9, weight: .bold)).foregroundColor(.blue))
                case .others:
                    Circle().fill(Color(red: 239/255, green: 246/255, blue: 255/255)).frame(width: 20, height: 20)
                        .overlay(Image(systemName: "ellipsis").font(.system(size: 9, weight: .bold)).foregroundColor(.blue))
                }
            }

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
                    mainText: "Food & Dining",
                    detailText: "₹32,450 (26.9%)",
                    detailColor: Color.appGreen
                )

                // Card 2: Highest Expense
                insightCard(
                    icon: "creditcard.fill",
                    iconColor: Color(red: 249/255, green: 115/255, blue: 22/255),
                    bgColor: Color(red: 254/255, green: 243/255, blue: 235/255),
                    header: "Highest Expense",
                    mainText: "₹12,450",
                    detailText: "at DMart",
                    detailColor: .secondary
                )

                // Card 3: Top Saving Category
                insightCard(
                    icon: "percent",
                    iconColor: Color.appGreen,
                    bgColor: Color.appGreen.opacity(0.12),
                    header: "Top Saving Category",
                    mainText: "Entertainment",
                    detailText: "7.1% less than Apr",
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
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 5, x: 0, y: 2)
    }

    // MARK: - 6. Spending Summary Section (2 Columns with Progress Bars)
    private var spendingSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spending Summary")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            HStack(alignment: .top, spacing: 14) {
                // Left Column
                VStack(spacing: 12) {
                    summaryCategoryRow(
                        icon: "bag.fill",
                        bgColor: Color.appGreen.opacity(0.12),
                        iconColor: Color.appGreenDeep,
                        name: "Food & Dining",
                        amountText: "₹32,450 (26.9%)",
                        progressColor: Color.appGreen,
                        ratio: 0.8
                    )

                    summaryCategoryRow(
                        icon: "cart.fill",
                        bgColor: Color(red: 239/255, green: 246/255, blue: 255/255),
                        iconColor: Color(red: 37/255, green: 99/255, blue: 235/255),
                        name: "Shopping",
                        amountText: "₹22,300 (18.8%)",
                        progressColor: Color(red: 37/255, green: 99/255, blue: 235/255),
                        ratio: 0.6
                    )

                    summaryCategoryRow(
                        icon: "star.fill",
                        bgColor: Color.appExpenseRed.opacity(0.12),
                        iconColor: Color.appExpenseRed,
                        name: "Entertainment",
                        amountText: "₹8,560 (7.1%)",
                        progressColor: Color.appExpenseRed,
                        ratio: 0.35
                    )
                }
                .frame(maxWidth: .infinity)

                // Right Column
                VStack(spacing: 12) {
                    summaryCategoryRow(
                        icon: "bolt.fill",
                        bgColor: Color(red: 243/255, green: 232/255, blue: 255/255),
                        iconColor: Color(red: 147/255, green: 51/255, blue: 234/255),
                        name: "Utilities",
                        amountText: "₹12,450 (10.3%)",
                        progressColor: Color(red: 147/255, green: 51/255, blue: 234/255),
                        ratio: 0.45
                    )

                    summaryCategoryRow(
                        icon: "bus.fill",
                        bgColor: Color(red: 254/255, green: 243/255, blue: 235/255),
                        iconColor: Color(red: 249/255, green: 115/255, blue: 22/255),
                        name: "Transport",
                        amountText: "₹8,900 (7.4%)",
                        progressColor: Color(red: 249/255, green: 115/255, blue: 22/255),
                        ratio: 0.35
                    )

                    summaryCategoryRow(
                        icon: "ellipsis",
                        bgColor: Color.gray.opacity(0.12),
                        iconColor: .gray,
                        name: "Others",
                        amountText: "₹17,780 (14.8%)",
                        progressColor: .gray,
                        ratio: 0.5
                    )
                }
                .frame(maxWidth: .infinity)
            }
            .padding(14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
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

                Text("• You spent ₹8,560 more on Food & Dining compared to last month.")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)

                Text("• Entertainment spending has decreased by 12.6%.")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
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
        let pdfMetaData = [
            kCGPDFContextCreator: "PiggyFlow",
            kCGPDFContextAuthor: "PiggyFlow User",
            kCGPDFContextTitle: "Financial Report - May 2025"
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let data = renderer.pdfData { context in
            context.beginPage()
            var y: CGFloat = 40
            "PiggyFlow Financial Report - May 2025".draw(at: CGPoint(x: 40, y: y), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 22)])
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

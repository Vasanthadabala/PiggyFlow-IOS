import SwiftUI
import SwiftData
import UIKit

struct ReportsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query private var expenses: [Expense]
    @Query private var incomes: [Income]

    @State private var selectedPeriod: PeriodFilter = .custom
    @State private var selectedDateRangeText: String = "May 1 – May 31, 2025"
    @State private var showShareSheet: Bool = false
    @State private var pdfURLToShare: URL? = nil
    @State private var selectedReportType: String? = nil

    enum PeriodFilter: String, CaseIterable, Identifiable {
        case custom = "Custom"
        case thisMonth = "This Month"
        case lastMonth = "Last Month"
        case thisYear = "This Year"
        case allTime = "All Time"

        var id: String { rawValue }
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
                        VStack(spacing: 20) {
                            // 2. Period Filter Tabs
                            periodFilterTabs

                            // 3. Date Range Banner
                            dateRangeBanner

                            // 4. Choose Report Type (3x3 Grid of 9 Cards)
                            chooseReportTypeSection

                            // 5. Saved Reports Section
                            savedReportsSection

                            // 6. Reports Insights Section
                            reportsInsightsSection

                            // 7. Export Reports Section (PDF, Excel, CSV Pills)
                            exportReportsSection
                        }
                        .padding(.horizontal, 16)
                    }
                    .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 96) }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let pdfURL = pdfURLToShare {
                    ActivityViewController(activityItems: [pdfURL])
                }
            }
        }
    }

    // MARK: - 1. Top Header Bar
    private var headerBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Reports")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(Color.appGreenDeep)

                Text("Generate detailed reports and export your data")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 16) {
                // History Action
                Button {
                    Haptics.light()
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "clock")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color.appGreenDeep)
                            .frame(width: 36, height: 36)
                            .background(Color.appGreen.opacity(0.12))
                            .clipShape(Circle())
                        Text("History")
                            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                            .foregroundColor(Color.appGreenDeep)
                    }
                }
                .buttonStyle(.plain)

                // Settings Action
                Button {
                    Haptics.light()
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color.appGreenDeep)
                            .frame(width: 36, height: 36)
                            .background(Color.appGreen.opacity(0.12))
                            .clipShape(Circle())
                        Text("Settings")
                            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                            .foregroundColor(Color.appGreenDeep)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 2. Period Filter Tabs
    private var periodFilterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(PeriodFilter.allCases) { period in
                    Button {
                        Haptics.light()
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            selectedPeriod = period
                        }
                    } label: {
                        HStack(spacing: 5) {
                            if period == .custom {
                                Image(systemName: "calendar")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            Text(period.rawValue)
                                .font(.system(size: 12.5, weight: selectedPeriod == period ? .bold : .medium, design: .rounded))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .foregroundColor(selectedPeriod == period ? .white : .secondary)
                        .background(
                            Capsule()
                                .fill(selectedPeriod == period ? Color.appGreenDeep : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(
                Capsule()
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
            )
        }
    }

    // MARK: - 3. Date Range Banner
    private var dateRangeBanner: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.appGreen.opacity(0.14))
                .frame(width: 38, height: 38)
                .overlay(
                    Image(systemName: "calendar")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.appGreen)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("Date Range")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)

                HStack(spacing: 4) {
                    Text(selectedDateRangeText)
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                }
            }

            Spacer(minLength: 6)

            Button {
                Haptics.light()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 12, weight: .bold))
                    Text("Edit Range")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .fixedSize()
                }
                .foregroundColor(Color.appGreenDeep)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.appGreen.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
    }

    // MARK: - 4. Choose Report Type (3x3 Grid of 9 Cards)
    private var chooseReportTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Choose Report Type")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Spacer()

                Button {
                    Haptics.light()
                } label: {
                    HStack(spacing: 2) {
                        Text("View All")
                            .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.appGreen)
                }
                .buttonStyle(.plain)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                reportTypeCard(
                    icon: "chart.pie",
                    iconColor: Color.appGreen,
                    bgColor: Color.appGreen.opacity(0.12),
                    title: "Overview Report",
                    description: "Income, expenses & savings summary"
                )

                reportTypeCard(
                    icon: "chart.bar.fill",
                    iconColor: Color(red: 249/255, green: 115/255, blue: 22/255),
                    bgColor: Color(red: 254/255, green: 243/255, blue: 235/255),
                    title: "Category Report",
                    description: "Spending breakdown by categories"
                )

                reportTypeCard(
                    icon: "bag.fill",
                    iconColor: Color(red: 147/255, green: 51/255, blue: 234/255),
                    bgColor: Color(red: 243/255, green: 232/255, blue: 255/255),
                    title: "Merchant Report",
                    description: "Spending breakdown by merchants"
                )

                reportTypeCard(
                    icon: "wallet.pass.fill",
                    iconColor: Color(red: 37/255, green: 99/255, blue: 235/255),
                    bgColor: Color(red: 239/255, green: 246/255, blue: 255/255),
                    title: "Income Report",
                    description: "All income sources and summary"
                )

                reportTypeCard(
                    icon: "creditcard.fill",
                    iconColor: Color.appExpenseRed,
                    bgColor: Color.appExpenseRed.opacity(0.12),
                    title: "Expense Report",
                    description: "All expenses details"
                )

                reportTypeCard(
                    icon: "calendar",
                    iconColor: Color(red: 217/255, green: 119/255, blue: 6/255),
                    bgColor: Color(red: 254/255, green: 249/255, blue: 231/255),
                    title: "Budget Report",
                    description: "Budget vs actual comparison"
                )

                reportTypeCard(
                    icon: "arrow.triangle.2.circlepath",
                    iconColor: Color(red: 13/255, green: 148/255, blue: 136/255),
                    bgColor: Color(red: 204/255, green: 251/255, blue: 241/255),
                    title: "Subscription Report",
                    description: "All subscriptions and payments"
                )

                reportTypeCard(
                    icon: "house.fill",
                    iconColor: Color(red: 37/255, green: 99/255, blue: 235/255),
                    bgColor: Color(red: 239/255, green: 246/255, blue: 255/255),
                    title: "EMI Report",
                    description: "All loan EMI payments"
                )

                reportTypeCard(
                    icon: "chart.line.uptrend.xyaxis",
                    iconColor: Color(red: 147/255, green: 51/255, blue: 234/255),
                    bgColor: Color(red: 243/255, green: 232/255, blue: 255/255),
                    title: "Cash Flow Report",
                    description: "Money in vs money out"
                )
            }
        }
    }

    @ViewBuilder
    private func reportTypeCard(icon: String, iconColor: Color, bgColor: Color, title: String, description: String) -> some View {
        NavigationLink(destination: ReportDetailView().hidesTabBarOnPush()) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(iconColor)

                // Titles like "Subscription Report" / "Cash Flow Report" don't fit a third
                // of the row on one line, so allow two rather than truncating them.
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)

                Text(description)
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.leading)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
            .background(bgColor.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 5. Saved Reports Section
    private var savedReportsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Saved Reports")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Spacer()

                NavigationLink(destination: ReportDetailView().hidesTabBarOnPush()) {
                    HStack(spacing: 2) {
                        Text("View All")
                            .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.appGreen)
                }
            }

            VStack(spacing: 0) {
                savedReportRow(
                    title: "May Overview Report",
                    subtitle: "May 1 – May 31, 2025  •  Overview Report",
                    dateText: "Generated on May 31, 2025",
                    icon: "chart.pie.fill",
                    iconColor: Color.appGreen,
                    bgColor: Color.appGreen.opacity(0.12)
                )

                Divider().padding(.leading, 64)

                savedReportRow(
                    title: "Q2 Category Report",
                    subtitle: "Apr 1 – Jun 30, 2025  •  Category Report",
                    dateText: "Generated on May 30, 2025",
                    icon: "cart.fill",
                    iconColor: Color(red: 249/255, green: 115/255, blue: 22/255),
                    bgColor: Color(red: 254/255, green: 243/255, blue: 235/255)
                )

                Divider().padding(.leading, 64)

                savedReportRow(
                    title: "Top Merchants (This Year)",
                    subtitle: "Jan 1 – Dec 31, 2025  •  Merchant Report",
                    dateText: "Generated on May 28, 2025",
                    icon: "bag.fill",
                    iconColor: Color(red: 147/255, green: 51/255, blue: 234/255),
                    bgColor: Color(red: 243/255, green: 232/255, blue: 255/255)
                )

                Divider().padding(.leading, 64)

                savedReportRow(
                    title: "Income vs Expense (This Month)",
                    subtitle: "May 1 – May 31, 2025  •  Income vs Expense",
                    dateText: "Generated on May 25, 2025",
                    icon: "wallet.pass.fill",
                    iconColor: Color(red: 37/255, green: 99/255, blue: 235/255),
                    bgColor: Color(red: 239/255, green: 246/255, blue: 255/255)
                )
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
        }
    }

    @ViewBuilder
    private func savedReportRow(title: String, subtitle: String, dateText: String, icon: String, iconColor: Color, bgColor: Color) -> some View {
        NavigationLink(destination: ReportDetailView().hidesTabBarOnPush()) {
            HStack(spacing: 12) {
                Circle()
                    .fill(bgColor)
                    .frame(width: 38, height: 38)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(iconColor)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(dateText)
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.8))

                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.6))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 6. Reports Insights Section
    private var reportsInsightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.appGreen.opacity(0.16))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.appGreen)
                    )

                Text("Reports Insights")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }

            HStack(spacing: 0) {
                // Column 1: Highest spending category
                VStack(alignment: .leading, spacing: 4) {
                    Text("Highest spending category")
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Food & Dining")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Text("₹32,450 (26.9%)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(Color.appGreen)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 6)

                Rectangle()
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 1, height: 48)

                // Column 2: Total spent this month
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total spent this month")
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("₹1,20,440")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Text("↑ 8.5% vs Apr 1 – Apr 30")
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 225/255, green: 29/255, blue: 72/255))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 6)

                Rectangle()
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 1, height: 48)

                // Column 3: Savings this month
                VStack(alignment: .leading, spacing: 4) {
                    Text("Savings this month")
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("₹64,560")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Text("↑ 32.1% vs Apr 1 – Apr 30")
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundColor(Color.appGreen)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 6)
            }
            .padding(.vertical, 14)
            .background(Color.appGreen.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    // MARK: - 7. Export Reports Section (PDF, Excel, CSV Pills)
    private var exportReportsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Export Reports")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            // Format buttons sit on their own row: sharing one HStack with the description
            // left them ~40pt each, so "PDF"/"Excel"/"CSV" wrapped one letter per line.
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color.appGreen.opacity(0.14))
                        .frame(width: 38, height: 38)
                        .overlay(
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.appGreen)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Export your reports in multiple formats")
                            .font(.system(size: 12.5, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("PDF, Excel or CSV")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }

                    Spacer(minLength: 0)
                }

                HStack(spacing: 8) {
                    exportFormatButton(icon: "doc.text.fill", title: "PDF", tint: .red)
                    exportFormatButton(icon: "tablecells.fill", title: "Excel", tint: Color.appGreenDeep)
                    exportFormatButton(icon: "doc.plaintext.fill", title: "CSV", tint: Color(red: 37/255, green: 99/255, blue: 235/255))
                }
            }
            .padding(14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
    }

    @ViewBuilder
    private func exportFormatButton(icon: String, title: String, tint: Color) -> some View {
        Button {
            Haptics.medium()
            exportPDFReport()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .fixedSize()
            }
            .foregroundColor(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(tint.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
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

struct ActivityViewController: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ReportsView()
}

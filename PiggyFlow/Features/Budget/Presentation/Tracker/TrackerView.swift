import SwiftUI
import SwiftData

struct TrackerView: View {
    @Environment(\.modelContext) private var context
    @Query private var trackerRecords: [TrackerRecord]
    @Query private var expenses: [Expense]

    @State private var selectedTab: TrackerTab = .overview
    @State private var selectedDateRange: String = "May 1 – May 31, 2025"
    @State private var showAddExpenseSheet: Bool = false
    @State private var showAddTrackerSheet: Bool = false
    /// Which tab the Add Tracker sheet opens on — set by whichever control presented it.
    @State private var addTrackerKind: TrackerKind = .budget

    enum TrackerTab: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case budgets = "Budgets"
        case subscriptions = "Subscriptions"
        case emis = "EMIs"
        case goals = "Goals"

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

                            // 7. Quick Add Action Pills Section
                            quickAddSection
                        }
                        .padding(.horizontal, 16)
                    }
                    .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 96) }
                }
            }
            // Full screen rather than a sheet: the chooser grid now carries a proper header and
            // fills the page, not a half-height card.
            .fullScreenCover(isPresented: $showAddExpenseSheet) {
                AddExpenseBottomSheetView(itemToEdit: nil)
            }
            // Full screen rather than a sheet, for the same reason as Add Expense/Add Income:
            // AddTrackerView carries its own header and action bar sized for the whole screen.
            .fullScreenCover(isPresented: $showAddTrackerSheet) {
                NavigationStack {
                    AddTrackerView(initialKind: addTrackerKind)
                }
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
                // Add Tracker Button
                Button {
                    Haptics.light()
                    addTrackerKind = .budget
                    showAddTrackerSheet = true
                } label: {
                    Image(systemName: AppIcon.Action.add)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color.appGreenDeep)
                        .frame(width: 40, height: 40)
                        .background(Color.appGreen.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

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
                    .fill(Color.white)
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

                    HStack(spacing: 4) {
                        Text(selectedDateRange)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                    }
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
                    Text("₹1,20,440")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("55% of ₹2,20,000")
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
                    Text("₹99,560")
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
                    Text("₹3,885")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("of ₹7,097")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
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
                        .frame(width: geo.size.width * 0.55, height: 8)
                }
            }
            .frame(height: 8)

            // Insight Callout Banner
            NavigationLink(destination: FinancialInsightsView().hidesTabBarOnPush()) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.appGreen.opacity(0.16))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.appGreen)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("You're on track!")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Text("You're spending ₹8,560 less than your planned budget.")
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
        .padding(16)
        .background(Color.white)
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

            VStack(spacing: 0) {
                paymentRow(
                    title: "Netflix Subscription",
                    dueDate: "Jun 1, 2025  •  Subscription",
                    amount: "₹649.00",
                    dueText: "Tomorrow",
                    avatar: .netflix
                )

                Divider().padding(.leading, 64)

                paymentRow(
                    title: "Citi Credit Card Bill",
                    dueDate: "Jun 5, 2025  •  Credit Card",
                    amount: "₹4,250.00",
                    dueText: "In 4 days",
                    avatar: .citi
                )

                Divider().padding(.leading, 64)

                paymentRow(
                    title: "Electricity Bill",
                    dueDate: "Jun 10, 2025  •  Utilities",
                    amount: "₹1,240.00",
                    dueText: "In 9 days",
                    avatar: .electricity
                )

                Divider().padding(.leading, 64)

                paymentRow(
                    title: "Home Loan EMI",
                    dueDate: "Jun 15, 2025  •  Loan",
                    amount: "₹18,500.00",
                    dueText: "In 14 days",
                    avatar: .homeLoan
                )
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
        }
    }

    enum PaymentAvatar {
        case netflix, citi, electricity, homeLoan
    }

    @ViewBuilder
    private func paymentRow(title: String, dueDate: String, amount: String, dueText: String, avatar: PaymentAvatar) -> some View {
        NavigationLink(destination: UpcomingPaymentsView().hidesTabBarOnPush()) {
            HStack(spacing: 12) {
                Group {
                    switch avatar {
                    case .netflix:
                        Circle()
                            .fill(Color(red: 200/255, green: 30/255, blue: 30/255))
                            .frame(width: 42, height: 42)
                            .overlay(
                                Text("N")
                                    .font(.system(size: 18, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                            )
                    case .citi:
                        Circle()
                            .fill(Color(red: 0/255, green: 75/255, blue: 145/255))
                            .frame(width: 42, height: 42)
                            .overlay(
                                Text("citi")
                                    .font(.system(size: 11, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                            )
                    case .electricity:
                        Circle()
                            .fill(Color(red: 220/255, green: 245/255, blue: 225/255))
                            .frame(width: 42, height: 42)
                            .overlay(
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(.appGreen)
                            )
                    case .homeLoan:
                        Circle()
                            .fill(Color.orange.opacity(0.15))
                            .frame(width: 42, height: 42)
                            .overlay(
                                Image(systemName: "building.2.fill")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(.orange)
                            )
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Text(dueDate)
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }

                Spacer()

                HStack(spacing: 6) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(amount)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)

                        Text(dueText)
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

            // Donut sits above the breakdown rather than beside it: side-by-side left the
            // rows ~185pt for ~245pt of content, so every amount and percent wrapped
            // vertically one character at a time.
            VStack(spacing: 18) {
                // Multi-color Donut Ring
                ZStack {
                    Circle()
                        .stroke(Color.appGreen, lineWidth: 14)
                        .frame(width: 110, height: 110)

                    Circle()
                        .trim(from: 0.25, to: 0.44)
                        .stroke(Color(red: 59/255, green: 130/255, blue: 246/255), lineWidth: 14)
                        .frame(width: 110, height: 110)

                    Circle()
                        .trim(from: 0.44, to: 0.58)
                        .stroke(Color(red: 147/255, green: 51/255, blue: 234/255), lineWidth: 14)
                        .frame(width: 110, height: 110)

                    Circle()
                        .trim(from: 0.58, to: 0.70)
                        .stroke(Color(red: 249/255, green: 115/255, blue: 22/255), lineWidth: 14)
                        .frame(width: 110, height: 110)

                    Circle()
                        .trim(from: 0.70, to: 0.85)
                        .stroke(Color(red: 239/255, green: 68/255, blue: 68/255), lineWidth: 14)
                        .frame(width: 110, height: 110)

                    Circle()
                        .trim(from: 0.85, to: 1.0)
                        .stroke(Color.gray.opacity(0.35), lineWidth: 14)
                        .frame(width: 110, height: 110)

                    VStack(spacing: 1) {
                        Text("55%")
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
                    budgetRow(color: Color.appGreen, category: "Food & Dining", amount: "₹32,450", percent: "54%", ratio: 0.54)
                    budgetRow(color: Color(red: 59/255, green: 130/255, blue: 246/255), category: "Shopping", amount: "₹22,300", percent: "62%", ratio: 0.62)
                    budgetRow(color: Color(red: 147/255, green: 51/255, blue: 234/255), category: "Utilities", amount: "₹12,450", percent: "49%", ratio: 0.49)
                    budgetRow(color: Color(red: 249/255, green: 115/255, blue: 22/255), category: "Transport", amount: "₹8,900", percent: "59%", ratio: 0.59)
                    budgetRow(color: Color(red: 239/255, green: 68/255, blue: 68/255), category: "Entertainment", amount: "₹8,560", percent: "71%", ratio: 0.71)
                    budgetRow(color: Color.gray.opacity(0.6), category: "Others", amount: "₹17,780", percent: "48%", ratio: 0.48)
                }
            }
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
        }
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

                NavigationLink(destination: ReportsView().hidesTabBarOnPush()) {
                    Text("View All")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.appGreen)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    goalCard(
                        title: "Goa Trip",
                        savedInfo: "₹25,000 of ₹50,000",
                        percentage: 0.50,
                        percentText: "50%",
                        color: Color.appGreen,
                        bgColor: Color(red: 232/255, green: 247/255, blue: 238/255),
                        icon: "tree.fill"
                    )

                    goalCard(
                        title: "New Phone",
                        savedInfo: "₹18,000 of ₹60,000",
                        percentage: 0.30,
                        percentText: "30%",
                        color: Color(red: 249/255, green: 115/255, blue: 22/255),
                        bgColor: Color(red: 254/255, green: 243/255, blue: 235/255),
                        icon: "iphone"
                    )

                    goalCard(
                        title: "Emergency Fund",
                        savedInfo: "₹40,000 of ₹1,00,000",
                        percentage: 0.40,
                        percentText: "40%",
                        color: Color(red: 147/255, green: 51/255, blue: 234/255),
                        bgColor: Color(red: 243/255, green: 232/255, blue: 255/255),
                        icon: "shield.fill"
                    )
                }
                .padding(.vertical, 2)
            }
        }
    }

    @ViewBuilder
    private func goalCard(title: String, savedInfo: String, percentage: CGFloat, percentText: String, color: Color, bgColor: Color, icon: String) -> some View {
        NavigationLink(destination: ReportsView().hidesTabBarOnPush()) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(bgColor)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: icon)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(color)
                        )

                    VStack(alignment: .leading, spacing: 1) {
                        Text(title)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Text(savedInfo)
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
                                .fill(color)
                                .frame(width: geo.size.width * percentage, height: 5)
                        }
                    }
                    .frame(height: 5)

                    Text(percentText)
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .foregroundColor(color)
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

    // MARK: - 7. Quick Add Action Pills Section
    private var quickAddSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Add")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    quickAddPill(icon: "doc.text.fill", title: "Add Expense") {
                        showAddExpenseSheet = true
                    }
                    quickAddPill(icon: "creditcard.fill", title: "Add Income") {
                        showAddExpenseSheet = true
                    }
                    quickAddPill(icon: "target", title: "Add Budget") {
                        addTrackerKind = .budget
                        showAddTrackerSheet = true
                    }
                    quickAddPill(icon: "star.circle.fill", title: "Add Goal") {
                        addTrackerKind = .goal
                        showAddTrackerSheet = true
                    }
                    quickAddPill(icon: "repeat.circle.fill", title: "Add Subscription") {
                        addTrackerKind = .subscription
                        showAddTrackerSheet = true
                    }
                    quickAddPill(icon: "building.2.fill", title: "Add EMI / Loan") {
                        addTrackerKind = .emi
                        showAddTrackerSheet = true
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    @ViewBuilder
    private func quickAddPill(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
            .foregroundColor(Color(red: 20/255, green: 90/255, blue: 50/255))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Color.appGreen.opacity(0.12))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    TrackerView()
}

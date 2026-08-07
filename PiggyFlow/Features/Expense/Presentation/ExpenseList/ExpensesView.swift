import SwiftUI
import SwiftData

struct ExpensesView: View {
    @Environment(\.modelContext) private var context
    @Query private var expenses: [Expense]
    @Query private var incomes: [Income]

    @State private var selectedDateRange: String = "May 1 – May 31, 2025"
    @State private var showDatePicker: Bool = false
    @State private var showSearchSheet: Bool = false
    @State private var showFilterSheet: Bool = false
    @State private var activeSheet: ActionSheetType?

    enum ActionSheetType: Identifiable {
        case insights, categories, recurring, export
        var id: Int { hashValue }
    }

    private var totalExpensesAmount: Double {
        !expenses.isEmpty ? expenses.reduce(0) { $0 + $1.price } : 120_440
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
                HStack(spacing: 4) {
                    Text(selectedDateRange)
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)

                // Month-over-Month Comparison Label
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color.appGreen)

                    Text("8.5% less than Apr 1 – Apr 30")
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .foregroundColor(Color.appGreen)
                }
            }

            Spacer(minLength: 4)

            // Right Column: Donut Pie Chart + Center Text
            ZStack {
                // Donut Ring Segments
                Circle()
                    .stroke(Color.appGreen, lineWidth: 11)
                    .frame(width: 98, height: 98)

                Circle()
                    .trim(from: 0.27, to: 0.45)
                    .stroke(Color(red: 132/255, green: 204/255, blue: 22/255), lineWidth: 11)
                    .frame(width: 98, height: 98)

                Circle()
                    .trim(from: 0.45, to: 0.60)
                    .stroke(Color(red: 234/255, green: 179/255, blue: 8/255), lineWidth: 11)
                    .frame(width: 98, height: 98)

                Circle()
                    .trim(from: 0.60, to: 0.70)
                    .stroke(Color(red: 249/255, green: 115/255, blue: 22/255), lineWidth: 11)
                    .frame(width: 98, height: 98)

                Circle()
                    .trim(from: 0.70, to: 0.78)
                    .stroke(Color(red: 236/255, green: 72/255, blue: 153/255), lineWidth: 11)
                    .frame(width: 98, height: 98)

                Circle()
                    .trim(from: 0.78, to: 1.0)
                    .stroke(Color(red: 59/255, green: 130/255, blue: 246/255), lineWidth: 11)
                    .frame(width: 98, height: 98)

                // Center Text inside Donut
                VStack(spacing: 1) {
                    Text("Top Category")
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                    Text("Food & Dining")
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("26.9%")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(Color.appGreen)
                }
                .frame(width: 74)
            }
        }
        .padding(18)
        .background(Color.white)
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

            VStack(spacing: 0) {
                transactionRow(
                    merchantName: "DMart",
                    categoryAndAccount: "Shopping  •  HDFC Bank",
                    timestamp: "May 31, 2025  •  08:45 PM",
                    amount: "-₹1,245.00",
                    avatarType: .dmart
                )

                Divider().padding(.leading, 64)

                transactionRow(
                    merchantName: "Zomato",
                    categoryAndAccount: "Food & Dining  •  HDFC Card",
                    timestamp: "May 30, 2025  •  07:15 PM",
                    amount: "-₹450.00",
                    avatarType: .zomato
                )

                Divider().padding(.leading, 64)

                transactionRow(
                    merchantName: "Amazon",
                    categoryAndAccount: "Shopping  •  HDFC Card",
                    timestamp: "May 29, 2025  •  09:20 PM",
                    amount: "-₹2,199.00",
                    avatarType: .amazon
                )

                Divider().padding(.leading, 64)

                transactionRow(
                    merchantName: "HP Petrol Pump",
                    categoryAndAccount: "Fuel  •  HDFC Bank",
                    timestamp: "May 29, 2025  •  05:40 PM",
                    amount: "-₹330.50",
                    avatarType: .fuel
                )
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
        }
    }

    enum MerchantAvatar {
        case dmart, zomato, amazon, fuel
    }

    @ViewBuilder
    private func transactionRow(merchantName: String, categoryAndAccount: String, timestamp: String, amount: String, avatarType: MerchantAvatar) -> some View {
        NavigationLink(destination: RecentTransactionsView().hidesTabBarOnPush()) {
            HStack(spacing: 12) {
                // Merchant Icon Avatar
                Group {
                    switch avatarType {
                    case .dmart:
                        Circle()
                            .fill(Color(red: 220/255, green: 245/255, blue: 225/255))
                            .frame(width: 42, height: 42)
                            .overlay(
                                Text("DMart")
                                    .font(.system(size: 9.5, weight: .black, design: .rounded))
                                    .foregroundColor(Color(red: 22/255, green: 130/255, blue: 60/255))
                            )
                    case .zomato:
                        Circle()
                            .fill(Color(red: 254/255, green: 226/255, blue: 226/255))
                            .frame(width: 42, height: 42)
                            .overlay(
                                Text("zomato")
                                    .font(.system(size: 9.5, weight: .black, design: .rounded))
                                    .foregroundColor(.red)
                            )
                    case .amazon:
                        Circle()
                            .fill(Color.orange.opacity(0.14))
                            .frame(width: 42, height: 42)
                            .overlay(
                                Text("a")
                                    .font(.system(size: 20, weight: .black, design: .serif))
                                    .foregroundColor(.orange)
                            )
                    case .fuel:
                        Circle()
                            .fill(Color(red: 224/255, green: 242/255, blue: 254/255))
                            .frame(width: 42, height: 42)
                            .overlay(
                                Image(systemName: "fuelpump.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(Color(red: 2/255, green: 132/255, blue: 199/255))
                            )
                    }
                }

                // Middle Info
                VStack(alignment: .leading, spacing: 3) {
                    Text(merchantName)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Text(categoryAndAccount)
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)

                    Text(timestamp)
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.8))
                }

                Spacer()

                // Right Amount & Chevron
                HStack(spacing: 4) {
                    Text(amount)
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

            VStack(alignment: .leading, spacing: 10) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        categoryCard(icon: "fork.knife", iconColor: Color.appGreen, bgColor: Color(red: 232/255, green: 247/255, blue: 238/255), title: "Food & Dining", amount: "₹32,450", percent: "26.9%")
                        categoryCard(icon: "bag.fill", iconColor: Color(red: 147/255, green: 51/255, blue: 234/255), bgColor: Color(red: 243/255, green: 232/255, blue: 255/255), title: "Shopping", amount: "₹22,300", percent: "18.5%")
                        categoryCard(icon: "fuelpump.fill", iconColor: Color(red: 249/255, green: 115/255, blue: 22/255), bgColor: Color(red: 254/255, green: 243/255, blue: 235/255), title: "Fuel", amount: "₹18,650", percent: "15.5%")
                        categoryCard(icon: "bolt.fill", iconColor: Color(red: 234/255, green: 179/255, blue: 8/255), bgColor: Color(red: 254/255, green: 249/255, blue: 231/255), title: "Utilities", amount: "₹12,450", percent: "10.3%")
                        categoryCard(icon: "film.fill", iconColor: Color(red: 236/255, green: 72/255, blue: 153/255), bgColor: Color(red: 252/255, green: 231/255, blue: 243/255), title: "Entertainment", amount: "₹8,900", percent: "7.4%")
                        categoryCard(icon: "ellipsis", iconColor: Color(red: 37/255, green: 99/255, blue: 235/255), bgColor: Color(red: 239/255, green: 246/255, blue: 255/255), title: "Others", amount: "₹25,690", percent: "21.4%")
                    }
                    .padding(.vertical, 2)
                }

                // Custom Green Progress Line Indicator underneath
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 3)
                    Capsule()
                        .fill(Color.appGreen)
                        .frame(width: 80, height: 3)
                }
                .padding(.horizontal, 4)
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
            .background(Color.white)
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

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    merchantCard(name: "Amazon", amount: "₹12,450", percent: "10.3%", avatarType: .amazon)
                    merchantCard(name: "Zomato", amount: "₹7,890", percent: "6.5%", avatarType: .zomato)
                    merchantCard(name: "Reliance BP", amount: "₹6,250", percent: "5.2%", avatarType: .reliance)
                    merchantCard(name: "Swiggy", amount: "₹5,430", percent: "4.5%", avatarType: .swiggy)
                    merchantCard(name: "DMart", amount: "₹4,980", percent: "4.1%", avatarType: .dmart)
                }
                .padding(.vertical, 2)
            }
        }
    }

    enum MerchantCardAvatar {
        case amazon, zomato, reliance, swiggy, dmart
    }

    @ViewBuilder
    private func merchantCard(name: String, amount: String, percent: String, avatarType: MerchantCardAvatar) -> some View {
        NavigationLink(destination: RecentTransactionsView().hidesTabBarOnPush()) {
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Group {
                        switch avatarType {
                        case .amazon:
                            Circle()
                                .fill(Color.orange.opacity(0.14))
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Text("a")
                                        .font(.system(size: 13, weight: .black, design: .serif))
                                        .foregroundColor(.orange)
                                )
                        case .zomato:
                            Circle()
                                .fill(Color(red: 254/255, green: 226/255, blue: 226/255))
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Text("z")
                                        .font(.system(size: 11, weight: .black, design: .rounded))
                                        .foregroundColor(.red)
                                )
                        case .reliance:
                            Circle()
                                .fill(Color(red: 224/255, green: 242/255, blue: 254/255))
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Image(systemName: "fuelpump.fill")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.blue)
                                )
                        case .swiggy:
                            Circle()
                                .fill(Color.orange.opacity(0.14))
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Text("S")
                                        .font(.system(size: 11, weight: .black, design: .rounded))
                                        .foregroundColor(.orange)
                                )
                        case .dmart:
                            Circle()
                                .fill(Color(red: 220/255, green: 245/255, blue: 225/255))
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Text("D")
                                        .font(.system(size: 11, weight: .black, design: .rounded))
                                        .foregroundColor(Color(red: 22/255, green: 130/255, blue: 60/255))
                                )
                        }
                    }

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
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ExpensesView()
}

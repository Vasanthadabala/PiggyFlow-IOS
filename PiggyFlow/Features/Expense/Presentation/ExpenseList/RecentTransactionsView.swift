import SwiftUI
import SwiftData
import UIKit

struct RecentTransactionsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query private var expenses: [Expense]
    @Query private var incomes: [Income]

    @State private var searchText: String = ""
    @State private var selectedTypeFilter: String = "All"
    @State private var showAddTransactionSheet: Bool = false
    @State private var collapsedDates: Set<String> = []
    @State private var dateRange: DateRangeFilter = .thisMonth
    @State private var showExportShare: Bool = false
    @State private var exportURL: URL? = nil

    /// Ranges the date chip offers. `.allTime` is the default-off escape hatch so a user whose
    /// transactions predate this month can still see them.
    enum DateRangeFilter: String, CaseIterable, Identifiable {
        case thisMonth = "This Month"
        case lastMonth = "Last Month"
        case last90 = "Last 90 Days"
        case thisYear = "This Year"
        case allTime = "All Time"

        var id: String { rawValue }

        var shortLabel: String { self == .allTime ? "All Time" : rawValue }

        /// `nil` means no bound — everything qualifies.
        func interval(now: Date = Date()) -> DateInterval? {
            let cal = Calendar.current
            switch self {
            case .allTime:
                return nil
            case .thisMonth:
                return cal.dateInterval(of: .month, for: now)
            case .lastMonth:
                guard let prev = cal.date(byAdding: .month, value: -1, to: now) else { return nil }
                return cal.dateInterval(of: .month, for: prev)
            case .last90:
                guard let start = cal.date(byAdding: .day, value: -90, to: now) else { return nil }
                return DateInterval(start: cal.startOfDay(for: start), end: now)
            case .thisYear:
                return cal.dateInterval(of: .year, for: now)
            }
        }
    }

    private let typeFilters = ["All", "Income", "Expense", "Account", "Category", "More"]

    // MARK: - Data Processing

    private var allItems: [HomeView.TransactionItem] {
        var items: [HomeView.TransactionItem] = []
        items += expenses.map { .expense($0) }
        items += incomes.map { .income($0) }
        return items.sorted { $0.date > $1.date }
    }

    private var filteredItems: [HomeView.TransactionItem] {
        var items = allItems
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            items = items.filter {
                $0.title.lowercased().contains(q) ||
                $0.type.lowercased().contains(q) ||
                $0.note.lowercased().contains(q)
            }
        }
        switch selectedTypeFilter {
        case "Income":  items = items.filter { if case .income = $0 { return true }; return false }
        case "Expense": items = items.filter { if case .expense = $0 { return true }; return false }
        default: break
        }
        if let interval = dateRange.interval() {
            items = items.filter { interval.contains($0.date) }
        }
        return items
    }

    private var groupedItems: [(date: String, dateObj: Date, total: Double, items: [HomeView.TransactionItem])] {
        var groups: [String: (dateObj: Date, total: Double, items: [HomeView.TransactionItem])] = [:]
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateStyle = .full

        for item in filteredItems {
            let day = calendar.startOfDay(for: item.date)
            let key = formatter.string(from: day)
            var entry = groups[key] ?? (dateObj: day, total: 0, items: [])
            switch item {
            case .expense(let e): entry.total -= e.price
            case .income(let i): entry.total += i.income
            }
            entry.items.append(item)
            groups[key] = entry
        }

        return groups.map { (date: $0.key, dateObj: $0.value.dateObj, total: $0.value.total, items: $0.value.items) }
            .sorted { $0.dateObj > $1.dateObj }
    }

    private var totalSpent: Double {
        allItems.compactMap { item -> Double? in
            if case .expense(let e) = item { return e.price }
            return nil
        }.reduce(0, +)
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                accountPickerBanner
                searchAndDateRow
                filterChipsRow

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        if groupedItems.isEmpty {
                            emptyState
                        } else {
                            ForEach(groupedItems, id: \.date) { group in
                                sectionHeader(group.date, total: group.total)
                                if !collapsedDates.contains(group.date) {
                                    ForEach(Array(group.items.enumerated()), id: \.element.id) { idx, item in
                                        let title = item.title.isEmpty ? item.type : item.title
                                        NavigationLink(destination: TransactionDetailView(item: item).hidesTabBarOnPush()) {
                                            transactionRow(item: item, title: title)
                                        }
                                        .buttonStyle(.plain)
                                        if idx < group.items.count - 1 {
                                            Divider().padding(.leading, 68)
                                        }
                                    }
                                }
                            }

                            // Footer
                            HStack {
                                HStack(spacing: 6) {
                                    Image(systemName: "doc.text.fill")
                                        .font(.system(size: 13))
                                        .foregroundColor(.appGreen)
                                    Text("Showing \(filteredItems.count) of \(allItems.count) transactions")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundColor(.secondary)
                                    Text("Updated just now")
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button {
                                    Haptics.medium()
                                    exportFilteredTransactions()
                                } label: {
                                    HStack(spacing: 4) {
                                        Text("Export")
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundColor(.appGreen)
                                        Image(systemName: "arrow.down.circle")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(.appGreen)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color.appGreen.opacity(0.06))
                        }
                        Spacer().frame(height: 100)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        // Full screen rather than a sheet: the chooser grid now carries a proper header and
        // fills the page, not a half-height card.
        .fullScreenCover(isPresented: $showAddTransactionSheet) {
            AddExpenseBottomSheetView(itemToEdit: nil)
        }
        .sheet(isPresented: $showExportShare) {
            if let exportURL {
                ActivityViewController(activityItems: [exportURL])
            }
        }
    }

    /// Exports exactly what the list is showing — the same search, type and date filters — so
    /// the PDF matches the screen rather than silently dumping the whole ledger.
    private func exportFilteredTransactions() {
        let items = filteredItems
        guard !items.isEmpty else { return }

        let title = "PiggyFlow Transactions — \(dateRange.rawValue)"
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextCreator: "PiggyFlow",
            kCGPDFContextTitle: title
        ] as [String: Any]

        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let data = renderer.pdfData { context in
            context.beginPage()
            var y: CGFloat = 40
            title.draw(at: CGPoint(x: 40, y: y), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 20)])
            y += 34
            y = PDFTableRenderer.drawHeader(y: y)

            for item in items {
                // A new page before running off the bottom, otherwise long exports silently
                // truncate at whatever fits on page one.
                if y > pageRect.height - 60 {
                    context.beginPage()
                    y = 40
                    y = PDFTableRenderer.drawHeader(y: y)
                }
                let isIncome = item.color == .appGreen
                let name = item.title.isEmpty ? item.type : item.title
                y = PDFTableRenderer.drawRow(
                    name: name,
                    amount: AppFormatter.signedCurrency(item.amount, isIncome: isIncome),
                    date: item.date.formatted(.dateTime.month(.abbreviated).day().year()),
                    y: y
                )
            }
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PiggyFlow_Transactions.pdf")
        do {
            try data.write(to: url)
            exportURL = url
            showExportShare = true
        } catch {
            Log.error(error, context: "Writing transactions PDF", category: .database)
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack {
            BackButton { dismiss() }
            Spacer()
            VStack(spacing: 2) {
                Text("Recent Transactions")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text("All your recent transactions across accounts")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Menu {
                Picker("Show", selection: $selectedTypeFilter) {
                    Text("All").tag("All")
                    Text("Income").tag("Income")
                    Text("Expense").tag("Expense")
                }
                Picker("Period", selection: $dateRange) {
                    ForEach(DateRangeFilter.allCases) { Text($0.rawValue).tag($0) }
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.appGreen)
                    .frame(width: 40, height: 40)
                    .background(Color.appGreen.opacity(0.12))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(Color.appBackground)
    }

    // MARK: - Account Picker Banner

    private var accountPickerBanner: some View {
        HStack(spacing: 12) {
            // Account icon
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.appGreen.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.appGreen)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("All Accounts")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                }
                Text("\(AccountManager.shared.accounts.count) Accounts")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("Total Spent")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                Text("₹\(String(format: "%.2f", totalSpent))")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                HStack(spacing: 3) {
                    Image(systemName: "arrowtriangle.up.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.appExpenseRed)
                    Text("8.6% vs last month")
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .foregroundColor(.appExpenseRed)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    // MARK: - Search & Date Row

    private var searchAndDateRow: some View {
        HStack(spacing: 10) {
            // Search
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 15))
                TextField("Search transactions", text: $searchText)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            // Date range
            Menu {
                Picker("Period", selection: $dateRange) {
                    ForEach(DateRangeFilter.allCases) { Text($0.rawValue).tag($0) }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12, weight: .bold))
                    Text(dateRange.shortLabel)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.appBackground)
    }

    // MARK: - Filter Chips Row

    private var filterChipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(typeFilters, id: \.self) { filter in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedTypeFilter = filter
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Text(filter)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                            if filter != "All" {
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .bold))
                            }
                        }
                        .foregroundColor(selectedTypeFilter == filter ? .appGreen : .primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(selectedTypeFilter == filter ? Color.appGreen : Color.primary.opacity(0.15), lineWidth: 1.5)
                                .background(
                                    selectedTypeFilter == filter ? Color.appGreen.opacity(0.08) : Color.clear
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
        .background(Color.appBackground)
    }

    // MARK: - Section Header

    private func sectionHeader(_ dateStr: String, total: Double) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if collapsedDates.contains(dateStr) {
                    collapsedDates.remove(dateStr)
                } else {
                    collapsedDates.insert(dateStr)
                }
            }
        } label: {
            HStack {
                Text(dateStr)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
                Text(total >= 0 ? "+₹\(String(format: "%.2f", total))" : "-₹\(String(format: "%.2f", abs(total)))")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(total >= 0 ? .appGreen : .appExpenseRed)
                Image(systemName: collapsedDates.contains(dateStr) ? "chevron.down" : "chevron.up")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.appBackground)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Transaction Row

    private func transactionRow(item: HomeView.TransactionItem, title: String) -> some View {
        HStack(spacing: 12) {
            // Merchant icon
            ZStack {
                Circle()
                    .fill(item.color == .appGreen ? Color.appGreen.opacity(0.12) : Color(.tertiarySystemGroupedBackground))
                    .frame(width: 44, height: 44)
                Text(item.emoji.isEmpty ? String(title.prefix(1)).uppercased() : item.emoji)
                    .font(.system(size: 18))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                HStack(spacing: 4) {
                    Text(item.type.isEmpty ? "General" : item.type)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                    if !item.account.isEmpty {
                        Text("•")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Text(item.account)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                let isIncome = item.color == .appGreen
                Text((isIncome ? "+₹" : "-₹") + String(format: "%.2f", item.amount))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(isIncome ? .appGreen : .appExpenseRed)
                Text(timeString(item.date))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(Color(.secondarySystemGroupedBackground))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 14) {
            Circle()
                .fill(Color.appGreen.opacity(0.12))
                .frame(width: 64, height: 64)
                .overlay(
                    Image(systemName: "tray.fill")
                        .font(.system(size: 26))
                        .foregroundColor(.appGreen)
                )
            Text("No transactions found")
                .font(.system(size: 16, weight: .bold, design: .rounded))
            Text("Tap the + button to log a new transaction.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    // MARK: - Helpers

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }

    private func deleteItem(_ item: HomeView.TransactionItem) {
        switch item {
        case .expense(let expense): context.delete(expense); try? context.save()
        case .income(let income): context.delete(income); try? context.save()
        }
    }
}

#Preview {
    RecentTransactionsView()
}

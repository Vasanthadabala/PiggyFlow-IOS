import SwiftUI
import Charts
import SwiftData

struct StatsView: View {
    @Environment(\.modelContext) private var context
    
    @Query private var expenses: [Expense]
    @Query private var incomes: [Income]
    
    @State private var selectedMonth: Date = Date()
    
    //BottomSheet
    @State private var selectedCategory: CategoryData? = nil
    
    
    // Month Range (Last 12 months)
    private var recentMonths: [Date] {
        let calendar = Calendar.current
        let current = calendar.startOfMonth(for: Date())
        return (0..<12).compactMap { offset in
            calendar.date(byAdding: .month, value: -offset, to: current)
        }.reversed()
    }
    
    // Filtered Data for selected month
    private var filteredExpenses: [Expense] {
        let calendar = Calendar.current
        return expenses.filter {
            calendar.isDate($0.date, equalTo: selectedMonth, toGranularity: .month)
        }
    }
    
    private var filteredIncomes: [Income] {
        let calendar = Calendar.current
        return incomes.filter {
            calendar.isDate($0.date, equalTo: selectedMonth, toGranularity: .month)
        }
    }
    
    // Total income
    private var totalIncome: Double {
        filteredIncomes.reduce(0) { $0 + $1.income }
    }
    
    // Total expenses
    private var totalExpenses: Double {
        filteredExpenses.reduce(0) { $0 + $1.price }
    }
    
    // Group expenses by category
    private var expensesByCategory: [CategoryData] {
        var categoryDict: [String: Double] = [:]
        
        for expense in filteredExpenses {
            let key = expense.name
            categoryDict[key, default: 0] += expense.price
        }
        
        return categoryDict.map { (name, amount) in
            // Find the first expense with this category name to get the emoji
            let emoji = expenses.first(where: { $0.name == name })?.emoji ?? "💸"
            return CategoryData(category: name, amount: amount, emoji: emoji)
        }
        .sorted { $0.amount > $1.amount }
    }
    
    // Income vs Expense comparison data
    private var comparisonData: [FinancialData] {
        [
            FinancialData(type: "Income", amount: totalIncome, color: .green),
            FinancialData(type: "Expense", amount: totalExpenses, color: .red)
        ]
    }
    
    var body: some View {
        VStack(spacing: 4) {
            // Month Selector with Arrows
            HStack {
                Button(action: {
                    withAnimation(.easeInOut) {
                        if let prevMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) {
                            selectedMonth = prevMonth
                        }
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(.primary)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                Text(selectedMonth.formatted(.dateTime.month(.wide).year()))
                    .font(.system(size: 18, weight: .semibold))
                    .transition(.opacity.combined(with: .scale))
                    .id(selectedMonth) // triggers animation when month changes
                
                Spacer()
                
                Button(action: {
                    withAnimation(.easeInOut) {
                        if let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth),
                           nextMonth <= Date() { // Prevent future months
                            selectedMonth = nextMonth
                        }
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                        .foregroundColor(.primary)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)
            .contentShape(Rectangle())
            
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    // Summary Cards
                    HStack(spacing: 16) {
                        SummaryCard(title: "Income", amount: totalIncome, color: .green, icon: "arrow.down.left")
                        SummaryCard(title: "Expense", amount: totalExpenses, color: .red, icon: "arrow.up.right")
                    }
                    .padding(.horizontal)
                    
                    SummaryCard(title: "Balance", amount: totalIncome - totalExpenses, color: totalIncome >= totalExpenses ? .green : .red, icon: "equal.circle")
                        .padding(.horizontal)
                    
                    // Check if there’s any data this month
                    if filteredExpenses.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "tray.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.gray.opacity(0.7))
                            Text("No data for this month")
                                .font(.title3)
                                .fontWeight(.semibold)
                            Text("Add some expenses to see your insights!")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else {
                        // Chart Display
                        lineChartView
                        
                        // Category Breakdown
                        if !expensesByCategory.isEmpty {
                            categoryBreakdownView
                        }
                        
                        Spacer()
                    }
                }
                .padding(.top)
            }
        }
        .fullScreenCover(item: $selectedCategory) { category in
            CategoryDetailSheet(
                categoryName: category.category,
                expenses: filteredExpenses,
                incomes: filteredIncomes
            )
        }
    }
    
    // MARK: - Donut Chart
    private var donutChartView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Income vs Expense")
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.horizontal)
            
            Chart(comparisonData) { item in
                SectorMark(
                    angle: .value("Amount", item.amount),
                    innerRadius: .ratio(0.618),
                    outerRadius: .ratio(0.85),
                    angularInset: 2.0
                )
                .cornerRadius(8)
                .foregroundStyle(item.color.gradient)
            }
            .frame(height: 240)
            .padding(.horizontal)
            .chartBackground { _ in
                VStack {
                    Text("Total")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("₹\(String(format: "%.2f", totalIncome))")
                        .font(.title2)
                        .fontWeight(.bold)
                }
            }
        }
    }
    
    // MARK: - Line Chart (Trend over time)
    private var lineChartView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Daily Spending Trend")
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.horizontal)
            
            let dailyExpenses = groupExpensesByDate()
            
            Chart(dailyExpenses) { item in
                LineMark(
                    x: .value("Date", item.date),
                    y: .value("Amount", item.amount)
                )
                .foregroundStyle(Color.red.gradient)
                .lineStyle(StrokeStyle(lineWidth: 3))
                .interpolationMethod(.catmullRom)
                
                AreaMark(
                    x: .value("Date", item.date),
                    y: .value("Amount", item.amount)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.red.opacity(0.3), Color.red.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
                
                PointMark(
                    x: .value("Date", item.date),
                    y: .value("Amount", item.amount)
                )
                .foregroundStyle(.red)
            }
            .frame(height: 260)
            .padding(.horizontal)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                }
            }
        }
    }
    
    // MARK: - Category Breakdown
    private var categoryBreakdownView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Spending Categories")
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.horizontal)
            
            ForEach(expensesByCategory.prefix(5)) { category in
                Button {
                    selectedCategory = category
                } label: {
                    categoryRow(category) // move row UI into function
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func categoryRow(_ category: CategoryData) -> some View {
        HStack {
            Text(category.emoji.isEmpty ? category.category.prefix(1).uppercased() : category.emoji)
                .font(.system(size: 24))
                .frame(width: 40, height: 40)
                .background(Color.red.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(category.category)
                    .font(.system(size: 16, weight: .medium))
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 6)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.red.gradient)
                            .frame(
                                width: geo.size.width * CGFloat(
                                    totalExpenses > 0 ? max(0, min(category.amount / totalExpenses, 1)) : 0
                                ),
                                height: 6
                            )
                    }
                }
                .frame(height: 6)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("₹\(String(format: "%.2f", category.amount))")
                    .font(.system(size: 15, weight: .semibold))
                Text("\(Int(totalExpenses > 0 ? (category.amount / totalExpenses) * 100 : 0))%")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    // Helper function to group expenses by date
    private func groupExpensesByDate() -> [DailyExpense] {
        var dateDict: [Date: Double] = [:]
        
        let calendar = Calendar.current
        for expense in expenses {
            let startOfDay = calendar.startOfDay(for: expense.date)
            dateDict[startOfDay, default: 0] += expense.price
        }
        
        return dateDict.map { DailyExpense(date: $0.key, amount: $0.value) }
            .sorted { $0.date < $1.date }
    }
}

// MARK: - Supporting Views
struct SummaryCard: View {
    let title: String
    let amount: Double
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Text("₹\(String(format: "%.2f", amount))")
                .font(.system(size: 20, weight: .bold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
    }
}

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        return self.date(from: self.dateComponents([.year, .month], from: date))!
    }
}

// MARK: - Data Models
struct CategoryData: Identifiable {
    let id = UUID()
    let category: String
    let amount: Double
    let emoji: String
}

struct FinancialData: Identifiable {
    let id = UUID()
    let type: String
    let amount: Double
    let color: Color
}

struct DailyExpense: Identifiable {
    let id = UUID()
    let date: Date
    let amount: Double
}

#Preview {
    StatsView()
}

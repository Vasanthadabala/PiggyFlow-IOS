import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) var colorScheme
    
    @AppStorage("username") private var userName: String = ""
    @State private var expenseBottomSheet: Bool = false
    @State private var search: String = ""
    @State private var selectedFilter: FilterType = .month
    @State private var selectedDate: Date = Date()
    
    @Query private var expenses:[Expense]
    @Query private var incomes:[Income]

    @State private var editBottomSheet: Bool = false
    @State private var selectedTransactionForEdit: TransactionItem?
    
    // 🕒 Dynamic greeting based on time
        private var greeting: String {
            let hour = Calendar.current.component(.hour, from: Date())
            switch hour {
            case 5..<12:
                return "Good Morning"
            case 12..<17:
                return "Good Afternoon"
            case 17..<22:
                return "Good Evening"
            default:
                return "Good Night"
            }
        }
    
    enum FilterType: String, CaseIterable, Identifiable {
        case day = "Day"
        case week = "Week"
        case month = "Month"
        
        var id: String { self.rawValue }
    }
    
    // Helper enum to wrap both Expense and Income
    enum TransactionItem: Identifiable {
        case expense(Expense)
        case income(Income)
        
        var id: String {
            switch self {
            case .expense(let e): return e.id
            case .income(let i): return i.id
            }
        }
        
        var date: Date {
            switch self {
            case .expense(let e): return e.date
            case .income(let i): return i.date
            }
        }
        
        var title: String {
            switch self {
            case .expense(let e): return e.name
            case .income(let i): return i.name
            }
        }
        
        var type: String {
            switch self {
            case .expense(let e): return e.type
            case .income(let i): return (i.type)
            }
        }
        
        var emoji: String {
            switch self {
            case .expense(let e): return e.emoji
            case .income: return "💰"
            }
        }
        
        var amount: String {
            switch self {
            case .expense(let e): return String(e.price)
            case .income(let i): return String(i.income)
            }
        }
        
        var note: String {
            switch self {
            case .expense(let e): return String(e.note)
            case .income(let i): return String(i.note)
            }
        }
        
        var color: Color {
            switch self {
            case .expense: return .red
            case .income: return .green
            }
        }
    }
    
    // Combine and sort all transactions
    private var allTransactions: [TransactionItem] {
        let expenseItems = expenses.map { TransactionItem.expense($0) }
        let incomeItems = incomes.map { TransactionItem.income($0) }
        return (expenseItems + incomeItems).sorted { $0.date > $1.date }
    }

    // Filtered transactions (based on search + filter type)
    private var filteredTransactions: [TransactionItem] {
        // Step 1: Filter by date
        let dateFiltered = allTransactions.filter { item in
            switch selectedFilter {
            case .day:
                return item.date.isInSameDay(as: selectedDate)
            case .week:
                return item.date.isInSameWeek(as: selectedDate)
            case .month:
                return item.date.isInSameMonth(as: selectedDate)
            }
        }
        
        // Step 2: Apply search filter
        if search.isEmpty {
            return dateFiltered
        } else {
            return dateFiltered.filter { item in
                item.title.localizedCaseInsensitiveContains(search) ||
                item.note.localizedCaseInsensitiveContains(search)
            }
        }
    }

    
    // Total income
    private var totalIncome: Double {
        incomes.reduce(0) { $0 + $1.income }
    }

    // Total expenses (optional, if you want to show spent)
    private var totalExpenses: Double {
        expenses.reduce(0) { $0 + $1.price }
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment:.bottomTrailing){
                VStack{
                    HStack {
                        NavigationLink(destination: ProfileView()) {
                            ZStack {
                                Circle()
                                    .fill(Color.green.gradient)
                                    .frame(width: 44, height: 44)

                                Text((userName.isEmpty ? "G" : String(userName.prefix(1))).uppercased())
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(greeting),")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.gray)
                            
                            Text(userName.isEmpty ? "Guest" : userName)
                                .font(.system(size: 18, weight: .bold))
                        }
                        .padding(.horizontal, 8)

                        Spacer()

                        NavigationLink(destination: NotificationView()) {
                            Image(systemName: "bell")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 18, height: 18)
                                .padding(.all, 12)
                                .background(
                                    Circle()
                                        .fill(Color.gray.opacity(0.2))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Spacer()
                        .frame(height: 24)
                    
                    VStack(alignment:.leading, spacing: 10){
                        HStack {
                            Text("Overview")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(Color.white.opacity(0.8))
                            Spacer()
                            Text(selectedDate.formatted(.dateTime.day().month(.abbreviated).year()))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white.opacity(0.92))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.white.opacity(0.2)))
                        }

                        Text("₹ \(totalIncome - totalExpenses, specifier: "%.2f")")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)

                        Text("Selected month")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.75))

                        HStack{
                            VStack(alignment:.leading, spacing: 2){
                                Text("Income ↘")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(Color.green)
                                Text("₹ \(totalIncome, specifier: "%.2f")")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(Color.white)
                            }
                            
                            Spacer()
                            
                            VStack(alignment:.leading, spacing:2){
                                Text("Spent ↗")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(Color.red)
                                Text("₹ \(totalExpenses, specifier: "%.2f")")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(Color.white)
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 22)
                            .fill(Color(red: 0.05, green: 0.37, blue: 0.22))
                            .shadow(color: .gray.opacity(0.2), radius: 4, x: 0, y: 2)
                    )

                    
                    Spacer()
                        .frame(height: 24)
                    
                    HStack(spacing:12){
                        TextField("Search category or note", text: $search)
                            .padding(.leading, 40)
                            .padding(.vertical, 12)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                            .shadow(radius: 0.5)
                            .font(.system(size: 18, weight: .regular, design: .serif))
                            .overlay(
                                HStack {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundColor(.gray)
                                        .padding(.leading, 12)
                                    Spacer()
                                }
                            )
                        
                        Picker("Filter", selection: $selectedFilter) {
                            ForEach(FilterType.allCases) { filter in
                                Text(filter.rawValue).tag(filter)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(.horizontal, 10)
                        .frame(width: 120, height: 46)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        .shadow(radius: 0.5)
                    }
                    .padding(.horizontal, 6)

                    Spacer().frame(height: 10)

                    HStack {
                        Text("Date")
                            .font(.system(size: 18, weight: .semibold))
                        Spacer()
                        DatePicker("", selection: $selectedDate, displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.gray.opacity(0.12))
                    )
                    .padding(.horizontal, 4)

                    HStack(spacing: 10) {
                        homeDateQuickButton("Today") { selectedDate = Date() }
                        homeDateQuickButton("Yesterday") {
                            selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 4)

                    Spacer().frame(height: 12)

                    HStack {
                        Text("Transactions")
                            .font(.system(size: 24, weight: .semibold))
                        Spacer()
                        Text("\(filteredTransactions.count) items")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 4)
                    
                    //                ScrollView {
                    //                    VStack(spacing: 12) {
                    //                        ForEach(expenses) { expense in
                    //                            ExpenseItemCard(emoji:expense.emoji, title: expense.name, date:expense.date, amount: String(expense.price), color: .red)
                    //                        }
                    //                        .onDelete(perform: deleteItem)
                    //                    }
                    //                    .padding(.horizontal, 8)
                    //                    .padding(.bottom, 10)
                    //                }
                    //                .safeAreaInset(edge: .bottom, spacing: 0) {
                    //                    Color.clear.frame(height: 0)
                    //                }
                    
                    if filteredTransactions.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "tray")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .foregroundColor(.gray.opacity(0.5))
                            
                            Text("No transactions yet")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.gray)
                            
                            Text("Tap the + button to add your first expense or income.")
                                .font(.system(size: 14))
                                .foregroundColor(.gray.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.clear)
                    } else {
                        
                        // Method 1 (with chevron)
//                        List {
//                            ForEach(allTransactions) { item in
//                                NavigationLink{
//                                    TransactionDetailView(item: item)
//                                } label:{
//                                    ExpenseItemCard(
//                                        emoji: item.emoji,
//                                        title: item.title,
//                                        date: item.date,
//                                        amount: String(item.amount),
//                                        color: item.color,
//                                        isIncome: item.color == .green
//                                    )
//                                }
//                                .buttonStyle(.plain)
//                                .listRowInsets(EdgeInsets())
//                                .padding(.vertical, 6)
//                                .padding(.horizontal, 4)
//                                .listRowSeparator(.hidden)
//                                .background(Color.clear)
//                                .listRowBackground(Color.clear)
//                            }
//                            .onDelete(perform: deleteItem)
//                        }
//                        .listStyle(.plain)
//                        .scrollContentBackground(.hidden)
                        
                        // Method 2 (without chevron)
                        List {
                            ForEach(filteredTransactions) { item in
                                let title = item.title
                                let type = item.type
                                
                                ExpenseItemCard(
                                    emoji: item.emoji,
                                    title: title.isEmpty ? type : title,
                                    date: item.date,
                                    amount: String(item.amount),
                                    color: item.color,
                                    isIncome: item.color == .green
                                )
                                .contentShape(Rectangle())
                                .background(
                                    NavigationLink(destination: TransactionDetailView(item: item)) {
                                        EmptyView()
                                    }
                                    .opacity(0)
                                )
                                .listRowInsets(EdgeInsets())
                                .padding(.vertical, 6)
                                .padding(.horizontal, 2)
                                .listRowSeparator(.hidden)
                                .background(Color.clear)
                                .listRowBackground(Color.clear)
                            }
                            .onDelete(perform: deleteItem)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                    
                    
                }
                .padding(.horizontal)
                
                // Floating Action Button
                Button(action: {
                    expenseBottomSheet.toggle()
                }) {
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.green.gradient)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 3)
                }
                .padding()
                .fullScreenCover(isPresented: $expenseBottomSheet) {
                    AddExpenseBottomSheetView(itemToEdit: nil)
                }
                .sheet(isPresented: $editBottomSheet) {
                    if let item = selectedTransactionForEdit {
                        AddExpenseBottomSheetView(itemToEdit: item)
                    }
                }
            }
        }
    }
    
    private func deleteItem(at offsets: IndexSet){
        var deletedExpenseIDs: [String] = []
        var deletedIncomeIDs: [String] = []

        offsets.forEach { index in
            let item = filteredTransactions[index]
            switch item {
            case .expense(let expense):
                deletedExpenseIDs.append(expense.id)
                context.delete(expense)
            case .income(let income):
                deletedIncomeIDs.append(income.id)
                context.delete(income)
            }
        }
        
        do{
            try context.save()
            deletedExpenseIDs.forEach { CloudSyncManager.shared.queueDeleteExpense(id: $0) }
            deletedIncomeIDs.forEach { CloudSyncManager.shared.queueDeleteIncome(id: $0) }
            print("Deleted Successfully")
        }catch {
            print("Failed to delete: \(error.localizedDescription)")
        }
    }

    @ViewBuilder
    private func homeDateQuickButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.system(size: 14, weight: .semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.gray.opacity(0.2)))
            .buttonStyle(.plain)
    }
}

extension Date {
    func isInSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }

    func isInSameWeek(as other: Date) -> Bool {
        Calendar.current.isDate(self, equalTo: other, toGranularity: .weekOfYear)
    }

    func isInSameMonth(as other: Date) -> Bool {
        Calendar.current.isDate(self, equalTo: other, toGranularity: .month)
    }
}

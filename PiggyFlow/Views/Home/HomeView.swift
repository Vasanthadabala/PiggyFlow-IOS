import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) var colorScheme
    
    @AppStorage("username") private var userName: String = ""
    @State private var expenseBottomSheet: Bool = false
    @State private var search: String = ""
    @State private var selectedFilter: FilterType = .month
    
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
        let now = Date()
        
        // Step 1: Filter by date
        let dateFiltered = allTransactions.filter { item in
            switch selectedFilter {
            case .day:
                return item.date.isInSameDay(as: now)
            case .week:
                return item.date.isInSameWeek(as: now)
            case .month:
                return item.date.isInSameMonth(as: now)
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
                    HStack{
                        NavigationLink(destination: ProfileView()) {
                            ZStack{
                                Circle()
                                    .fill(Color.green.gradient)
                                    .frame(width: 48, height: 48)
                                
                                Text(userName.prefix(1).uppercased())
                                    .font(.system(size: 24, weight: .bold, design: .serif))
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        VStack(alignment: .leading){
                            Text("\(greeting),")
                                .font(.system(size: 16, weight: .regular, design: .serif))
                            Text(userName)
                                .font(.system(size: 18, weight: .medium, design: .serif))
                        }
                        .padding(.horizontal, 8)
                        
                        Spacer()
                        
                        NavigationLink(destination: NotificationView()) {
                            VStack{
                                Image(systemName: "bell")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24, height: 24)
                                    .clipShape(Circle())
                            }
                            .padding(.all, 12)
                            .background(
                                Circle()
                                    .fill(Color.gray.opacity(0.1))
                                    .shadow(radius: 0.1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    Spacer()
                        .frame(height: 24)
                    
                    VStack(alignment:.leading){
                        Text("Income")
                            .font(.system(size: 16, weight: .regular, design: .serif))
                            .foregroundColor(Color.white)
                        Spacer()
                            .frame(height: 16)
                        
                        Text("\(totalIncome, specifier: "%.2f")")
                            .font(.system(size: 24, weight: .medium, design: .serif))
                            .foregroundColor(Color.white)
                        
                        Spacer()
                            .frame(height: 16)
                        
                        HStack{
                            VStack(alignment:.leading, spacing: 2){
                                HStack{
                                    Text("Spent")
                                        .font(.system(size: 16, weight: .regular, design: .serif))
                                        .foregroundColor(Color.red)
                                    Image(systemName: "chart.line.uptrend.xyaxis")
                                        .resizable()
                                        .scaledToFit()
                                        .foregroundColor(Color.red)
                                        .frame(width: 12, height: 12)
                                }
                                Text("\(totalExpenses, specifier: "%.2f")")
                                    .font(.system(size: 18, weight: .regular, design: .serif))
                                    .foregroundColor(Color.white)
                            }
                            
                            Spacer()
                            
                            VStack(alignment:.leading, spacing:2){
                                HStack{
                                    Text("Left")
                                        .font(.system(size: 16, weight: .regular, design: .serif))
                                        .foregroundColor(Color.green)
                                    Image(systemName: "chart.line.downtrend.xyaxis")
                                        .resizable()
                                        .scaledToFit()
                                        .foregroundColor(Color.green)
                                        .frame(width: 12, height: 12)
                                }
                                Text("\(totalIncome - totalExpenses, specifier: "%.2f")")
                                    .font(.system(size: 18, weight: .regular, design: .serif))
                                    .foregroundColor(Color.white)
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: colorScheme == .dark ? [Color.green.opacity(0.05), Color.green.opacity(0.05)] : [Color.black, Color.black.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .gray.opacity(0.2), radius: 4, x: 0, y: 2)
                    )

                    
                    Spacer()
                        .frame(height: 24)
                    
                    HStack(spacing:12){
                        TextField("Search", text: $search)
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
                        VStack(spacing: 16) {
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
                                .padding(.horizontal, 4)
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
        offsets.forEach { index in
            let item = allTransactions[index]
            switch item {
            case .expense(let expense):
                context.delete(expense)
            case .income(let income):
                context.delete(income)
            }
        }
        
        do{
            try context.save()
            print("Deleted Successfully")
        }catch {
            print("Failed to delete: \(error.localizedDescription)")
        }
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

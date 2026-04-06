//
//  BottomSheet.swift
//  PiggyFlow
//
//  Created by Vasanth on 11/12/25.
//

import SwiftUI
import SwiftData

struct AddExpenseBottomSheetView: View{
    @Environment(\.dismiss) var expenseBottomSheetDismiss
    @Environment(\.modelContext) private var context
    
    @State private var showToast:Bool = false
    @State private var showAddCategorySheet = false
    @State private var showDeleteAlert = false
    @State private var showAddDataToast = false
    @State private var categoryToDelete: UserCategory? = nil
    
    @State private var userCategories: [UserCategory] = []
    
    
    @State private var selectedUserCategory: UserCategory? = nil
    @State private var newCategoryName: String = ""
    @State private var newCategoryEmoji: String = ""
    
    
    // Optional: If provided, we're in edit mode
    var itemToEdit: HomeView.TransactionItem?
    
    @State private var entryType: EntryType = .expense
    @State private var selectedCategory: CategoryType? = nil
    
    @State private var price: String = ""
    @State private var dateValue: Date = Date()
    @State private var note: String = ""
    @State private var incomeText: String = ""
    
    private var isSubmitEnabled: Bool {
        switch entryType {
        case .expense:
            if isEditMode {
                return !price.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            return !(selectedCategory == nil && selectedUserCategory == nil)
            && !price.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .income:
            return !incomeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
    
    private var submitTitle: String {
        if isEditMode {
            return "Save Changes"
        }
        return entryType == .expense ? "Add Expense" : "Add Income"
    }
    
    // Computed property to determine if we're editing
    private var isEditMode: Bool {
        itemToEdit != nil
    }
    
    enum EntryType:String, CaseIterable, Identifiable {
        case expense = "Expense"
        case income = "Income"
        
        var id: String { self.rawValue }
    }
    
    enum CategoryType: String, Identifiable {
        case home = "🏠 Home"
        case groceries = "🛒 Groceries"
        case powerBill = "💡 Power Bill"
        case phone = "📱 Phone"
        case internet = "🌐 Internet"
        case fuel = "⛽ Fuel"
        case transport = "🚌 Transport"
        case food = "🍔 Food"
        case shopping = "🛍️ Shopping"
        case entertainment = "🎉 Entertainment"
        case drinks = "🍹 Drinks"
        case salary      = "💼 Salary"
        case business    = "🏢 Business"
        case freelance   = "🧑‍💻 Freelance"
        case investments = "📈 Investments"
        case rental      = "🏠 Rental Income"
        case interest    = "💰 Interest"
        case bonus       = "🎁 Bonus"
        case gifts       = "🎉 Gifts"
        case refund      = "🔄 Refund"
        case others = "🔖 Others"
        
        var id: String { self.rawValue }
        
        static let expenseDefaultCategories: [CategoryType] = [
            .food,
            .home,
            .groceries,
            .transport,
            .entertainment,
            .drinks,
            .shopping,
            .powerBill,
            .phone,
            .internet,
            .fuel,
            .others
        ]
        
        static let incomeDefaultCategories: [CategoryType] = [
            .salary,
            .business,
            .freelance,
            .investments,
            .rental,
            .interest,
            .bonus,
            .gifts,
            .refund,
            .others
        ]
    }
    
    var body: some View {
        ZStack{
            
            VStack(spacing: 12) {
                HStack {
                    Spacer()
                    Button(action: {
                        expenseBottomSheetDismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .resizable()
                            .frame(width: 28, height: 28)
                            .foregroundStyle(.white, .red)
                            .padding()
                    }
                    .buttonStyle(.plain)
                }

                ScrollView(showsIndicators: false) {
                VStack(spacing:16){
                    if !isEditMode {
                        Picker("Type", selection: $entryType) {
                            ForEach(EntryType.allCases) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                    }
                    
                    if entryType == .expense {
                        ExpenseSection(
                            isEditMode: isEditMode,
                            userCategories: $userCategories,
                            selectedUserCategory: $selectedUserCategory,
                            selectedCategory: $selectedCategory,
                            onAddCategoryTapped: {
                                showAddCategorySheet = true
                            },
                            onDeleteCategory: { category in
                                categoryToDelete = category
                                showDeleteAlert = true
                            },
                            price: $price,
                            dateValue: $dateValue,
                            note: $note,
                            addNewCategory: addNewCategory
                        )
                    }
                    else {
                        IncomeSection(
                            isEditMode: isEditMode,
                            userCategories: $userCategories,
                            selectedUserCategory: $selectedUserCategory,
                            selectedCategory: $selectedCategory,
                            onAddCategoryTapped: {
                                showAddCategorySheet = true
                            },
                            onDeleteCategory: { category in
                                categoryToDelete = category
                                showDeleteAlert = true
                            },
                            incomeText: $incomeText,
                            dateValue: $dateValue,
                            note: $note,
                            addNewIncomeCategory: addNewCategory
                        )
                    }
                    
                    
                    Button{
                        if !isSubmitEnabled {
                            showValidationToast()
                            return
                        }
                        
                        if isEditMode {
                            // Update existing item
                            updateItem()
                        } else {
                            // Add new item
                            addNewItem()
                        }
                        expenseBottomSheetDismiss()
                    } label: {
                        Text(submitTitle)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .font(.system(size: 24, weight: .semibold))
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .foregroundColor(.white)
                    .background(isSubmitEnabled ? Color.green : Color.gray.opacity(0.35))
                    .cornerRadius(12)
                    .disabled(!isSubmitEnabled)
                    .padding(.top, 8)
                }
                .padding()
                }
            }
            .onAppear {
                
                // 🔹 Fetch Expense Categories
                    UserCategoryManager.shared.fetchCategories()
                    userCategories = UserCategoryManager.shared.categories
                
                
                if let item = itemToEdit {
                    switch item {
                    case .expense(let expense):
                        entryType = .expense
                        price = String(expense.price)
                        dateValue = expense.date
                        note = expense.note
                        
                    case .income(let income):
                        entryType = .income
                        incomeText = String(income.income)
                        dateValue = income.date
                        note = income.note
                    }
                }
                
            }
            .onChange(of: entryType) {
                selectedCategory = nil
                selectedUserCategory = nil
            }
        }
        .fullScreenCover(isPresented: $showAddCategorySheet) {
            AddCategorySheet(
                entryType: entryType,
                isPresented: $showAddCategorySheet,
                newCategoryName: $newCategoryName,
                newCategoryEmoji: $newCategoryEmoji,
                showToast: $showToast,
                onAddExpenseCategory: addNewCategory
            )
        }
        .alert("Delete Category", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                deleteExpenseCategory()
            }
            Button("Cancel", role: .cancel) { }
        }
        
        if(showAddDataToast){
            VStack{
                Spacer()
                
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                    
                    Text("Provide Required fields")
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 24)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            .animation(.easeInOut, value: showToast)
        }
    }
    
    
    
    //Toast helper function
    private func showValidationToast() {
        withAnimation { showAddDataToast = true }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showAddDataToast = false }
        }
    }
    
    // MARK: - Category Management
        private func addNewCategory() {
            let trimmedName = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedEmoji = newCategoryEmoji.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Check if both fields are filled
            guard !trimmedName.isEmpty else {
                withAnimation {
                    showToast = true
                }
                
                // Hide toast after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        showToast = false
                    }
                }
                
                print("❌ Both fields are required.")
                return
            }
            
            print("🟢 Attempting to add new category:")
            print("🟢 Name: \(newCategoryName)")
            print("🟢 Emoji: \(newCategoryEmoji)")
            print("🟢 Current categories before adding: \(userCategories.count)")
            
            let newCategory = UserCategory(name: trimmedName, emoji: trimmedEmoji)
            
            let categoryContext = UserCategoryManager.shared.container.mainContext
            categoryContext.insert(newCategory)
            
            do {
                try categoryContext.save()
                
                print("✅ Category saved successfully!")
                print("✅ New category ID: \(newCategory.id)")
                
                UserCategoryManager.shared.fetchCategories()
                userCategories = UserCategoryManager.shared.categories
                print("✅ Total categories after save: \(userCategories.count)")

                
                // Verify the category was added
                userCategories.forEach { category in
                    print("✅ Available category: \(category.emoji) \(category.name)")
                }
                
                selectedUserCategory = newCategory
                newCategoryName = ""
                newCategoryEmoji = ""
                showAddCategorySheet = false
                
            } catch {
                print("❌ Failed to save category: \(error.localizedDescription)")
                print("❌ Error details: \(error)")
            }
        }
    
    // Separate function to add new item
    private func addNewItem() {
        if entryType == .expense {
            guard let priceValue = Double(price) else { return }
            
            let (emojiPart, namePart) = selectedUserCategory != nil ?
            (selectedUserCategory!.emoji, selectedUserCategory!.name) :
            (selectedCategory?.rawValue.split(separator: " ").first.map(String.init) ?? "💸",
             selectedCategory?.rawValue.split(separator: " ").dropFirst().first.map(String.init) ?? "Other")
            
            let newExpense = Expense(
                type: "Expense",
                emoji: emojiPart,
                name: namePart,
                price: priceValue,
                date: dateValue,
                note: note
            )
            context.insert(newExpense)

            do {
                try context.save()
                CloudSyncManager.shared.queueExpenseUpsert(newExpense)
                print("✅ Data saved successfully!")
            } catch {
                print("❌ Failed to save: \(error.localizedDescription)")
            }
        } else {
            guard let incomeValue = Double(incomeText) else { return }
            
            let (emojiPart, namePart) = selectedUserCategory != nil ?
            (selectedUserCategory!.emoji, selectedUserCategory!.name) :
            (selectedCategory?.rawValue.split(separator: " ").first.map(String.init) ?? "💰",
             selectedCategory?.rawValue.split(separator: " ").dropFirst().joined(separator: " ") ?? "")

            let newIncome = Income(
                type: "Income",
                emoji: emojiPart,
                name: namePart,
                income: incomeValue,
                date: dateValue,
                note: note
            )
            
            context.insert(newIncome)
            do {
                try context.save()
                CloudSyncManager.shared.queueIncomeUpsert(newIncome)
                print("✅ Data saved successfully!")
            } catch {
                print("❌ Failed to save: \(error.localizedDescription)")
            }
        }
    }
    
    // Separate function to update existing item
    private func updateItem() {
        guard let item = itemToEdit else { return }
        
        switch item {
        case .expense(let expense):
            if let priceValue = Double(price) {
                expense.price = priceValue
                expense.date = dateValue
                expense.note = note
            }
        case .income(let income):
            if let incomeValue = Double(incomeText) {
                income.income = incomeValue
                income.date = dateValue
                income.note = note
            }
        }
        
        do {
            try context.save()
            switch item {
            case .expense(let expense):
                CloudSyncManager.shared.queueExpenseUpsert(expense)
            case .income(let income):
                CloudSyncManager.shared.queueIncomeUpsert(income)
            }
            print("✅ Updated successfully!")
        } catch {
            print("❌ Failed to update: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Delete Category
    private func deleteExpenseCategory() {
        guard let category = categoryToDelete else { return }

        let context = UserCategoryManager.shared.container.mainContext
        let id = category.id

        do {
            let descriptor = FetchDescriptor<UserCategory>(
                predicate: #Predicate { $0.id == id }
            )

            if let object = try context.fetch(descriptor).first {
                context.delete(object)
                try context.save()

                UserCategoryManager.shared.fetchCategories()
                userCategories = UserCategoryManager.shared.categories

                print("✅ Expense category deleted")
            }

            categoryToDelete = nil
        } catch {
            print("❌ Failed to delete expense category:", error)
        }
    }

}

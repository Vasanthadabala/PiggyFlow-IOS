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
    
    @State private var userCategories: [UserCategory] = []
    
    @State private var showAddCategorySheet: Bool = false
    
    @State private var selectedUserCategory: UserCategory? = nil
    @State private var newCategoryName: String = ""
    @State private var newCategoryEmoji: String = ""
    
    @State private var showDeleteAlert = false
    @State private var categoryToDelete: UserCategory? = nil

    
    // Optional: If provided, we're in edit mode
    var itemToEdit: HomeView.TransactionItem?
    
    @State private var entryType: EntryType = .expense
    @State private var selectedCategory: CategoryType? = nil
    @State private var price: String = ""
    @State private var dateValue: Date = Date()
    @State private var note: String = ""
    @State private var incomeText: String = ""
    
    
    // Computed property to determine if we're editing
    private var isEditMode: Bool {
        itemToEdit != nil
    }
    
    enum EntryType:String, CaseIterable, Identifiable {
        case expense = "Expense"
        case income = "Income"
        
        var id: String { self.rawValue }
    }
    
    enum CategoryType: String, CaseIterable, Identifiable {
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
        case others = "🔖 Others"
        
        var id: String { self.rawValue }
    }
    
    @State var showAddDataToast:Bool = false
    
    var body: some View {
        ZStack{
            VStack(spacing: 12) {
                
                // Close button pinned at top right
                HStack {
                    Spacer()
                    Button(action: { expenseBottomSheetDismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .resizable()
                            .frame(width: 28, height: 28)
                            .foregroundColor(Color.red)
                            .padding()
                    }
                }
                
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
                        if isEditMode {
                            HStack(){
                                Text("Update Expense")
                                    .padding(.horizontal, 4)
                                    .font(.system(size: 24, weight: .medium, design: .serif))
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8){
                            if !isEditMode {
                                HStack{
                                    Text("Select Category")
                                        .font(.system(size: 16, weight: .regular, design: .serif))
                                    
                                    Spacer()
                                    
                                    // Add new category button
                                    Button(action: {
                                        showAddCategorySheet = true
                                    }) {
                                        Text("+ Add Category")
                                            .padding(.vertical, 4)
                                            .padding(.horizontal, 12)
                                            .font(.system(size: 16, weight: .regular, design: .serif))
                                            .foregroundColor(Color.white)
                                            .background(Color.green.gradient)
                                            .cornerRadius(10)
                                    }
                                    .sheet(isPresented: $showAddCategorySheet) {
                                        ZStack{
                                            VStack(spacing: 20) {
                                                
                                                // Close button pinned at top right
                                                HStack {
                                                    Spacer()
                                                    Button(action: { showAddCategorySheet = false }) {
                                                        Image(systemName: "xmark.circle.fill")
                                                            .resizable()
                                                            .frame(width: 28, height: 28)
                                                            .foregroundColor(Color.red)
                                                            .padding()
                                                    }
                                                }
                                                VStack(spacing: 20) {
                                                    Text("Add New Category")
                                                        .font(.system(size: 24, weight: .semibold, design: .serif))
                                                    
                                                    VStack(alignment: .leading, spacing: 8) {
                                                        Text("Category Name")
                                                            .font(.system(size: 16, weight: .regular, design: .serif))
                                                        
                                                        TextField("Enter User Name", text: $newCategoryName)
                                                            .padding(12)
                                                            .background(Color.gray.opacity(0.1))
                                                            .cornerRadius(8)
                                                            .shadow(radius: 0.5)
                                                            .font(.system(size: 18, weight: .regular, design: .serif))
                                                    }
                                                    .padding(.horizontal, 4)
                                                    
                                                    VStack(alignment: .leading, spacing: 8) {
                                                        
                                                        HStack {
                                                            Text("Emoji")
                                                                .font(.system(size: 16, weight: .regular, design: .serif))
                                                            
                                                            Text("(Optional)")
                                                                .font(.system(size: 16, weight: .regular, design: .serif))
                                                                .foregroundColor(Color.gray.opacity(0.5))
                                                        }
                                                        
                                                        TextField("Emoji", text: $newCategoryEmoji)
                                                            .padding(12)
                                                            .background(Color.gray.opacity(0.1))
                                                            .cornerRadius(8)
                                                            .shadow(radius: 0.5)
                                                            .font(.system(size: 18, weight: .regular, design: .serif))
                                                    }
                                                    .padding(.horizontal, 4)
                                                    
                                                    HStack(spacing: 20) {
                                                        
                                                        Button {
                                                            showAddCategorySheet = false
                                                            newCategoryName = ""
                                                            newCategoryEmoji = ""
                                                        } label: {
                                                            Text("Cancel")
                                                                .frame(maxWidth: .infinity)
                                                                .font(.system(size: 18, weight: .medium, design: .serif))
                                                        }
                                                        .padding(.vertical, 8)
                                                        .padding(.horizontal)
                                                        .foregroundColor(.white)
                                                        .background(Color.red.gradient)
                                                        .cornerRadius(10)
                                                        
                                                        Button {
                                                            addNewCategory()
                                                        } label: {
                                                            Text("Add")
                                                                .frame(maxWidth: .infinity)
                                                                .font(.system(size: 18, weight: .medium, design: .serif))
                                                        }
                                                        .padding(.vertical, 8)
                                                        .padding(.horizontal)
                                                        .foregroundColor(.white)
                                                        .background(Color.green.gradient)
                                                        .cornerRadius(10)
                                                    }
                                                    .padding(.top, 10)
                                                    
                                                    Spacer()
                                                }
                                                .padding()
                                                
                                                if showToast {
                                                    VStack {
                                                        Spacer()
                                                        Text("⚠️ Provide Category Name!")
                                                            .font(.body)
                                                            .padding(.horizontal, 20)
                                                            .padding(.vertical, 12)
                                                            .background(Color.black.opacity(0.85))
                                                            .foregroundColor(.white)
                                                            .cornerRadius(10)
                                                            .shadow(radius: 4)
                                                            .padding(.bottom, 50)
                                                            .transition(.move(edge: .bottom).combined(with: .opacity))
                                                    }
                                                    .animation(.easeInOut, value: showToast)
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 8)
                                
                                
                                
                                ScrollView(.vertical, showsIndicators: true) {
                                    let columns = [GridItem(.flexible()), GridItem(.flexible())] // 2 columns
                                    LazyVGrid(columns: columns, spacing: 12) {
                                        
                                        // User-added categories
                                        ForEach(userCategories) { category in
                                            
                                            Text("\(category.emoji) \(category.name)")
                                                .padding(.vertical, 6)
                                                .padding(.horizontal, 8)
                                                .frame(maxWidth: .infinity)
                                                .foregroundColor(
                                                    selectedUserCategory?.id == category.id
                                                    ? Color.white
                                                    : Color.blue
                                                )
                                                .background(
                                                    selectedUserCategory?.id == category.id
                                                    ? Color.green.opacity(0.8)
                                                    : Color.gray.opacity(0.1)
                                                )
                                                .cornerRadius(12)
                                            
                                                .onTapGesture {
                                                    selectedUserCategory = category
                                                    selectedCategory = nil
                                                }
                                            
                                                .onLongPressGesture(minimumDuration: 1.0) {
                                                    
                                                    DispatchQueue.main.async {
                                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                                        categoryToDelete = category
                                                        showDeleteAlert = true
                                                    }
                                                }
                                        }
                                        
                                        ForEach(CategoryType.allCases) { category in
                                            Button(action: {
                                                selectedCategory = category
                                                selectedUserCategory = nil
                                            }) {
                                                Text(category.rawValue)
                                                    .padding(.vertical, 6)
                                                    .padding(.horizontal, 8)
                                                    .frame(maxWidth: .infinity) // full width in grid cell
                                                    .foregroundColor(selectedCategory == category ? Color.white : Color.blue)
                                                    .background(selectedCategory == category ? Color.green.opacity(0.8) : Color.gray.opacity(0.1))
                                                    .cornerRadius(12)
                                            }
                                        }
                                        
                                    }
                                    .padding(.horizontal, 4)
                                    .alert("Delete Category", isPresented: $showDeleteAlert) {
                                        
                                        Button("Delete", role: .destructive) {
                                            guard let category = categoryToDelete else { return }
                                            
                                            let context = UserCategoryManager.shared.container.mainContext
                                            let id = category.id   // ✅ Convert to literal value
                                            
                                            do {
                                                // ✅ Re-fetch object from SAME context
                                                let descriptor = FetchDescriptor<UserCategory>(
                                                    predicate: #Predicate { userCategory in
                                                        userCategory.id == id   // ✅ KeyPath == literal
                                                    }
                                                )
                                                
                                                if let object = try context.fetch(descriptor).first {
                                                    
                                                    context.delete(object)
                                                    try context.save()
                                                    
                                                    print("✅ Category deleted from SwiftData")
                                                    
                                                    // Refresh UI
                                                    UserCategoryManager.shared.fetchCategories()
                                                    userCategories = UserCategoryManager.shared.categories
                                                    
                                                    categoryToDelete = nil
                                                    
                                                } else {
                                                    print("❌ Category not found in context")
                                                }
                                                
                                            } catch {
                                                print("❌ Failed to delete:", error)
                                            }
                                        }
                                        
                                        Button("Cancel", role: .cancel) { }
                                        
                                    } message: {
                                        Text("Are you sure you want to delete this category?")
                                    }
                                    
                                }
                                .frame(maxHeight: 220)
                                .disabled(isEditMode)
                                
                            }
                        }
                        
                        // Price
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Enter Price")
                                .font(.system(size: 16, weight: .regular, design: .serif))
                            
                            TextField("e.g., 100", text: $price)
                                .keyboardType(.decimalPad)
                                .padding(.all, 12)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                                .shadow(radius: 0.5)
                                .font(.system(size: 18, weight: .regular, design: .serif))
                        }
                        
                        
                        DatePicker(selection: $dateValue, label: {
                            Text("Due Date")
                                .font(.system(size: 16, weight: .medium, design: .serif))
                            
                        })
                        .padding(.all, 4)
                        
                        // Note
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Note")
                                    .font(.system(size: 16, weight: .regular, design: .serif))
                                
                                Text("(Optional)")
                                    .font(.system(size: 16, weight: .regular, design: .serif))
                                    .foregroundColor(Color.gray.opacity(0.5))
                            }
                            
                            TextEditor(text: $note)
                                .frame(height: 50)
                                .padding(8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                                .shadow(radius: 0.5)
                                .font(.system(size: 18, weight: .regular, design: .serif))
                                .scrollContentBackground(.hidden)
                        }
                    } else if entryType == .income{
                        if isEditMode {
                            HStack(){
                                Text("Update Income")
                                    .padding(.horizontal, 4)
                                    .font(.system(size: 24, weight: .medium, design: .serif))
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8){
                            if !isEditMode {
                                HStack{
                                    Text("Select Category")
                                        .font(.system(size: 16, weight: .regular, design: .serif))
                                    
                                    Spacer()
                                    
                                    // Add new category button
                                    Button(action: {
                                        showAddCategorySheet = true
                                    }) {
                                        Text("+ Add Category")
                                            .padding(.vertical, 4)
                                            .padding(.horizontal, 12)
                                            .font(.system(size: 16, weight: .regular, design: .serif))
                                            .foregroundColor(Color.white)
                                            .background(Color.green.gradient)
                                            .cornerRadius(10)
                                    }
                                    .sheet(isPresented: $showAddCategorySheet) {
                                        ZStack{
                                            VStack(spacing: 20) {
                                                
                                                // Close button pinned at top right
                                                HStack {
                                                    Spacer()
                                                    Button(action: { showAddCategorySheet = false }) {
                                                        Image(systemName: "xmark.circle.fill")
                                                            .resizable()
                                                            .frame(width: 28, height: 28)
                                                            .foregroundColor(Color.red)
                                                            .padding()
                                                    }
                                                }
                                                VStack(spacing: 20) {
                                                    Text("Add New Category")
                                                        .font(.system(size: 24, weight: .semibold, design: .serif))
                                                    
                                                    VStack(alignment: .leading, spacing: 8) {
                                                        Text("Category Name")
                                                            .font(.system(size: 16, weight: .regular, design: .serif))
                                                        
                                                        TextField("Enter User Name", text: $newCategoryName)
                                                            .padding(12)
                                                            .background(Color.gray.opacity(0.1))
                                                            .cornerRadius(8)
                                                            .shadow(radius: 0.5)
                                                            .font(.system(size: 18, weight: .regular, design: .serif))
                                                    }
                                                    .padding(.horizontal, 4)
                                                    
                                                    VStack(alignment: .leading, spacing: 8) {
                                                        
                                                        HStack {
                                                            Text("Emoji")
                                                                .font(.system(size: 16, weight: .regular, design: .serif))
                                                            
                                                            Text("(Optional)")
                                                                .font(.system(size: 16, weight: .regular, design: .serif))
                                                                .foregroundColor(Color.gray.opacity(0.5))
                                                        }
                                                        
                                                        TextField("Emoji", text: $newCategoryEmoji)
                                                            .padding(12)
                                                            .background(Color.gray.opacity(0.1))
                                                            .cornerRadius(8)
                                                            .shadow(radius: 0.5)
                                                            .font(.system(size: 18, weight: .regular, design: .serif))
                                                    }
                                                    .padding(.horizontal, 4)
                                                    
                                                    HStack(spacing: 20) {
                                                        
                                                        Button {
                                                            showAddCategorySheet = false
                                                            newCategoryName = ""
                                                            newCategoryEmoji = "🔖"
                                                        } label: {
                                                            Text("Cancel")
                                                                .frame(maxWidth: .infinity)
                                                                .font(.system(size: 18, weight: .medium, design: .serif))
                                                        }
                                                        .padding(.vertical, 8)
                                                        .padding(.horizontal)
                                                        .foregroundColor(.white)
                                                        .background(Color.red.gradient)
                                                        .cornerRadius(10)
                                                        
                                                        Button {
                                                            addNewCategory()
                                                        } label: {
                                                            Text("Add")
                                                                .frame(maxWidth: .infinity)
                                                                .font(.system(size: 18, weight: .medium, design: .serif))
                                                        }
                                                        .padding(.vertical, 8)
                                                        .padding(.horizontal)
                                                        .foregroundColor(.white)
                                                        .background(Color.green.gradient)
                                                        .cornerRadius(10)
                                                    }
                                                    .padding(.top, 10)
                                                    
                                                    Spacer()
                                                }
                                                .padding()
                                                
                                                if showToast {
                                                    VStack {
                                                        Spacer()
                                                        Text("⚠️ Provide Category Name!")
                                                            .font(.body)
                                                            .padding(.horizontal, 20)
                                                            .padding(.vertical, 12)
                                                            .background(Color.black.opacity(0.85))
                                                            .foregroundColor(.white)
                                                            .cornerRadius(10)
                                                            .shadow(radius: 4)
                                                            .padding(.bottom, 50)
                                                            .transition(.move(edge: .bottom).combined(with: .opacity))
                                                    }
                                                    .animation(.easeInOut, value: showToast)
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 8)
                                
                                
                                
                                ScrollView(.vertical, showsIndicators: true) {
                                    let columns = [GridItem(.flexible()), GridItem(.flexible())] // 2 columns
                                    LazyVGrid(columns: columns, spacing: 12) {
                                        
                                        // User-added categories
                                        ForEach(userCategories) { category in
                                            
                                            Text("\(category.emoji) \(category.name)")
                                                .padding(.vertical, 6)
                                                .padding(.horizontal, 8)
                                                .frame(maxWidth: .infinity)
                                                .foregroundColor(
                                                    selectedUserCategory?.id == category.id
                                                    ? Color.white
                                                    : Color.blue
                                                )
                                                .background(
                                                    selectedUserCategory?.id == category.id
                                                    ? Color.green.opacity(0.8)
                                                    : Color.gray.opacity(0.1)
                                                )
                                                .cornerRadius(12)
                                            
                                                .onTapGesture {
                                                    selectedUserCategory = category
                                                    selectedCategory = nil
                                                }
                                            
                                                .onLongPressGesture(minimumDuration: 1.0) {
                                                    
                                                    DispatchQueue.main.async {
                                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                                        categoryToDelete = category
                                                        showDeleteAlert = true
                                                    }
                                                }
                                        }
                                        
                                        ForEach(CategoryType.allCases) { category in
                                            Button(action: {
                                                selectedCategory = category
                                                selectedUserCategory = nil
                                            }) {
                                                Text(category.rawValue)
                                                    .padding(.vertical, 6)
                                                    .padding(.horizontal, 8)
                                                    .frame(maxWidth: .infinity) // full width in grid cell
                                                    .foregroundColor(selectedCategory == category ? Color.white : Color.blue)
                                                    .background(selectedCategory == category ? Color.green.opacity(0.8) : Color.gray.opacity(0.1))
                                                    .cornerRadius(12)
                                            }
                                        }
                                        
                                    }
                                    .padding(.horizontal, 4)
                                    .alert("Delete Category", isPresented: $showDeleteAlert) {
                                        
                                        Button("Delete", role: .destructive) {
                                            guard let category = categoryToDelete else { return }
                                            
                                            let context = UserCategoryManager.shared.container.mainContext
                                            let id = category.id   // ✅ Convert to literal value
                                            
                                            do {
                                                // ✅ Re-fetch object from SAME context
                                                let descriptor = FetchDescriptor<UserCategory>(
                                                    predicate: #Predicate { userCategory in
                                                        userCategory.id == id   // ✅ KeyPath == literal
                                                    }
                                                )
                                                
                                                if let object = try context.fetch(descriptor).first {
                                                    
                                                    context.delete(object)
                                                    try context.save()
                                                    
                                                    print("✅ Category deleted from SwiftData")
                                                    
                                                    // Refresh UI
                                                    UserCategoryManager.shared.fetchCategories()
                                                    userCategories = UserCategoryManager.shared.categories
                                                    
                                                    categoryToDelete = nil
                                                    
                                                } else {
                                                    print("❌ Category not found in context")
                                                }
                                                
                                            } catch {
                                                print("❌ Failed to delete:", error)
                                            }
                                        }
                                        
                                        Button("Cancel", role: .cancel) { }
                                        
                                    } message: {
                                        Text("Are you sure you want to delete this category?")
                                    }
                                    
                                }
                                .frame(maxHeight: 220)
                                .disabled(isEditMode)
                                
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Enter Income")
                                .font(.system(size: 16, weight: .regular, design: .serif))
                            
                            TextField("e.g., 500", text: $incomeText)
                                .padding(.all, 12)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                                .shadow(radius: 0.5)
                                .font(.system(size: 18, weight: .regular, design: .serif))
                        }
                        
                        DatePicker(selection: $dateValue, label: {
                            Text("Due Date")
                                .font(.system(size: 16, weight: .medium, design: .serif))
                            
                        })
                        .padding(.all, 4)
                        
                        // Note
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Note")
                                    .font(.system(size: 16, weight: .regular, design: .serif))
                                
                                Text("(Optional)")
                                    .font(.system(size: 16, weight: .regular, design: .serif))
                                    .foregroundColor(Color.gray.opacity(0.5))
                            }
                            
                            TextEditor(text: $note)
                                .frame(height: 50)
                                .padding(8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                                .shadow(radius: 0.5)
                                .font(.system(size: 18, weight: .regular, design: .serif))
                                .scrollContentBackground(.hidden)
                        }
                    }
                    
                    
                    Button{
                        if entryType == .expense{
                            if (selectedCategory == nil && selectedUserCategory == nil) || price.isEmpty {
                                showValidationToast()
                                return
                            }
                        }
                        
                        if entryType == .income {
                            if incomeText.isEmpty {
                                showValidationToast()
                                return
                            }
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
                        Text(isEditMode ? "Save Changes" : "Add")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .font(.system(size: 18, weight: .medium, design: .serif))
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal)
                    .foregroundColor(.white)
                    .background(Color.green.gradient)
                    .cornerRadius(12)
                    Spacer()
                }
                .padding()
            }
            .onAppear {
                if let item = itemToEdit {
                    switch item {
                    case .expense(let expense):
                        entryType = .expense
                        price = String(expense.price)
                        dateValue = expense.date
                        note = expense.note
                        // Set category based on emoji and name
                        if let category = CategoryType.allCases.first(where: { $0.rawValue == "\(expense.emoji) \(expense.name)" }) {
                            selectedCategory = category
                        }
                    case .income(let income):
                        entryType = .income
                        incomeText = String(income.income)
                        dateValue = income.date
                        note = income.note
                    }
                }
                
                UserCategoryManager.shared.fetchCategories()
                userCategories = UserCategoryManager.shared.categories
            }
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
        } else {
            guard let incomeValue = Double(incomeText) else { return }
            
            let (_, namePart) = selectedUserCategory != nil ?
            (selectedUserCategory!.emoji, selectedUserCategory!.name) :
            (selectedCategory?.rawValue.split(separator: " ").first.map(String.init) ?? "💸",
             selectedCategory?.rawValue.split(separator: " ").dropFirst().first.map(String.init) ?? "Other")
            
            let newIncome = Income(
                type: "Income",
                emoji: "💰",
                name: namePart,
                income: incomeValue,
                date: dateValue,
                note: note
            )
            context.insert(newIncome)
        }
        
        do {
            try context.save()
            print("✅ Data saved successfully!")
        } catch {
            print("❌ Failed to save: \(error.localizedDescription)")
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
            print("✅ Updated successfully!")
        } catch {
            print("❌ Failed to update: \(error.localizedDescription)")
        }
    }
}

import SwiftUI
import SwiftData

struct AddExpenseBottomSheetView: View {
    @Environment(\.dismiss) var expenseBottomSheetDismiss
    @Environment(\.modelContext) private var context

    @State private var showToast: Bool = false
    @State private var showAddCategorySheet = false
    @State private var showDeleteAlert = false
    @State private var showAddDataToast = false
    @State private var categoryToDelete: UserCategory? = nil

    @State private var userCategories: [UserCategory] = []

    @State private var selectedUserCategory: UserCategory? = nil
    @State private var newCategoryName: String = ""
    @State private var newCategoryEmoji: String = ""

    var itemToEdit: HomeView.TransactionItem?
    let initialEntryType: EntryType

    @State private var showManualForm: Bool = false
    @State private var showAddIncomeScreen: Bool = false
    @State private var showAddExpenseScreen: Bool = false
    /// Preselection handed to the full expense page — "Add Purchase" already knows it's shopping.
    @State private var expenseScreenCategory: CategoryType? = nil
    @State private var showScanSheet: Bool = false
    @State private var showAddAccountSheet: Bool = false
    @State private var showGoalSheet: Bool = false

    @State private var entryType: EntryType
    @State private var selectedCategory: CategoryType? = nil

    @State private var price: String = ""
    @State private var dateValue: Date = Date()
    @State private var note: String = ""
    @State private var incomeText: String = ""
    @State private var isSubmitPressed = false

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

    private var isEditMode: Bool {
        itemToEdit != nil
    }

    enum EntryType: String, CaseIterable, Identifiable {
        case expense = "Expense"
        case income = "Income"

        var id: String { self.rawValue }
    }

    init(itemToEdit: HomeView.TransactionItem? = nil, initialEntryType: EntryType = .expense) {
        self.itemToEdit = itemToEdit
        self.initialEntryType = initialEntryType
        _entryType = State(initialValue: initialEntryType)
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
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            if isEditMode || showManualForm {
                manualEntryFormView
            } else {
                addNewChooserGrid
            }

            // Slide in from the trailing edge like a pushed screen, rather than
            // `.fullScreenCover`'s fixed cover-from-the-bottom animation — tapping a card
            // here should feel like moving deeper into one flow, not opening another sheet
            // on top of this one.
            if showAddIncomeScreen {
                // Income has its own full page rather than the shared manual form. Saving
                // closes this whole chooser too, rather than just returning to the grid —
                // the environment `dismiss()` naturally reaches the real presentation further
                // up since this screen isn't a presentation of its own; `onBackOverride`
                // handles the "no, go back to the grid" case explicitly.
                AddIncomeView(
                    onSaved: { expenseBottomSheetDismiss() },
                    onBackOverride: {
                        withAnimation(.easeInOut(duration: 0.28)) { showAddIncomeScreen = false }
                    }
                )
                .transition(.move(edge: .trailing))
                .zIndex(1)
            }

            if showAddExpenseScreen {
                // Same arrangement for expenses. The in-sheet manual form stays for editing an
                // existing item, where a half-height sheet is the right size for the job.
                AddExpenseView(
                    initialCategory: expenseScreenCategory,
                    onSaved: { expenseBottomSheetDismiss() },
                    onBackOverride: {
                        withAnimation(.easeInOut(duration: 0.28)) { showAddExpenseScreen = false }
                    }
                )
                .transition(.move(edge: .trailing))
                .zIndex(1)
            }

            if showAddAccountSheet {
                // Same push-style overlay as Income/Expense above, instead of a `.sheet`.
                AddAccountView(
                    onBackOverride: {
                        withAnimation(.easeInOut(duration: 0.28)) { showAddAccountSheet = false }
                    }
                )
                .transition(.move(edge: .trailing))
                .zIndex(1)
            }
        }
        .sheet(isPresented: $showScanSheet) {
            ScanView()
        }
        .sheet(isPresented: $showAddCategorySheet) {
            AddCategorySheet(
                entryType: entryType,
                isPresented: $showAddCategorySheet,
                newCategoryName: $newCategoryName,
                newCategoryEmoji: $newCategoryEmoji,
                showToast: $showAddDataToast,
                onAddExpenseCategory: {
                    fetchUserCategories()
                }
            )
        }
        .onAppear {
            fetchUserCategories()
            if let itemToEdit {
                showManualForm = true
                setupEditMode(itemToEdit)
            } else if initialEntryType == .income {
                // A caller asking for income straight away skips the chooser and goes to the
                // dedicated income page.
                withAnimation(.easeInOut(duration: 0.28)) { showAddIncomeScreen = true }
            }
        }
    }

    // MARK: - 1. Add New Chooser Grid View (Matching Reference Image)
    private var addNewChooserGrid: some View {
        VStack(spacing: 0) {
            // Same header every other full-screen form uses: a back button rather than the
            // close "X" a half-height sheet called for, now that this fills the whole page.
            ScreenHeader(
                title: "Add New",
                subtitle: "Choose what you want to add",
                onBack: { expenseBottomSheetDismiss() }
            )

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    // 2-Column Grid of 8 Add Cards
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        addOptionCard(
                            icon: "doc.text.fill",
                            iconColor: .appGreen,
                            bgColor: Color.appGreen.opacity(0.12),
                            title: "Add Expense",
                            subtitle: "Add a new expense manually"
                        ) {
                            expenseScreenCategory = nil
                            withAnimation(.easeInOut(duration: 0.28)) { showAddExpenseScreen = true }
                        }

                        addOptionCard(
                            icon: "banknote.fill",
                            iconColor: .appGreen,
                            bgColor: Color.appGreen.opacity(0.12),
                            title: "Add Income",
                            subtitle: "Add a new income source"
                        ) {
                            withAnimation(.easeInOut(duration: 0.28)) { showAddIncomeScreen = true }
                        }

                        addOptionCard(
                            icon: "creditcard.fill",
                            iconColor: Color(red: 249/255, green: 115/255, blue: 22/255),
                            bgColor: Color(red: 254/255, green: 243/255, blue: 235/255),
                            title: "Add Transfer",
                            subtitle: "Transfer between accounts"
                        ) {
                            withAnimation(.easeInOut(duration: 0.28)) { showAddAccountSheet = true }
                        }

                        addOptionCard(
                            icon: "target",
                            iconColor: Color(red: 147/255, green: 51/255, blue: 234/255),
                            bgColor: Color(red: 243/255, green: 232/255, blue: 255/255),
                            title: "Add Goal",
                            subtitle: "Create a new savings goal"
                        ) {
                            expenseBottomSheetDismiss()
                        }

                        addOptionCard(
                            icon: "calendar.badge.plus",
                            iconColor: Color(red: 37/255, green: 99/255, blue: 235/255),
                            bgColor: Color(red: 239/255, green: 246/255, blue: 255/255),
                            title: "Add Subscription",
                            subtitle: "Add a subscription or recurring bill"
                        ) {
                            expenseBottomSheetDismiss()
                        }

                        addOptionCard(
                            icon: "calendar.badge.clock",
                            iconColor: Color(red: 249/255, green: 115/255, blue: 22/255),
                            bgColor: Color(red: 254/255, green: 243/255, blue: 235/255),
                            title: "Add EMI",
                            subtitle: "Add a new EMI or loan payment"
                        ) {
                            expenseBottomSheetDismiss()
                        }

                        addOptionCard(
                            icon: "bag.fill",
                            iconColor: Color(red: 236/255, green: 72/255, blue: 153/255),
                            bgColor: Color(red: 252/255, green: 231/255, blue: 243/255),
                            title: "Add Purchase",
                            subtitle: "Add a purchase or shopping item"
                        ) {
                            expenseScreenCategory = .shopping
                            withAnimation(.easeInOut(duration: 0.28)) { showAddExpenseScreen = true }
                        }

                        addOptionCard(
                            icon: "doc.text.viewfinder",
                            iconColor: Color(red: 13/255, green: 148/255, blue: 136/255),
                            bgColor: Color(red: 204/255, green: 251/255, blue: 241/255),
                            title: "Upload Bill",
                            subtitle: "Scan and upload a bill or receipt"
                        ) {
                            showScanSheet = true
                        }
                    }

                    // Scan Bill with AI Banner
                    aiScanBanner

                    // Quick Actions Section
                    quickActionsSection
                }
                // Matches ScreenHeader's own 16pt inset, so the cards line up under the back
                // button rather than sitting 2pt off from where the old 18pt header used to be.
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
        }
    }

    @ViewBuilder
    private func addOptionCard(icon: String, iconColor: Color, bgColor: Color, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Circle()
                    .fill(bgColor)
                    .frame(width: 38, height: 38)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(iconColor)
                    )

                // No trailing chevron: the whole card is the tap target already, and at two
                // columns the text had only ~81pt to work with — enough to fit "Add Expense"
                // on one line at 0.8 minimum scale, but not enough for its own subtitle, which
                // truncated mid-word even with a 2-line allowance. Dropping the chevron gives
                // the text room to actually use that allowance.
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)

                    Text(subtitle)
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(11)
            .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Scan Bill with AI Banner
    private var aiScanBanner: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.appGreen.opacity(0.16))
                .frame(width: 42, height: 42)
                .overlay(
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.appGreen)
                )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("Scan Bill with AI")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Text("New")
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundColor(.appGreenDeep)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.appGreen.opacity(0.16))
                        .clipShape(Capsule())
                }

                Text("Extract details automatically using AI")
                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                Haptics.light()
                showScanSheet = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 13, weight: .bold))
                    Text("Scan Now")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
                .foregroundColor(.appGreenDeep)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 1)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color.appGreen.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Quick Actions Section
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            HStack(spacing: 0) {
                quickActionButton(icon: "square.and.pencil", iconColor: .appGreen, bgColor: Color.appGreen.opacity(0.12), title: "Add Note")
                quickActionButton(icon: "car.fill", iconColor: Color(red: 37/255, green: 99/255, blue: 235/255), bgColor: Color(red: 239/255, green: 246/255, blue: 255/255), title: "Add Vehicle")
                quickActionButton(icon: "person.2.fill", iconColor: Color(red: 147/255, green: 51/255, blue: 234/255), bgColor: Color(red: 243/255, green: 232/255, blue: 255/255), title: "Split Expense")
                quickActionButton(icon: "bookmark.fill", iconColor: Color(red: 249/255, green: 115/255, blue: 22/255), bgColor: Color(red: 254/255, green: 243/255, blue: 235/255), title: "Add Reminder")
            }
        }
    }

    @ViewBuilder
    private func quickActionButton(icon: String, iconColor: Color, bgColor: Color, title: String) -> some View {
        Button {
            Haptics.light()
        } label: {
            VStack(spacing: 8) {
                Circle()
                    .fill(bgColor)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .bold))
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
        .buttonStyle(.plain)
    }

    // MARK: - 2. Manual Entry Form View (Expense / Income Logging)
    private var manualEntryFormView: some View {
        VStack(spacing: 0) {
            // Form Header with Back & Close Buttons
            HStack {
                if !isEditMode {
                    Button {
                        Haptics.light()
                        withAnimation {
                            showManualForm = false
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .bold))
                            Text("Back")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.appGreen)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Text(submitTitle)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Spacer()

                Button {
                    expenseBottomSheetDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .resizable()
                        .frame(width: 26, height: 26)
                        .foregroundStyle(.gray.opacity(0.6), Color.white)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
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
                            onAddCategoryTapped: { showAddCategorySheet = true },
                            onDeleteCategory: { category in
                                categoryToDelete = category
                                showDeleteAlert = true
                            },
                            price: $price,
                            dateValue: $dateValue,
                            note: $note,
                            addNewCategory: { showAddCategorySheet = true }
                        )
                    } else {
                        IncomeSection(
                            isEditMode: isEditMode,
                            userCategories: $userCategories,
                            selectedUserCategory: $selectedUserCategory,
                            selectedCategory: $selectedCategory,
                            onAddCategoryTapped: { showAddCategorySheet = true },
                            onDeleteCategory: { category in
                                categoryToDelete = category
                                showDeleteAlert = true
                            },
                            incomeText: $incomeText,
                            dateValue: $dateValue,
                            note: $note,
                            addNewIncomeCategory: { showAddCategorySheet = true }
                        )
                    }

                    VStack(spacing: 16) {
                        DatePicker("Date", selection: $dateValue, displayedComponents: .date)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))

                        TextField("Add Note (Optional)", text: $note)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding()
                    .background(Color.appSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal)

                    // Submit Button
                    Button {
                        submitAction()
                    } label: {
                        Text(submitTitle)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(isSubmitEnabled ? Color.appGreen : Color.gray.opacity(0.4))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .disabled(!isSubmitEnabled)
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
        }
    }

    // MARK: - Data Helpers
    private func fetchUserCategories() {
        userCategories = UserCategoryManager.shared.categories
    }

    private func setupEditMode(_ item: HomeView.TransactionItem) {
        switch item {
        case .expense(let exp):
            entryType = .expense
            price = String(format: "%.2f", exp.price)
            note = exp.note
            dateValue = exp.date
            selectedCategory = CategoryType(rawValue: exp.name)
        case .income(let inc):
            entryType = .income
            incomeText = String(format: "%.2f", inc.income)
            note = inc.note
            dateValue = inc.date
            selectedCategory = CategoryType(rawValue: inc.type)
        }
    }

    private func submitAction() {
        Haptics.medium()
        if isEditMode, let item = itemToEdit {
            switch item {
            case .expense(let exp):
                exp.price = Double(price) ?? exp.price
                exp.note = note
                exp.date = dateValue
                if let cat = selectedCategory { exp.name = cat.rawValue }
                else if let uCat = selectedUserCategory { exp.name = uCat.name }
            case .income(let inc):
                inc.income = Double(incomeText) ?? inc.income
                inc.note = note
                inc.date = dateValue
                if let cat = selectedCategory { inc.type = cat.rawValue }
                else if let uCat = selectedUserCategory { inc.type = uCat.name }
            }
        } else {
            if entryType == .expense {
                let p = Double(price) ?? 0
                let catName = selectedCategory?.rawValue ?? selectedUserCategory?.name ?? "General"
                let newExpense = Expense(type: catName, name: catName, price: p, date: dateValue, note: note)
                context.insert(newExpense)
            } else {
                let inc = Double(incomeText) ?? 0
                let catName = selectedCategory?.rawValue ?? selectedUserCategory?.name ?? "Income"
                let newIncome = Income(type: catName, name: catName, income: inc, date: dateValue, note: note)
                context.insert(newIncome)
            }
        }
        try? context.save()
        expenseBottomSheetDismiss()
    }
}

#Preview {
    AddExpenseBottomSheetView()
}

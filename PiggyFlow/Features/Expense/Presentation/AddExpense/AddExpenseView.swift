import SwiftUI
import SwiftData

/// Full-page expense entry.
///
/// The bottom sheet in `AddExpenseBottomSheetView` captures an amount, a category chip and a
/// note — enough for a quick entry, not enough to answer "where did this go and how did I pay
/// for it?" later. This screen is the expense counterpart to `AddIncomeView`: same layout, same
/// pickers, the fields that matter for an expense.
struct AddExpenseView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    /// Preselects the category — "Add Purchase" in the chooser already knows it's shopping.
    var initialCategory: AddExpenseBottomSheetView.CategoryType? = nil

    /// Called after a successful save, so a presenting sheet can close itself behind this
    /// screen instead of leaving the user staring at the chooser they came from.
    var onSaved: (() -> Void)? = nil

    /// Overrides the back button's dismissal. Callers that present this screen as a real
    /// `.fullScreenCover` don't need it — `dismiss()` already closes that cover correctly.
    /// Callers that instead show it as a transitioning overlay (no real presentation of its
    /// own) must supply this, or `dismiss()` would fall through to whatever real presentation
    /// sits further up the hierarchy and close more than just this screen.
    var onBackOverride: (() -> Void)? = nil

    // The picker rows are shared with `AddIncomeView` — they carry its Income-era names but
    // nothing in them is income-specific.
    private typealias Option = AddIncomeView.Option

    // MARK: - Form state

    @State private var amountText: String = ""
    @State private var currency: AddIncomeView.CurrencyOption = .inr
    @State private var category: Option = ExpenseCatalog.categories.first
        ?? Option(id: "🔖 Others", title: "Others", icon: "square.grid.2x2.fill")
    @State private var date: Date = Date()
    @State private var paymentMethod: Option = ExpenseCatalog.paymentMethods[0]
    @State private var account: Option = ExpenseCatalog.accounts[0]
    @State private var merchant: String = ""
    @State private var descriptionText: String = ""
    @State private var tags: [String] = []

    // MARK: - Presentation state

    @State private var activePicker: PickerField?
    @State private var showDateTimeSheet = false
    @State private var showTagSheet = false
    @State private var showScanSheet = false
    @State private var saveError: AppError?
    @State private var showSavedToast = false
    @State private var didApplyInitialCategory = false

    /// The dropdown currently being edited. One `@State` rather than a `Bool` per row, so two
    /// sheets can never race each other open.
    private enum PickerField: String, Identifiable {
        case currency, category, paymentMethod, account
        var id: String { rawValue }
    }

    private var amountValue: Double { AmountInput.value(of: amountText) }

    private var canSave: Bool { amountValue > 0 }

    private static let descriptionLimit = 100

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        amountCard
                        categoryField
                        dateTimeField
                        paymentMethodField
                        accountField
                        merchantField
                        descriptionField
                        tagField
                        insightBanner
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 16)
                }
                // Inset by the action bar itself, so the last field always clears it however
                // the buttons wrap — a fixed height here drifts the moment the bar changes.
                .safeAreaInset(edge: .bottom) { bottomActionBar }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            guard !didApplyInitialCategory, let initialCategory else { return }
            didApplyInitialCategory = true
            if let match = ExpenseCatalog.categories.first(where: { $0.id == initialCategory.rawValue }) {
                category = match
            }
        }
        .sheet(item: $activePicker) { field in
            picker(for: field)
        }
        .sheet(isPresented: $showDateTimeSheet) {
            IncomeDateTimeSheet(date: $date)
        }
        .sheet(isPresented: $showTagSheet) {
            IncomeTagSheet(tags: $tags)
        }
        .fullScreenCover(isPresented: $showScanSheet) {
            ScanView()
        }
        .alert(saveError?.title ?? "", isPresented: errorAlertBinding, presenting: saveError) { _ in
            Button("OK", role: .cancel) { saveError = nil }
        } message: { error in
            Text(error.errorDescription ?? "")
        }
        .overlay(alignment: .top) { savedToast }
    }

    // MARK: - Header

    private var headerBar: some View {
        ScreenHeader(
            title: "Add Expense",
            subtitle: "Track every expense to stay on top",
            onBack: { onBackOverride?() ?? dismiss() }
        ) {
            ScreenHeaderAction(icon: "doc.text.viewfinder", title: "Receipt") {
                showScanSheet = true
            }
        }
    }

    // MARK: - Amount

    private var amountCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Amount")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)

            HStack(spacing: 10) {
                Text(currency.symbol)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                TextField("0", text: amountBinding)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)

                Button {
                    Haptics.light()
                    activePicker = .currency
                } label: {
                    HStack(spacing: 6) {
                        Text(currency.label)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                        Image(systemName: AppIcon.Nav.expand)
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .liftedControl(cornerRadius: 18)
    }

    /// Re-formats on every keystroke so the field always reads like money (`1,250`) rather
    /// than a raw digit run. The stored text is the display text; `amountValue` parses it back.
    private var amountBinding: Binding<String> {
        Binding(
            get: { amountText },
            set: { amountText = AmountInput.formatted($0) }
        )
    }

    // MARK: - Fields

    private var categoryField: some View {
        labelled("Category") {
            dropdownRow(icon: category.icon, iconStyle: .solid, value: category.title) {
                activePicker = .category
            }
        }
    }

    private var dateTimeField: some View {
        labelled("Date & Time") {
            Button {
                Haptics.light()
                showDateTimeSheet = true
            } label: {
                HStack(spacing: 0) {
                    HStack(spacing: 12) {
                        iconTile("calendar", style: .tinted)
                        Text(date.formatted(.dateTime.day().month(.wide).year()))
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Divider()
                        .frame(height: 30)
                        .padding(.trailing, 14)

                    HStack(spacing: 12) {
                        iconTile("clock", style: .tinted)
                        Text(date.formatted(.dateTime.hour().minute()))
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: AppIcon.Nav.expand)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .liftedControl(cornerRadius: 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var paymentMethodField: some View {
        labelled("Payment Method") {
            dropdownRow(icon: paymentMethod.icon, iconStyle: .tinted, value: paymentMethod.title) {
                activePicker = .paymentMethod
            }
        }
    }

    private var accountField: some View {
        labelled("Account") {
            dropdownRow(icon: account.icon, iconStyle: .tinted, value: account.title) {
                activePicker = .account
            }
        }
    }

    private var merchantField: some View {
        labelled("Merchant (Optional)") {
            HStack(spacing: 12) {
                iconTile("storefront", style: .tinted)
                TextField("e.g. Zomato, Reliance Fresh", text: $merchant)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .textInputAutocapitalization(.words)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .liftedControl(cornerRadius: 14)
        }
    }

    private var descriptionField: some View {
        labelled("Description (Optional)") {
            VStack(alignment: .trailing, spacing: 2) {
                HStack(alignment: .top, spacing: 12) {
                    iconTile("doc.text", style: .tinted)

                    ZStack(alignment: .topLeading) {
                        if descriptionText.isEmpty {
                            Text("What was this expense for?")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary.opacity(0.7))
                                .padding(.top, 8)
                                .allowsHitTesting(false)
                        }

                        TextEditor(text: $descriptionText)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .scrollContentBackground(.hidden)
                            .frame(height: 64)
                    }
                }

                Text("\(descriptionText.count)/\(Self.descriptionLimit)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .liftedControl(cornerRadius: 14)
            .onChange(of: descriptionText) { _, newValue in
                if newValue.count > Self.descriptionLimit {
                    descriptionText = String(newValue.prefix(Self.descriptionLimit))
                }
            }
        }
    }

    private var tagField: some View {
        labelled("Add to") {
            Button {
                Haptics.light()
                showTagSheet = true
            } label: {
                HStack(spacing: 12) {
                    iconTile("tag", style: .tinted)

                    if tags.isEmpty {
                        Text("Add Tag")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary.opacity(0.7))
                    } else {
                        Text(tags.joined(separator: ", "))
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: AppIcon.Nav.forward)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .liftedControl(cornerRadius: 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Insight banner

    // Matches TrackerInfoBanner's layout (text left, one tinted icon circle right) rather
    // than the leading-icon-plus-composite-glyph arrangement this used to have — the glyph
    // stacked three separate SF Symbols with manual offsets to stand in for missing
    // illustration artwork, and next to the app's usual single clean icon it read as clutter.
    private var insightBanner: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Keep your expenses organised!")
                    .font(.system(size: 14.5, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text("Add categories, tags and notes to track better.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            TintedIconCircle(color: .appGreen, size: 48, cornerRadius: 14) {
                Image(systemName: "list.clipboard.fill")
                    .font(.system(size: 21, weight: .semibold))
            }
        }
        .padding(14)
        .background(Color.appGreen.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Action bar

    private var bottomActionBar: some View {
        VStack(spacing: 6) {
            Button {
                save(addAnother: false)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 15, weight: .bold))
                    Text("Save Expense")
                        .font(.system(size: 15.5, weight: .bold, design: .rounded))
                }
                .primaryButton(tint: .appGreenDeep, enabled: canSave, cornerRadius: 30)
            }
            .buttonStyle(.plain)
            .disabled(!canSave)

            Button {
                save(addAnother: true)
            } label: {
                Text("Save & Add Another")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.appGreen)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .disabled(!canSave)
            .opacity(canSave ? 1 : 0.4)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .background(Color.appBackground.ignoresSafeArea(edges: .bottom))
    }

    private var savedToast: some View {
        Group {
            if showSavedToast {
                HStack(spacing: 8) {
                    Image(systemName: AppIcon.Status.success)
                        .font(.system(size: 14, weight: .bold))
                    Text("Expense saved")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
                .background(Color.appGreenDeep)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 6)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showSavedToast)
    }

    // MARK: - Reusable row pieces

    private enum IconStyle { case solid, tinted }

    @ViewBuilder
    private func labelled<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func iconTile(_ systemName: String, style: IconStyle) -> some View {
        switch style {
        case .solid:
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.appGreen)
                .frame(width: 30, height: 30)
                .overlay(
                    Image(systemName: systemName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                )
        case .tinted:
            TintedIconCircle(color: .appGreen, size: 30, cornerRadius: 10) {
                Image(systemName: systemName)
                    .font(.system(size: 15, weight: .semibold))
            }
        }
    }

    @ViewBuilder
    private func dropdownRow(
        icon: String,
        iconStyle: IconStyle,
        value: String?,
        placeholder: String = "",
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.light()
            action()
        } label: {
            HStack(spacing: 12) {
                iconTile(icon, style: iconStyle)

                Text(value ?? placeholder)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(value == nil ? .secondary.opacity(0.7) : .primary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Image(systemName: AppIcon.Nav.expand)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .liftedControl(cornerRadius: 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Pickers

    @ViewBuilder
    private func picker(for field: PickerField) -> some View {
        switch field {
        case .currency:
            IncomeOptionPickerSheet(
                title: "Currency",
                options: AddIncomeView.CurrencyOption.all.map { $0.option },
                selectedID: currency.code
            ) { picked in
                currency = AddIncomeView.CurrencyOption.all.first { $0.code == picked.id } ?? .inr
            }
        case .category:
            IncomeOptionPickerSheet(
                title: "Category",
                options: ExpenseCatalog.categories + ExpenseCatalog.userCategories(),
                selectedID: category.id
            ) { category = $0 }
        case .paymentMethod:
            IncomeOptionPickerSheet(
                title: "Payment Method",
                options: ExpenseCatalog.paymentMethods,
                selectedID: paymentMethod.id
            ) { paymentMethod = $0 }
        case .account:
            IncomeOptionPickerSheet(
                title: "Account",
                options: ExpenseCatalog.accounts,
                selectedID: account.id
            ) { account = $0 }
        }
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )
    }

    // MARK: - Save

    /// Persists through `SaveExpenseUseCase` rather than inserting into the context directly —
    /// that's what applies validation and queues the record for cloud sync.
    private func save(addAnother: Bool) {
        guard canSave else { return }
        Haptics.medium()

        let trimmedMerchant = merchant.trimmingCharacters(in: .whitespacesAndNewlines)

        let input = SaveExpenseUseCase.Input(
            category: category.id,
            // The list rows show `name`, so an entry with no merchant reads as its category
            // rather than as a blank line.
            name: trimmedMerchant.isEmpty ? category.title : trimmedMerchant,
            amount: amountValue,
            date: date,
            emoji: category.emoji,
            note: descriptionText,
            currencyCode: currency.code,
            merchant: merchant,
            paymentMethod: paymentMethod.title,
            account: account.title,
            tags: tags
        )

        do {
            try AppContainer.shared.useCases.saveExpense(context: context).execute(input)
        } catch {
            saveError = AppError.wrap(error)
            return
        }

        if addAnother {
            resetForNextEntry()
        } else {
            dismiss()
            onSaved?()
        }
    }

    /// Clears the transaction-specific fields but keeps the context the user just set up
    /// (category, account, payment method, currency) — consecutive entries in one session are
    /// usually the same shape, a few shop receipts at a time.
    private func resetForNextEntry() {
        amountText = ""
        merchant = ""
        descriptionText = ""
        tags = []
        date = Date()
        showSavedToast = true

        Task {
            try? await Task.sleep(for: .seconds(1.6))
            showSavedToast = false
        }
    }
}

// MARK: - Catalog

/// The option lists behind the expense dropdowns.
///
/// Categories come from `CategoryType.expenseDefaultCategories`, so a category chosen here is
/// the same string the home list, stats screen and edit sheet already recognise. Accounts and
/// payment methods mirror the demo data in `AccountsView`; once accounts are persisted rather
/// than hardcoded there, both lists should read from the store instead.
enum ExpenseCatalog {

    private static let categoryIcons: [String: String] = [
        AddExpenseBottomSheetView.CategoryType.food.rawValue: "fork.knife",
        AddExpenseBottomSheetView.CategoryType.home.rawValue: "house.fill",
        AddExpenseBottomSheetView.CategoryType.groceries.rawValue: "cart.fill",
        AddExpenseBottomSheetView.CategoryType.transport.rawValue: "bus.fill",
        AddExpenseBottomSheetView.CategoryType.entertainment.rawValue: "play.rectangle.fill",
        AddExpenseBottomSheetView.CategoryType.drinks.rawValue: "wineglass.fill",
        AddExpenseBottomSheetView.CategoryType.shopping.rawValue: "bag.fill",
        AddExpenseBottomSheetView.CategoryType.powerBill.rawValue: "bolt.fill",
        AddExpenseBottomSheetView.CategoryType.phone.rawValue: "iphone",
        AddExpenseBottomSheetView.CategoryType.internet.rawValue: "wifi",
        AddExpenseBottomSheetView.CategoryType.fuel.rawValue: "fuelpump.fill",
        AddExpenseBottomSheetView.CategoryType.others.rawValue: "square.grid.2x2.fill"
    ]

    static let categories: [AddIncomeView.Option] = AddExpenseBottomSheetView.CategoryType
        .expenseDefaultCategories
        .map { category in
            AddIncomeView.Option(
                id: category.rawValue,
                title: displayName(of: category.rawValue),
                icon: categoryIcons[category.rawValue] ?? "square.grid.2x2.fill",
                emoji: emoji(of: category.rawValue)
            )
        }

    /// Categories the user added themselves.
    static func userCategories() -> [AddIncomeView.Option] {
        UserCategoryManager.shared.categories.map { category in
            AddIncomeView.Option(
                id: category.name,
                title: category.name,
                icon: "square.grid.2x2.fill",
                subtitle: "Your category",
                emoji: category.emoji
            )
        }
    }

    static let paymentMethods: [AddIncomeView.Option] = [
        .init(id: "HDFC Bank •••• 2345", title: "HDFC Bank •••• 2345", icon: AppIcon.Finance.creditCard, subtitle: "Debit card"),
        .init(id: "SBI Credit Card •••• 4412", title: "SBI Credit Card •••• 4412", icon: AppIcon.Finance.creditCard, subtitle: "Credit card"),
        .init(id: "UPI", title: "UPI", icon: "indianrupeesign.circle.fill", subtitle: "PhonePe, GPay, Paytm"),
        .init(id: "Cash", title: "Cash", icon: AppIcon.Finance.cash, subtitle: "Paid in hand"),
        .init(id: "Net Banking", title: "Net Banking", icon: AppIcon.Finance.bank, subtitle: "Paid from your bank")
    ]

    static let accounts: [AddIncomeView.Option] = [
        .init(id: "Personal Account", title: "Personal Account", icon: AppIcon.Finance.wallet),
        .init(id: "Business Account", title: "Business Account", icon: "briefcase.fill"),
        .init(id: "Savings Account", title: "Savings Account", icon: AppIcon.Finance.bank),
        .init(id: "Joint Account", title: "Joint Account", icon: "person.2.fill")
    ]

    /// `"🍔 Food"` → `"Food"`. The stored raw value keeps its emoji; the row shows an SF Symbol
    /// instead, so the emoji would read as a duplicate icon.
    private static func displayName(of rawValue: String) -> String {
        let stripped = rawValue.drop(while: { !$0.isLetter })
        let name = stripped.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? rawValue : name
    }

    private static func emoji(of rawValue: String) -> String {
        String(rawValue.prefix(while: { !$0.isLetter })).trimmingCharacters(in: .whitespaces)
    }
}

#Preview {
    AddExpenseView()
        .modelContainer(DataManager.shared.localContainer)
}

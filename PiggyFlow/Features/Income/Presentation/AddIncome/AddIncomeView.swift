import SwiftUI
import SwiftData

/// Full-page income entry.
///
/// The bottom-sheet form in `AddExpenseBottomSheetView` treats income as a variant of an
/// expense — an amount, a category chip and a note. Income needs more than that to be worth
/// reporting on later (where it came from, which account it landed in, what kind of payment
/// it was), and a half-height sheet can't hold those fields without turning into a scroller
/// fighting the keyboard. So income gets its own screen.
struct AddIncomeView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    /// Called after a successful save. Lets a presenting sheet close itself behind this
    /// screen instead of leaving the user staring at the chooser they came from.
    var onSaved: (() -> Void)? = nil

    /// Overrides the back button's dismissal. Callers that present this screen as a real
    /// `.fullScreenCover` don't need it — `dismiss()` already closes that cover correctly.
    /// Callers that instead show it as a transitioning overlay (no real presentation of its
    /// own) must supply this, or `dismiss()` would fall through to whatever real presentation
    /// sits further up the hierarchy and close more than just this screen.
    var onBackOverride: (() -> Void)? = nil

    // MARK: - Form state

    @State private var amountText: String = ""
    @State private var currency: CurrencyOption = .inr
    @State private var source: Option = IncomeCatalog.sources.first ?? Option(id: "Income", title: "Income", icon: "banknote.fill")
    @State private var date: Date = Date()
    @State private var paymentMethod: Option?
    @State private var account: Option = IncomeCatalog.accounts()[0]
    @State private var payer: String = ""
    @State private var incomeType: Option?
    @State private var descriptionText: String = ""
    @State private var tags: [String] = []

    // MARK: - Presentation state

    @State private var activePicker: PickerField?
    @State private var showDateTimeSheet = false
    @State private var showTagSheet = false
    @State private var showScanSheet = false
    @State private var saveError: AppError?
    @State private var showSavedToast = false

    /// The dropdown currently being edited. One `@State` rather than a `Bool` per row, so two
    /// sheets can never race each other open.
    private enum PickerField: String, Identifiable {
        case currency, source, paymentMethod, account, incomeType
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
                        sourceField
                        dateTimeField
                        paymentMethodField
                        accountField
                        payerField
                        typeField
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
            title: "Add Income",
            subtitle: "Record income and grow your finances",
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

    /// Re-formats on every keystroke so the field always reads like money (`50,000`) rather
    /// than a raw digit run. The stored text is the display text; `amountValue` parses it back.
    private var amountBinding: Binding<String> {
        Binding(
            get: { amountText },
            set: { amountText = AmountInput.formatted($0) }
        )
    }

    // MARK: - Fields

    private var sourceField: some View {
        labelled("Source of Income") {
            dropdownRow(icon: source.icon, iconStyle: .solid, value: source.title) {
                activePicker = .source
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
            dropdownRow(
                icon: paymentMethod?.icon ?? AppIcon.Finance.creditCard,
                iconStyle: .tinted,
                value: paymentMethod?.title,
                placeholder: "Select payment method"
            ) {
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

    private var payerField: some View {
        labelled("Employer / Payer (Optional)") {
            HStack(spacing: 12) {
                iconTile("building.2", style: .tinted)
                TextField("e.g. Your Company Name", text: $payer)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .textInputAutocapitalization(.words)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .liftedControl(cornerRadius: 14)
        }
    }

    private var typeField: some View {
        labelled("Type (Optional)") {
            dropdownRow(
                icon: "tag",
                iconStyle: .tinted,
                value: incomeType?.title,
                placeholder: "Select a type"
            ) {
                activePicker = .incomeType
            }
        }
    }

    private var descriptionField: some View {
        labelled("Description (Optional)") {
            VStack(alignment: .trailing, spacing: 2) {
                HStack(alignment: .top, spacing: 12) {
                    iconTile("doc.text", style: .tinted)

                    ZStack(alignment: .topLeading) {
                        if descriptionText.isEmpty {
                            Text("Add a note (e.g. May salary, Freelance project)")
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
                Text("Track income to know your real growth")
                    .font(.system(size: 14.5, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text("Monitoring income helps you plan better and achieve your goals.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            TintedIconCircle(color: .appGreen, size: 48, cornerRadius: 14) {
                Image(systemName: AppIcon.Chart.trend)
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
                    Text("Save Income")
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
                    Text("Income saved")
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
                options: CurrencyOption.all.map { $0.option },
                selectedID: currency.code
            ) { picked in
                currency = CurrencyOption.all.first { $0.code == picked.id } ?? .inr
            }
        case .source:
            IncomeOptionPickerSheet(
                title: "Source of Income",
                options: IncomeCatalog.sources + IncomeCatalog.userSources(),
                selectedID: source.id
            ) { source = $0 }
        case .paymentMethod:
            IncomeOptionPickerSheet(
                title: "Payment Method",
                options: IncomeCatalog.paymentMethods,
                selectedID: paymentMethod?.id
            ) { paymentMethod = $0 }
        case .account:
            IncomeOptionPickerSheet(
                title: "Account",
                options: IncomeCatalog.accounts(),
                selectedID: account.id
            ) { account = $0 }
        case .incomeType:
            IncomeOptionPickerSheet(
                title: "Type",
                options: IncomeCatalog.incomeTypes,
                selectedID: incomeType?.id
            ) { incomeType = $0 }
        }
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )
    }

    // MARK: - Save

    /// Persists through `SaveIncomeUseCase` rather than inserting into the context directly —
    /// that's what applies validation and queues the record for cloud sync.
    private func save(addAnother: Bool) {
        guard canSave else { return }
        Haptics.medium()

        let input = SaveIncomeUseCase.Input(
            category: source.id,
            name: payer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? source.title : payer,
            amount: amountValue,
            date: date,
            emoji: source.emoji,
            note: descriptionText,
            currencyCode: currency.code,
            payer: payer,
            paymentMethod: paymentMethod?.title ?? "",
            account: account.title,
            incomeType: incomeType?.title ?? "",
            tags: tags
        )

        do {
            try AppContainer.shared.useCases.saveIncome(context: context).execute(input)
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
    /// (source, account, payer, currency) — the second salary entry of a session is almost
    /// always the same shape as the first.
    private func resetForNextEntry() {
        amountText = ""
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

// MARK: - Option model

extension AddIncomeView {

    /// One row in a dropdown. `id` is what gets persisted, `title` is what's shown — they
    /// differ for income sources, where the stored value keeps the emoji prefix the rest of
    /// the app matches on (`"💼 Salary"`).
    struct Option: Identifiable, Hashable {
        let id: String
        let title: String
        let icon: String
        var subtitle: String = ""
        var emoji: String = ""
    }

    struct CurrencyOption: Hashable {
        let code: String
        let symbol: String
        let name: String

        var label: String { "\(code) (\(symbol))" }

        var option: Option {
            Option(id: code, title: label, icon: "banknote", subtitle: name)
        }

        static let inr = CurrencyOption(code: "INR", symbol: "₹", name: "Indian Rupee")

        static let all: [CurrencyOption] = [
            inr,
            CurrencyOption(code: "USD", symbol: "$", name: "US Dollar"),
            CurrencyOption(code: "EUR", symbol: "€", name: "Euro"),
            CurrencyOption(code: "GBP", symbol: "£", name: "Pound Sterling"),
            CurrencyOption(code: "AED", symbol: "د.إ", name: "UAE Dirham"),
            CurrencyOption(code: "SGD", symbol: "S$", name: "Singapore Dollar")
        ]
    }
}

// MARK: - Catalog

/// The option lists behind the dropdowns.
///
/// Sources are derived from `CategoryType.incomeDefaultCategories` so a source saved here is
/// the same string the home list, detail screen and edit sheet already recognise. Accounts read
/// from the real `AccountManager` store the user builds up in `AccountsView`.
enum IncomeCatalog {

    private static let sourceIcons: [AddIncomeView.Option.ID: String] = [
        AddExpenseBottomSheetView.CategoryType.salary.rawValue: "briefcase.fill",
        AddExpenseBottomSheetView.CategoryType.freelance.rawValue: "laptopcomputer",
        AddExpenseBottomSheetView.CategoryType.investments.rawValue: "chart.line.uptrend.xyaxis",
        AddExpenseBottomSheetView.CategoryType.rental.rawValue: "house.fill",
        AddExpenseBottomSheetView.CategoryType.interest.rawValue: "percent",
        AddExpenseBottomSheetView.CategoryType.bonus.rawValue: "gift.fill",
        AddExpenseBottomSheetView.CategoryType.gifts.rawValue: "sparkles",
        AddExpenseBottomSheetView.CategoryType.refund.rawValue: "arrow.uturn.backward",
        AddExpenseBottomSheetView.CategoryType.others.rawValue: "square.grid.2x2.fill"
    ]

    static let sources: [AddIncomeView.Option] = AddExpenseBottomSheetView.CategoryType
        .incomeDefaultCategories
        .map { category in
            AddIncomeView.Option(
                id: category.rawValue,
                title: displayName(of: category.rawValue),
                icon: sourceIcons[category.rawValue] ?? "banknote.fill",
                emoji: emoji(of: category.rawValue)
            )
        }

    /// Categories the user added themselves, so they're selectable as income sources too.
    static func userSources() -> [AddIncomeView.Option] {
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
        .init(id: "HDFC Bank •••• 2345", title: "HDFC Bank •••• 2345", icon: AppIcon.Finance.bank, subtitle: "Bank transfer"),
        .init(id: "SBI Bank •••• 1234", title: "SBI Bank •••• 1234", icon: AppIcon.Finance.bank, subtitle: "Bank transfer"),
        .init(id: "UPI", title: "UPI", icon: "indianrupeesign.circle.fill", subtitle: "PhonePe, GPay, Paytm"),
        .init(id: "Cash", title: "Cash", icon: AppIcon.Finance.cash, subtitle: "Received in hand"),
        .init(id: "Cheque", title: "Cheque", icon: "doc.text.fill", subtitle: "Deposited by cheque")
    ]

    /// Real accounts the user has added — falls back to a single placeholder so `[0]`-indexing
    /// call sites never crash before the user has added their first real account.
    static func accounts() -> [AddIncomeView.Option] {
        let real = AccountManager.shared.accounts.map { account in
            AddIncomeView.Option(id: account.name, title: account.name, icon: account.iconName, subtitle: account.subType)
        }
        return real.isEmpty
            ? [AddIncomeView.Option(id: "Cash", title: "Cash", icon: AppIcon.Finance.cash, subtitle: "Add an account to see it here")]
            : real
    }

    static let incomeTypes: [AddIncomeView.Option] = [
        .init(id: "Monthly Salary", title: "Monthly Salary", icon: "calendar", subtitle: "Repeats every month"),
        .init(id: "One-time", title: "One-time", icon: "1.circle.fill", subtitle: "A single payment"),
        .init(id: "Recurring", title: "Recurring", icon: AppIcon.Finance.subscription, subtitle: "Repeats on a schedule"),
        .init(id: "Reimbursement", title: "Reimbursement", icon: "arrow.uturn.backward", subtitle: "Money paid back to you"),
        .init(id: "Advance", title: "Advance", icon: "clock.arrow.circlepath", subtitle: "Paid ahead of time")
    ]

    static let suggestedTags: [String] = [
        "Salary", "Side Hustle", "Passive", "Business", "Family", "Tax Free", "Reimbursed"
    ]

    /// `"💼 Salary"` → `"Salary"`. The stored raw value keeps its emoji; the row shows an SF
    /// Symbol instead, so the emoji would read as a duplicate icon.
    private static func displayName(of rawValue: String) -> String {
        let stripped = rawValue.drop(while: { !$0.isLetter })
        let name = stripped.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? rawValue : name
    }

    private static func emoji(of rawValue: String) -> String {
        String(rawValue.prefix(while: { !$0.isLetter })).trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Amount input

/// Keeps the amount field readable while it's being typed.
enum AmountInput {

    private static let grouping: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: AppConstants.Currency.localeIdentifier)
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    /// Digits in, grouped money out. Group separators already in the input are dropped before
    /// re-grouping, so the field stays stable as the user types into the middle of it.
    static func formatted(_ input: String) -> String {
        let (integer, fraction) = split(input)
        guard !integer.isEmpty else { return "" }

        let grouped = grouping.string(from: NSNumber(value: Int(integer) ?? 0)) ?? integer
        // A non-nil but empty fraction is the moment right after the decimal point is typed —
        // the point has to survive re-formatting or it can never be followed by digits.
        guard let fraction else { return grouped }
        return "\(grouped).\(fraction)"
    }

    static func value(of input: String) -> Double {
        let (integer, fraction) = split(input)
        guard !integer.isEmpty else { return 0 }
        let decimals = (fraction?.isEmpty ?? true) ? "0" : fraction!
        return Double("\(integer).\(decimals)") ?? 0
    }

    /// Splits raw keystrokes into an integer run and up to two decimal places, discarding
    /// anything else (group separators, a second decimal point, pasted currency symbols).
    private static func split(_ input: String) -> (integer: String, fraction: String?) {
        var integer = ""
        var fraction: String?

        for character in input {
            if character.isNumber {
                if fraction == nil {
                    if integer.count < 12 { integer.append(character) }
                } else if fraction!.count < 2 {
                    fraction!.append(character)
                }
            } else if (character == "." || character == ",") && fraction == nil && !integer.isEmpty {
                // A comma reaching here is our own group separator, which `formatted` re-adds.
                if character == "." { fraction = "" }
            }
        }

        return (integer, fraction)
    }
}

// MARK: - Option picker sheet

/// Shared dropdown body. Every picker on this screen is the same list of icon + title +
/// subtitle rows, so they share one sheet rather than five near-identical ones.
struct IncomeOptionPickerSheet: View {

    @Environment(\.dismiss) private var dismiss

    let title: String
    let options: [AddIncomeView.Option]
    let selectedID: String?
    let onSelect: (AddIncomeView.Option) -> Void

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                        Button {
                            Haptics.light()
                            onSelect(option)
                            dismiss()
                        } label: {
                            HStack(spacing: 14) {
                                TintedIconCircle(color: .appGreen, size: 38, cornerRadius: 11) {
                                    Image(systemName: option.icon)
                                        .font(.system(size: 16, weight: .semibold))
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(option.title)
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .foregroundColor(.primary)

                                    if !option.subtitle.isEmpty {
                                        Text(option.subtitle)
                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Spacer(minLength: 8)

                                if option.id == selectedID {
                                    Image(systemName: AppIcon.Status.success)
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.appGreen)
                                }
                            }
                            .flatRow()
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if index < options.count - 1 {
                            RowDivider(leadingInset: 68)
                        }
                    }
                }
                .groupedCard()
                .padding(16)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.appGreen)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Date & time sheet

struct IncomeDateTimeSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Binding var date: Date

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                DatePicker("", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(.appGreen)
                    .labelsHidden()

                RowDivider()

                DatePicker("Time", selection: $date, displayedComponents: .hourAndMinute)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .tint(.appGreen)

                HStack(spacing: 10) {
                    quickDateButton("Today") { setDay(offset: 0) }
                    quickDateButton("Yesterday") { setDay(offset: -1) }
                    Spacer()
                }

                Spacer(minLength: 0)
            }
            .padding(16)
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Date & Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.appGreen)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    /// Moves the day while keeping the time the user picked.
    private func setDay(offset: Int) {
        Haptics.light()
        let calendar = Calendar.current
        guard let targetDay = calendar.date(byAdding: .day, value: offset, to: Date()) else { return }
        let time = calendar.dateComponents([.hour, .minute], from: date)
        date = calendar.date(
            bySettingHour: time.hour ?? 0,
            minute: time.minute ?? 0,
            second: 0,
            of: targetDay
        ) ?? targetDay
    }

    @ViewBuilder
    private func quickDateButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .foregroundColor(.appGreen)
            .background(Color.appGreen.opacity(0.12))
            .clipShape(Capsule())
            .buttonStyle(.plain)
    }
}

// MARK: - Tag sheet

struct IncomeTagSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Binding var tags: [String]

    @State private var draft: String = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 10) {
                    TextField("Create a tag", text: $draft)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .onSubmit { add(draft) }

                    Button {
                        add(draft)
                    } label: {
                        Image(systemName: AppIcon.Action.add)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.appGreen)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(trimmed(draft).isEmpty)
                    .opacity(trimmed(draft).isEmpty ? 0.4 : 1)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .liftedControl(cornerRadius: 14)

                if !tags.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Added")
                            .sectionEyebrow()

                        chipFlow(tags) { tag in
                            chip(tag, isSelected: true) { remove(tag) }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("SUGGESTED")
                        .sectionEyebrow()

                    chipFlow(IncomeCatalog.suggestedTags.filter { !tags.contains($0) }) { tag in
                        chip(tag, isSelected: false) { add(tag) }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Add Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.appGreen)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func chipFlow<Item: Hashable, Content: View>(
        _ items: [Item],
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        // `LazyVGrid` with adaptive columns wraps chips of differing widths without the
        // manual width-measuring a hand-rolled flow layout would need.
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8, alignment: .leading)], alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                content(item)
            }
        }
    }

    @ViewBuilder
    private func chip(_ tag: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(tag)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .lineLimit(1)

                Image(systemName: isSelected ? AppIcon.Nav.close : AppIcon.Action.add)
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(isSelected ? .white : .appGreen)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.appGreen : Color.appGreen.opacity(0.12))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func add(_ tag: String) {
        let value = trimmed(tag)
        guard !value.isEmpty, !tags.contains(value) else { return }
        Haptics.light()
        tags.append(value)
        draft = ""
    }

    private func remove(_ tag: String) {
        Haptics.light()
        tags.removeAll { $0 == tag }
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#Preview {
    AddIncomeView()
        .modelContainer(DataManager.shared.localContainer)
}

import SwiftUI
import SwiftData
import PhotosUI

/// Full-screen editor for a manually-entered expense (`expense.source == "manual"`).
///
/// Mirrors `AddExpenseView`'s fields and pickers — same categories, accounts, payment
/// methods, date/time sheet — but pre-filled from an existing `Expense` and saving in place
/// rather than inserting a new record. Bill-sourced expenses use `EditTransactionView`
/// instead, which shows split/receipt data this screen has no reason to.
struct EditExpenseView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Expense.date, order: .reverse) private var allExpenses: [Expense]

    let expense: Expense

    private typealias Option = AddIncomeView.Option

    // MARK: - Form state

    @State private var amountText: String
    @State private var currency: AddIncomeView.CurrencyOption
    @State private var category: Option
    @State private var date: Date
    @State private var paymentMethod: Option?
    @State private var account: Option
    @State private var notes: String
    @State private var receiptFileName: String
    @State private var receiptImage: UIImage?

    // MARK: - Presentation state

    @State private var activePicker: PickerField?
    @State private var showDateTimeSheet = false
    @State private var showDeleteAlert = false
    @State private var showReceiptViewer = false
    @State private var photoSelection: PhotosPickerItem?
    @State private var saveError: AppError?
    @FocusState private var notesFocused: Bool

    private enum PickerField: String, Identifiable {
        case currency, category, paymentMethod, account
        var id: String { rawValue }
    }

    private static let notesLimit = 200

    init(expense: Expense) {
        self.expense = expense

        let priceText = expense.price > 0 ? String(format: "%.2f", expense.price) : ""
        _amountText = State(initialValue: AmountInput.formatted(priceText))
        _currency = State(initialValue: AddIncomeView.CurrencyOption.all.first { $0.code == expense.currencyCode } ?? .inr)

        let categoryOptions = ExpenseCatalog.categories + ExpenseCatalog.userCategories()
        let matchedCategory = categoryOptions.first { $0.id == expense.type }
            ?? Option(id: expense.type, title: expense.type, icon: "square.grid.2x2.fill", emoji: expense.emoji)
        _category = State(initialValue: matchedCategory)

        _date = State(initialValue: expense.date)

        let trimmedPayment = expense.paymentMethod.trimmingCharacters(in: .whitespacesAndNewlines)
        _paymentMethod = State(initialValue: ExpenseCatalog.paymentMethods.first { $0.id == trimmedPayment })

        let trimmedAccount = expense.account.trimmingCharacters(in: .whitespacesAndNewlines)
        _account = State(initialValue: ExpenseCatalog.accounts().first { $0.id == trimmedAccount } ?? ExpenseCatalog.accounts()[0])

        _notes = State(initialValue: expense.note)
        _receiptFileName = State(initialValue: expense.receiptFileName)
        _receiptImage = State(initialValue: ReceiptStorage.load(expense.receiptFileName))
    }

    private var amountValue: Double { AmountInput.value(of: amountText) }
    private var canSave: Bool { amountValue > 0 }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        heroRow
                        amountCard
                        categoryField
                        dateTimeField
                        paymentMethodField
                        accountField
                        notesCard
                        receiptCard
                        SpendingInsightsCard(expenses: allExpenses, subject: expense)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 16)
                }
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
        .sheet(isPresented: $showReceiptViewer) {
            ReceiptViewerSheet(image: receiptImage)
        }
        .photosPicker(isPresented: $photoPickerPresented, selection: $photoSelection, matching: .images)
        .onChange(of: photoSelection) { _, item in
            guard let item else { return }
            Task { await attachReceipt(from: item) }
        }
        .alert("Delete Expense?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) { deleteExpense() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this entry? This action cannot be undone.")
        }
        .alert(saveError?.title ?? "", isPresented: errorAlertBinding, presenting: saveError) { _ in
            Button("OK", role: .cancel) { saveError = nil }
        } message: { error in
            Text(error.errorDescription ?? "")
        }
    }

    @State private var photoPickerPresented = false

    // MARK: - Header

    private var headerBar: some View {
        ScreenHeader(
            title: "Edit Expense",
            subtitle: "Update this transaction's details",
            onBack: { dismiss() }
        ) {
            ScreenHeaderAction(icon: AppIcon.Action.delete, title: "Delete", tint: .appExpenseRed) {
                showDeleteAlert = true
            }
        }
    }

    // MARK: - Hero row (live preview)

    private var heroRow: some View {
        HStack(spacing: 14) {
            TintedIconCircle(color: .appExpenseRed, size: 52, cornerRadius: 16) {
                Image(systemName: category.icon)
                    .font(.system(size: 21, weight: .bold))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(category.title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text("\(category.title) • \(account.title)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                Text(date.formatted(.dateTime.day().month(.wide).year().hour().minute()))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(AppFormatter.signedCurrency(amountValue, isIncome: false))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.appExpenseRed)

                HStack(spacing: 4) {
                    Image(systemName: AppIcon.Finance.expense)
                        .font(.system(size: 10, weight: .bold))
                    Text("Expense")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
                .foregroundColor(.appExpenseRed)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.appExpenseRed.opacity(0.12))
                .clipShape(Capsule())
            }
        }
        .padding(16)
        .groupedCard(cornerRadius: 18)
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
        labelled("Payment Method (Optional)") {
            dropdownRow(icon: paymentMethod?.icon ?? AppIcon.Finance.creditCard, iconStyle: .tinted, value: paymentMethod?.title, placeholder: "Select payment method") {
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

    private var notesCard: some View {
        labelled("Notes (Optional)") {
            VStack(alignment: .trailing, spacing: 2) {
                HStack(alignment: .top, spacing: 12) {
                    iconTile("doc.text", style: .tinted)

                    ZStack(alignment: .topLeading) {
                        if notes.isEmpty {
                            Text("Add a note")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary.opacity(0.7))
                                .padding(.top, 8)
                                .allowsHitTesting(false)
                        }

                        TextEditor(text: $notes)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .scrollContentBackground(.hidden)
                            .frame(height: 64)
                            .focused($notesFocused)
                    }
                }

                Text("\(notes.count)/\(Self.notesLimit)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .liftedControl(cornerRadius: 14)
            .onChange(of: notes) { _, newValue in
                if newValue.count > Self.notesLimit {
                    notes = String(newValue.prefix(Self.notesLimit))
                }
            }
        }
    }

    // MARK: - Receipt

    private var receiptCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "receipt.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                Text("Receipt (Optional)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(16)

            RowDivider().padding(.horizontal, 16)

            if receiptFileName.isEmpty {
                emptyReceiptRow
            } else {
                attachedReceiptRow
            }
        }
        .groupedCard(cornerRadius: 18)
    }

    private var emptyReceiptRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("No receipt added")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text("Add a receipt image for reference")
                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button {
                Haptics.light()
                photoPickerPresented = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("Add Receipt")
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                }
                .foregroundColor(.appGreen)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Color.appGreen.opacity(0.12))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var attachedReceiptRow: some View {
        HStack(spacing: 12) {
            Group {
                if let receiptImage {
                    Image(uiImage: receiptImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color(.tertiarySystemGroupedBackground)
                        .overlay(Image(systemName: "doc.fill").foregroundColor(.secondary))
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(receiptDisplayName)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                if let sizeBytes = ReceiptStorage.fileSize(receiptFileName) {
                    Text("Size: \(AppFormatter.fileSize(sizeBytes))")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button {
                Haptics.light()
                showReceiptViewer = true
            } label: {
                VStack(spacing: 3) {
                    TintedIconCircle(color: .appGreen, size: 34, cornerRadius: 11) {
                        Image(systemName: AppIcon.Action.view)
                            .font(.system(size: 14, weight: .bold))
                    }
                    Text("View")
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundColor(.appGreen)
                }
            }
            .buttonStyle(.plain)

            Button {
                Haptics.light()
                photoPickerPresented = true
            } label: {
                VStack(spacing: 3) {
                    TintedIconCircle(color: .secondary, size: 34, cornerRadius: 11) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 13, weight: .bold))
                    }
                    Text("Replace")
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var receiptDisplayName: String {
        "\(category.title.replacingOccurrences(of: " ", with: ""))_Receipt.jpg"
    }

    // MARK: - Action bar

    private var bottomActionBar: some View {
        VStack(spacing: 10) {
            Button {
                save()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: AppIcon.Status.success)
                        .font(.system(size: 15, weight: .bold))
                    Text("Save Changes")
                        .font(.system(size: 15.5, weight: .bold, design: .rounded))
                }
                .primaryButton(tint: .appGreenDeep, enabled: canSave, cornerRadius: 30)
            }
            .buttonStyle(.plain)
            .disabled(!canSave)

            Button {
                Haptics.light()
                dismiss()
            } label: {
                Text("Cancel")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(Color.appBackground.ignoresSafeArea(edges: .bottom))
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
                .fill(Color.appExpenseRed)
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
                selectedID: paymentMethod?.id
            ) { paymentMethod = $0 }
        case .account:
            IncomeOptionPickerSheet(
                title: "Account",
                options: ExpenseCatalog.accounts(),
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

    // MARK: - Receipt attach

    private func attachReceipt(from item: PhotosPickerItem) async {
        defer { photoSelection = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        if !receiptFileName.isEmpty { ReceiptStorage.delete(receiptFileName) }
        guard let filename = ReceiptStorage.save(image) else { return }
        receiptFileName = filename
        receiptImage = image
    }

    // MARK: - Save & Delete

    private func save() {
        guard canSave else { return }
        Haptics.medium()

        expense.price = amountValue
        expense.type = category.id
        expense.emoji = category.emoji
        if expense.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            expense.name = category.title
        }
        expense.date = date
        expense.note = notes
        expense.currencyCode = currency.code
        expense.paymentMethod = paymentMethod?.title ?? ""
        expense.account = account.title
        expense.receiptFileName = receiptFileName

        do {
            try context.save()
        } catch {
            saveError = AppError.wrap(error)
            return
        }

        CloudSyncManager.shared.queueExpenseUpsert(expense)
        dismiss()
    }

    private func deleteExpense() {
        Haptics.medium()
        let receiptToDelete = expense.receiptFileName
        context.delete(expense)
        CloudSyncManager.shared.queueDeleteExpense(id: expense.id)
        try? context.save()
        if !receiptToDelete.isEmpty { ReceiptStorage.delete(receiptToDelete) }
        dismiss()
    }
}

// MARK: - Receipt viewer

/// Full-screen look at an attached receipt image.
struct ReceiptViewerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let image: UIImage?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(16)
                } else {
                    Text("Receipt image unavailable")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}

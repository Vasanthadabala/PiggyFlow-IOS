import SwiftUI
import SwiftData
import PhotosUI

/// Full-screen editor for an expense that came from a scanned/uploaded bill
/// (`expense.source == "receipt"`).
///
/// Shows the receipt it was read from and which account it's allocated to, alongside the
/// same amount/category/notes fields `EditExpenseView` edits for manual entries. There's no
/// real multi-account split model behind "Split Details" yet (see `ExpenseCatalog`'s own
/// note on accounts being a static catalog, not a persisted store) — "Edit Split" opens the
/// same account picker as the split row itself, which is an honest stand-in for "change which
/// account this came out of" rather than a fabricated multi-way split UI with no data behind it.
struct EditTransactionView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Expense.date, order: .reverse) private var allExpenses: [Expense]

    let expense: Expense

    private typealias Option = AddIncomeView.Option

    // MARK: - Form state

    @State private var amountText: String
    @State private var currency: AddIncomeView.CurrencyOption
    @State private var category: Option
    @State private var account: Option
    @State private var notes: String
    @State private var receiptFileName: String
    @State private var receiptImage: UIImage?

    // MARK: - Presentation state

    @State private var activePicker: PickerField?
    @State private var showDeleteAlert = false
    @State private var showReceiptViewer = false
    @State private var photoSelection: PhotosPickerItem?
    @State private var photoPickerPresented = false
    @State private var saveError: AppError?
    @FocusState private var notesFocused: Bool

    private enum PickerField: String, Identifiable {
        case category, account
        var id: String { rawValue }
    }

    init(expense: Expense) {
        self.expense = expense

        let priceText = expense.price > 0 ? String(format: "%.2f", expense.price) : ""
        _amountText = State(initialValue: AmountInput.formatted(priceText))
        _currency = State(initialValue: AddIncomeView.CurrencyOption.all.first { $0.code == expense.currencyCode } ?? .inr)

        let categoryOptions = ExpenseCatalog.categories + ExpenseCatalog.userCategories()
        let matchedCategory = categoryOptions.first { $0.id == expense.type }
            ?? Option(id: expense.type, title: expense.type, icon: "square.grid.2x2.fill", emoji: expense.emoji)
        _category = State(initialValue: matchedCategory)

        let trimmedAccount = expense.account.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPayment = expense.paymentMethod.trimmingCharacters(in: .whitespacesAndNewlines)
        _account = State(initialValue: ExpenseCatalog.accounts().first { $0.id == trimmedAccount }
            ?? ExpenseCatalog.paymentMethods.first { $0.id == trimmedPayment }
            ?? ExpenseCatalog.accounts()[0])

        _notes = State(initialValue: expense.note)
        _receiptFileName = State(initialValue: expense.receiptFileName)
        _receiptImage = State(initialValue: ReceiptStorage.load(expense.receiptFileName))
    }

    private var amountValue: Double { AmountInput.value(of: amountText) }
    private var canSave: Bool { amountValue > 0 }
    private var merchantTitle: String { expense.name.isEmpty ? category.title : expense.name }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        heroRow
                        amountCard
                        splitDetailsCard
                        categoryCard
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
        .sheet(isPresented: $showReceiptViewer) {
            ReceiptViewerSheet(image: receiptImage)
        }
        .photosPicker(isPresented: $photoPickerPresented, selection: $photoSelection, matching: .images)
        .onChange(of: photoSelection) { _, item in
            guard let item else { return }
            Task { await attachReceipt(from: item) }
        }
        .alert("Delete Transaction?", isPresented: $showDeleteAlert) {
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

    // MARK: - Header

    private var headerBar: some View {
        ScreenHeader(
            title: "Edit Transaction",
            subtitle: "Update this scanned transaction",
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
            ZStack {
                Circle()
                    .fill(Color.appExpenseRed.opacity(0.12))
                    .frame(width: 56, height: 56)
                Text(expense.emoji.isEmpty ? String(merchantTitle.prefix(2)).uppercased() : expense.emoji)
                    .font(.system(size: expense.emoji.isEmpty ? 22 : 24))
                    .foregroundColor(.appExpenseRed)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(merchantTitle)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text("\(category.title) • \(account.title)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                Text(expense.date.formattedFull)
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

                Text(currency.label)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(Capsule())
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

    // MARK: - Split Details (single allocation — see type doc)

    private var splitDetailsCard: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Text("Account (Split Details)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                Spacer()
                Button {
                    Haptics.light()
                    activePicker = .account
                } label: {
                    Text("Edit Split")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.appGreen)
                }
                .buttonStyle(.plain)
            }
            .padding(16)

            RowDivider().padding(.horizontal, 16)

            Button {
                Haptics.light()
                activePicker = .account
            } label: {
                HStack(spacing: 14) {
                    TintedIconCircle(color: .appIndigo, size: 36, cornerRadius: 12) {
                        Image(systemName: account.icon)
                            .font(.system(size: 15, weight: .bold))
                    }
                    Text(account.title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(AppFormatter.signedCurrency(amountValue, isIncome: false))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Text("100%")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .groupedCard(cornerRadius: 18)
    }

    // MARK: - Category

    private var categoryCard: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Text("Category")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                Spacer()
            }
            .padding(16)

            RowDivider().padding(.horizontal, 16)

            Button {
                Haptics.light()
                activePicker = .category
            } label: {
                HStack(spacing: 14) {
                    TintedIconCircle(color: .appGreen, size: 44, cornerRadius: 14) {
                        Image(systemName: category.icon)
                            .font(.system(size: 18, weight: .bold))
                    }
                    Text(category.title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Spacer()
                    HStack(spacing: 3) {
                        Text("Edit Category")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(.appGreen)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .groupedCard(cornerRadius: 18)
    }

    // MARK: - Notes

    private var notesCard: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Text("Notes")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                Spacer()
                Button {
                    Haptics.light()
                    notesFocused = true
                } label: {
                    Text("Edit Note")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.appGreen)
                }
                .buttonStyle(.plain)
            }
            .padding(16)

            RowDivider().padding(.horizontal, 16)

            ZStack(alignment: .topLeading) {
                if notes.isEmpty {
                    Text("Add a note")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.7))
                        .padding(.top, 2)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $notes)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .scrollContentBackground(.hidden)
                    .frame(height: 54)
                    .focused($notesFocused)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .groupedCard(cornerRadius: 18)
    }

    // MARK: - Receipt

    private var receiptCard: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "receipt.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Text("Receipt")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
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
                Text("No receipt attached")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text("Attach the bill this was scanned from")
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
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text("\(merchantTitle.replacingOccurrences(of: " ", with: ""))_Bill.jpg")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text("Uploaded on \(expense.date.formattedFull)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
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
                VStack(spacing: 4) {
                    TintedIconCircle(color: .appGreen, size: 40, cornerRadius: 13) {
                        Image(systemName: AppIcon.Action.view)
                            .font(.system(size: 16, weight: .bold))
                    }
                    Text("View")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.appGreen)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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

    // MARK: - Pickers

    @ViewBuilder
    private func picker(for field: PickerField) -> some View {
        switch field {
        case .category:
            IncomeOptionPickerSheet(
                title: "Category",
                options: ExpenseCatalog.categories + ExpenseCatalog.userCategories(),
                selectedID: category.id
            ) { category = $0 }
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
        expense.currencyCode = currency.code
        expense.account = account.title
        expense.note = notes
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

import SwiftUI
import SwiftData
import UIKit

struct TransactionDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Expense.date, order: .reverse) private var allExpenses: [Expense]
    @State private var showEditSheet = false
    @State private var showDeleteAlert = false
    @State private var showReceiptViewer = false

    let item: HomeView.TransactionItem

    private func formattedDate(_ date: Date) -> String { date.formattedFull }

    private var isIncome: Bool { item.color == .appGreen }
    private var themeColor: Color { isIncome ? .appGreen : .appExpenseRed }
    private var merchantTitle: String { item.title.isEmpty ? item.type : item.title }

    private var currentExpense: Expense? {
        if case .expense(let expense) = item { return expense }
        return nil
    }

    private var receiptFileName: String { currentExpense?.receiptFileName ?? "" }
    private var receiptImage: UIImage? { ReceiptStorage.load(receiptFileName) }

    /// Other expenses at the same merchant (falling back to same category when there's no
    /// merchant on record) — the real counterpart to the old hardcoded 3-row sample list.
    private var relatedExpenses: [Expense] {
        guard let currentExpense else { return [] }
        let merchant = currentExpense.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        return allExpenses
            .filter { candidate in
                guard candidate.id != currentExpense.id else { return false }
                if !merchant.isEmpty {
                    return candidate.merchant.caseInsensitiveCompare(merchant) == .orderedSame
                }
                return candidate.type == currentExpense.type
            }
            .sorted { $0.date > $1.date }
            .prefix(3)
            .map { $0 }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Navigation bar
            customNavBar

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    // Hero row
                    heroRow

                    // Split Details
                    splitDetailsCard

                    // Category
                    categoryCard

                    // Notes
                    notesCard

                    // Receipt
                    receiptCard

                    // Spending Insights
                    spendingInsightsSection

                    // Related Transactions
                    relatedTransactionsCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 12)
            }
            // Reserves exactly the action bar's real height as scroll clearance, so card
            // content can never render behind the floating bar regardless of list length.
            .safeAreaInset(edge: .bottom) { bottomActionBar }
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .background(Color.appBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showEditSheet) {
            editDestination
        }
        .sheet(isPresented: $showReceiptViewer) {
            ReceiptViewerSheet(image: receiptImage)
        }
        .alert("Delete Transaction?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) { deleteTransaction() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this entry? This action cannot be undone.")
        }
    }

    // MARK: - Edit Routing

    /// Bill-scanned expenses open `EditTransactionView` (receipt, split, real merchant
    /// insights); everything else — manual expenses and all income — keeps its existing
    /// editor. Income has no receipt/bill concept, so it isn't part of this split.
    @ViewBuilder
    private var editDestination: some View {
        switch item {
        case .expense(let expense) where expense.source == "receipt":
            EditTransactionView(expense: expense)
        case .expense(let expense):
            EditExpenseView(expense: expense)
        case .income:
            AddExpenseBottomSheetView(itemToEdit: item)
        }
    }

    // MARK: - Custom Nav Bar

    private var customNavBar: some View {
        HStack {
            BackButton { dismiss() }

            Spacer()

            Text("Transaction Details")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            Spacer()

            Menu {
                Button { showEditSheet = true } label: {
                    Label("Edit", systemImage: "pencil")
                }
                Button(role: .destructive) { showDeleteAlert = true } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color(.secondarySystemGroupedBackground))
                        .frame(width: 40, height: 40)
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(Color.appBackground)
    }

    // MARK: - Hero Row

    private var heroRow: some View {
        HStack(spacing: 14) {
            // Merchant logo circle
            ZStack {
                Circle()
                    .fill(themeColor.opacity(0.12))
                    .frame(width: 56, height: 56)
                Text(item.emoji.isEmpty ? String(merchantTitle.prefix(2)).uppercased() : item.emoji)
                    .font(.system(size: item.emoji.isEmpty ? 22 : 24))
                    .foregroundColor(themeColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(merchantTitle)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text(item.account.isEmpty ? (item.type.isEmpty ? "General" : item.type) : "\(item.type.isEmpty ? "General" : item.type) • \(item.account)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                Text("\(formattedDate(item.date))")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text((isIncome ? "+₹" : "-₹") + String(format: "%.2f", item.amount))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(themeColor)

                HStack(spacing: 4) {
                    Image(systemName: isIncome ? "arrow.down.left" : "arrow.up.right")
                        .font(.system(size: 10, weight: .bold))
                    Text(isIncome ? "Income" : "Expense")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
                .foregroundColor(themeColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(themeColor.opacity(0.12))
                .clipShape(Capsule())
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    // MARK: - Split Details Card

    private var splitDetailsCard: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Text("Split Details")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                Spacer()
                Button {
                    Haptics.light()
                    showEditSheet = true
                } label: {
                    Text("Edit Split")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.appGreen)
                }
                .buttonStyle(.plain)
            }
            .padding(16)

            Divider().padding(.horizontal, 16)

            HStack(spacing: 14) {
                // Account initial circle
                ZStack {
                    Circle()
                        .fill(Color.appIndigo.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Text(item.account.isEmpty ? "?" : String(item.account.prefix(1)).uppercased())
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.appIndigo)
                }
                Text(item.account.isEmpty ? "No Account Selected" : item.account)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text((isIncome ? "+₹" : "-₹") + String(format: "%.2f", item.amount))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("100%")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    // MARK: - Category Card

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

            Divider().padding(.horizontal, 16)

            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.appGreen.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "cart.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.appGreen)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.type.isEmpty ? "Uncategorised" : item.type)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                Spacer()
                HStack(spacing: 3) {
                    Text("Edit Category")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.appGreen)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.appGreen)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    // MARK: - Notes Card

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
                    showEditSheet = true
                } label: {
                    Text("Edit Note")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.appGreen)
                }
                .buttonStyle(.plain)
            }
            .padding(16)

            Divider().padding(.horizontal, 16)

            HStack {
                Text(item.note.isEmpty ? "No notes added" : item.note)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(item.note.isEmpty ? .secondary.opacity(0.7) : .secondary)
                    .lineSpacing(2)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    // MARK: - Receipt Card

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

            Divider().padding(.horizontal, 16)

            if receiptFileName.isEmpty {
                HStack {
                    Text("No receipt attached")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.7))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            } else {
                HStack(spacing: 12) {
                    Group {
                        if let receiptImage {
                            Image(uiImage: receiptImage)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Color(.tertiarySystemGroupedBackground)
                                .overlay(
                                    Image(systemName: "doc.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(.secondary)
                                )
                        }
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(merchantTitle.replacingOccurrences(of: " ", with: ""))_Bill.jpg")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Text("Uploaded on \(formattedDate(item.date))")
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
                            ZStack {
                                Circle()
                                    .fill(Color.appGreen.opacity(0.12))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "eye.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.appGreen)
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
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    // MARK: - Spending Insights

    @ViewBuilder
    private var spendingInsightsSection: some View {
        if let currentExpense {
            SpendingInsightsCard(expenses: allExpenses, subject: currentExpense)
        }
    }

    // MARK: - Related Transactions Card

    @ViewBuilder
    private var relatedTransactionsCard: some View {
        if !relatedExpenses.isEmpty {
            VStack(spacing: 0) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "list.bullet.rectangle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        Text("Related Transactions")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    Spacer()
                }
                .padding(16)

                ForEach(Array(relatedExpenses.enumerated()), id: \.element.id) { _, related in
                    Divider().padding(.horizontal, 16)
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.appExpenseRed.opacity(0.10))
                                .frame(width: 40, height: 40)
                            Text(related.emoji.isEmpty ? String((related.name.isEmpty ? related.type : related.name).prefix(2)).uppercased() : related.emoji)
                                .font(.system(size: 16))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(related.name.isEmpty ? related.type : related.name)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            Text(related.account.isEmpty ? related.type : "\(related.type) • \(related.account)")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(AppFormatter.signedCurrency(related.price, isIncome: false))
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.appExpenseRed)
                            Text(related.date.formatted(.dateTime.month(.abbreviated).day().year()))
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
        }
    }

    // MARK: - Bottom Action Bar

    private var bottomActionBar: some View {
        HStack(spacing: 0) {
            // Split Expense
            Button {
                Haptics.light()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 16, weight: .bold))
                    Text("Split Expense")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)

            Divider().frame(height: 40)

            // Mark as Frequent
            Button {
                Haptics.light()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "repeat.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text("Mark as Frequent")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)

            Divider().frame(height: 40)

            // Delete
            Button {
                Haptics.medium()
                showDeleteAlert = true
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text("Delete")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
                .foregroundColor(.appExpenseRed)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.top, 14)
        .padding(.bottom, 14)
        .background(
            Color(.secondarySystemGroupedBackground)
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: -4)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Delete

    private func deleteTransaction() {
        switch item {
        case .expense(let expense):
            context.delete(expense)
            CloudSyncManager.shared.queueDeleteExpense(id: expense.id)
        case .income(let income):
            context.delete(income)
            CloudSyncManager.shared.queueDeleteIncome(id: income.id)
        }
        try? context.save()
        dismiss()
    }
}

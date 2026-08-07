import SwiftUI
import SwiftData

struct TransactionDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var showEditSheet = false
    @State private var showDeleteAlert = false

    let item: HomeView.TransactionItem

    private func formattedDate(_ date: Date) -> String { date.formattedFull }

    private var isIncome: Bool { item.color == .appGreen }
    private var themeColor: Color { isIncome ? .appGreen : .appExpenseRed }
    private var merchantTitle: String { item.title.isEmpty ? item.type : item.title }

    // Simulated related transactions
    private var relatedItems: [(name: String, sub: String, amount: String, date: String)] {
        [
            (name: merchantTitle, sub: "Shopping • HDFC Bank", amount: "-₹875.50", date: "May 23, 2025"),
            (name: merchantTitle, sub: "Shopping • HDFC Bank", amount: "-₹1,050.00", date: "May 12, 2025"),
            (name: merchantTitle, sub: "Shopping • HDFC Bank", amount: "-₹945.75", date: "Apr 28, 2025")
        ]
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
                    spendingInsightsCard

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
        .sheet(isPresented: $showEditSheet) {
            AddExpenseBottomSheetView(itemToEdit: item)
        }
        .alert("Delete Transaction?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) { deleteTransaction() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this entry? This action cannot be undone.")
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
                Text("\(item.type.isEmpty ? "General" : item.type) • HDFC Bank")
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
                Button { } label: {
                    Text("Edit Split")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.appGreen)
                }
                .buttonStyle(.plain)
            }
            .padding(16)

            Divider().padding(.horizontal, 16)

            HStack(spacing: 14) {
                // Bank initial circle
                ZStack {
                    Circle()
                        .fill(Color.appIndigo.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Text("H")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.appIndigo)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("HDFC Bank")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("**** 4321")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("-₹\(String(format: "%.2f", item.amount))")
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
                    Text(item.type.isEmpty ? "Shopping" : item.type)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("Groceries")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
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
                Button { } label: {
                    Text("Edit Note")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.appGreen)
                }
                .buttonStyle(.plain)
            }
            .padding(16)

            Divider().padding(.horizontal, 16)

            HStack {
                Text(item.note.isEmpty ? "Monthly groceries and household items" : item.note)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
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

            HStack(spacing: 12) {
                // Thumbnail placeholder
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(.tertiarySystemGroupedBackground))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "doc.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.secondary)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text("\(merchantTitle)_Bill_\(shortDate(item.date)).jpg")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("Uploaded on \(formattedDate(item.date))")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                    Text("Size: 245 KB")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button { } label: {
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
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    // MARK: - Spending Insights Card

    private var spendingInsightsCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.appWarningAmber)
                Text("Spending Insights")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(16)

            Divider().padding(.horizontal, 16)

            HStack(spacing: 0) {
                insightStat(title: "Total spent at \(merchantTitle)", value: "₹2,845.00", sub: "This Month")
                Divider().frame(height: 50)
                insightStat(title: "Transactions", value: "3", sub: "This Month")
                Divider().frame(height: 50)
                insightStat(title: "Average per order", value: "₹948.33", sub: "This Month")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider().padding(.horizontal, 16)

            Button { } label: {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.appGreen)
                    Text("You've spent 12% more at \(merchantTitle) compared to last month.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    @ViewBuilder
    private func insightStat(title: String, value: String, sub: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            Text(sub)
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Related Transactions Card

    private var relatedTransactionsCard: some View {
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
                Button { } label: {
                    Text("View All")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.appGreen)
                }
                .buttonStyle(.plain)
            }
            .padding(16)

            ForEach(Array(relatedItems.enumerated()), id: \.offset) { idx, rel in
                Divider().padding(.horizontal, 16)
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.appGreen.opacity(0.10))
                            .frame(width: 40, height: 40)
                        Text(item.emoji.isEmpty ? String(merchantTitle.prefix(2)).uppercased() : item.emoji)
                            .font(.system(size: 16))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(rel.name)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Text(rel.sub)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(rel.amount)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.appExpenseRed)
                        Text(rel.date)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.5))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
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

    // MARK: - Helpers

    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMMdd"
        return f.string(from: date)
    }

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

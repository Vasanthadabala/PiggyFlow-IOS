import SwiftUI
import SwiftData

/// Review-and-edit step shown after a bill is scanned.
///
/// OCR is never accurate enough to trust blindly, so nothing reaches the ledger until the
/// user has confirmed it here.
struct ScannedItemsReviewSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State var items: [ParsedItem]
    /// The photo(s) that produced `items` — every expense saved from this batch shares the
    /// one bill they were all read from as its receipt.
    var images: [UIImage] = []
    /// Called with the number of expenses saved, so the caller can confirm.
    var onSaved: (Int) -> Void

    private var totalAmount: Double {
        items.compactMap { Double($0.price) }.reduce(0, +)
    }

    private var validItemCount: Int {
        items.filter { Double($0.price).map { $0 > 0 } ?? false && !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                if items.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 0) {
                        summaryHeader

                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 10) {
                                ForEach($items) { $item in
                                    itemRow($item)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 14)
                            .padding(.bottom, 16)
                        }

                        saveBar
                    }
                }
            }
            .navigationTitle("Review Items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !items.isEmpty {
                        Button("Clear") {
                            withAnimation { items.removeAll() }
                        }
                        .foregroundColor(.appExpenseRed)
                    }
                }
            }
        }
    }

    // MARK: - Pieces

    private var summaryHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(items.count) item\(items.count == 1 ? "" : "s") found")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                Text(AppFormatter.currency(totalAmount))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer()

            Text("Tap any row to edit")
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                .foregroundColor(.appGreen)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.appGreen.opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.appSurface)
    }

    private func itemRow(_ item: Binding<ParsedItem>) -> some View {
        HStack(spacing: 10) {
            TextField("Item name", text: item.name)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)

            Text(AppConstants.Currency.symbol)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.appGreen)

            TextField("0.00", text: item.price)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 84)

            Button {
                withAnimation {
                    items.removeAll { $0.id == item.wrappedValue.id }
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary.opacity(0.45))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
    }

    private var saveBar: some View {
        Button {
            Haptics.medium()
            save()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: AppIcon.Status.success)
                    .font(.system(size: 16, weight: .bold))
                Text(validItemCount == 0 ? "Nothing to save" : "Save \(validItemCount) Expense\(validItemCount == 1 ? "" : "s")")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(validItemCount == 0 ? Color.secondary.opacity(0.4) : Color.appGreen)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(validItemCount == 0)
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(Color.appSurface.ignoresSafeArea(edges: .bottom))
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 44, weight: .light))
                .foregroundColor(.secondary.opacity(0.5))
            Text("No items found")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            Text("The receipt couldn't be read clearly. Try again with better lighting, or enter the expense manually.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    // MARK: - Persistence

    private func save() {
        // One receipt image backs every expense pulled from it — saved once, referenced by
        // filename, rather than duplicated per item.
        let receiptFileName = images.first.flatMap(ReceiptStorage.save) ?? ""

        var saved = 0
        for item in items {
            let name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let amount = Double(item.price), amount > 0, !name.isEmpty else { continue }

            let expense = Expense(
                type: "Shopping",
                emoji: "🧾",
                name: name,
                price: amount,
                date: Date(),
                note: "Scanned from receipt",
                source: "receipt",
                receiptFileName: receiptFileName
            )
            context.insert(expense)
            CloudSyncManager.shared.queueExpenseUpsert(expense)
            saved += 1
        }

        do {
            try context.save()
        } catch {
            Log.error(error, context: "Saving scanned expenses", category: .database)
        }

        onSaved(saved)
        dismiss()
    }
}

import SwiftUI

struct ExpenseItemCard: View {
    let emoji: String
    let title: String
    let date: Date
    let amount: Double
    let color: Color
    let isIncome: Bool
    
    private var formattedDate: String { date.formattedMedium }
    
    private var badgeColor: Color {
        isIncome ? .appGreen : .appExpenseRed
    }

    var body: some View {
        HStack(spacing: 14) {
            TintedIconCircle(color: badgeColor, size: 44, cornerRadius: 14) {
                Text(emoji.isEmpty ? String(title.prefix(1)).uppercased() : emoji)
                    .font(.system(size: 19))
            }

            // Name & Date
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text(formattedDate)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(isIncome ? "+ ₹\(amount, specifier: "%.2f")" : "- ₹\(amount, specifier: "%.2f")")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(badgeColor)
        }
        .flatRow(vertical: 13, horizontal: 16)
        .contentShape(Rectangle())
    }
}

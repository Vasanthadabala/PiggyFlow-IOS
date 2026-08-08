import SwiftUI
import SwiftData

/// Bumps a goal's `currentAmount` toward its target. Deliberately minimal — a running total
/// the user can top up, not a contribution ledger; no history, no undo.
struct AddGoalFundsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let goal: TrackerRecord

    @State private var amountText: String = ""

    private var amountValue: Double { AmountInput.value(of: amountText) }
    private var canSave: Bool { amountValue > 0 }

    private var progressRatio: Double {
        goal.amount > 0 ? min(1, goal.currentAmount / goal.amount) : 0
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    Text(goal.name)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("\(AppFormatter.currency(goal.currentAmount)) of \(AppFormatter.currency(goal.amount)) saved")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.gray.opacity(0.15)).frame(height: 6)
                            Capsule().fill(Color.appGreen).frame(width: geo.size.width * progressRatio, height: 6)
                        }
                    }
                    .frame(height: 6)
                    .padding(.top, 4)
                }
                .padding(.top, 12)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Add Funds")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)

                    HStack(spacing: 10) {
                        Text(AppConstants.Currency.symbol)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        TextField("0", text: amountBinding)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .liftedControl(cornerRadius: 16)
                }

                Spacer()

                Button {
                    save()
                } label: {
                    Text("Add to Goal")
                        .font(.system(size: 15.5, weight: .bold, design: .rounded))
                        .primaryButton(tint: .appGreenDeep, enabled: canSave, cornerRadius: 16)
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
            }
            .padding(20)
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Add Funds")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var amountBinding: Binding<String> {
        Binding(
            get: { amountText },
            set: { amountText = AmountInput.formatted($0) }
        )
    }

    private func save() {
        guard canSave else { return }
        Haptics.medium()
        goal.currentAmount = min(goal.currentAmount + amountValue, goal.amount)
        try? context.save()
        dismiss()
    }
}

import SwiftUI

/// Goal tab — a target amount to reach by a date, with optional milestones along the way.
struct GoalTrackerForm: View {
    @Binding var form: TrackerFormState

    @State private var milestoneBeingEdited: GoalMilestone?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            TrackerField(title: "Goal Title") {
                TrackerTextField(
                    icon: AppIcon.Action.edit,
                    placeholder: "e.g. Buy New Laptop",
                    text: $form.title
                )
            }

            TrackerFieldPair {
                TrackerField(title: "Category") {
                    TrackerMenuField(
                        options: TrackerOptions.goalCategories,
                        selection: $form.goalCategory
                    )
                }
            } trailing: {
                TrackerField(title: "Priority") {
                    TrackerMenuField(
                        options: TrackerOptions.priorities,
                        selection: $form.priority
                    )
                }
            }

            TrackerFieldPair {
                TrackerField(title: "Target Amount") {
                    TrackerAmountField(amount: $form.amount, currency: $form.currency)
                }
            } trailing: {
                TrackerField(title: "Current Amount (Optional)") {
                    TrackerAmountField(amount: $form.currentAmount)
                }
            }

            TrackerFieldPair {
                TrackerField(title: "Target Date") {
                    TrackerDateField(date: $form.targetDate, emptyLabel: "Select target date")
                }
            } trailing: {
                TrackerField(title: "Remind me") {
                    TrackerReminderField(selection: $form.reminder)
                }
            }

            TrackerField(title: "Milestones (Optional)") {
                milestonesCard
            }

            TrackerField(title: "Description (Optional)") {
                TrackerNotesField(
                    placeholder: "Add a note about your goal...",
                    text: $form.notes
                )
            }

            TrackerField(title: "Icon & Color") {
                TrackerIconColorPicker(
                    icons: TrackerKind.goal.iconChoices,
                    selectedIcon: $form.icon,
                    selectedColor: $form.color
                )
            }
        }
        .sheet(item: $milestoneBeingEdited) { milestone in
            MilestoneEditorSheet(percent: milestone.percent, target: form.amountValue) { newPercent in
                guard let index = form.milestones.firstIndex(where: { $0.id == milestone.id }) else { return }
                form.milestones[index].percent = newPercent
                sortMilestones()
            }
        }
    }

    // MARK: - Milestones

    private var milestonesCard: some View {
        VStack(spacing: 0) {
            ForEach(form.milestones) { milestone in
                milestoneRow(milestone)
                RowDivider(leadingInset: 12)
            }

            Button {
                addMilestone()
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: AppIcon.Action.addCircle)
                        .font(.system(size: 14, weight: .semibold))
                    Text("Add Milestone")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                }
                .foregroundColor(.appGreen)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        // Same white surface as every other field — it kept the old grey fill after the rest
        // of the form moved off the enclosing card, which read as a disabled block.
        .liftedControl(cornerRadius: 14)
    }

    @ViewBuilder
    private func milestoneRow(_ milestone: GoalMilestone) -> some View {
        HStack(spacing: 12) {
            // Progress ring — the milestone's share of the goal, at a glance.
            ZStack {
                Circle()
                    .stroke(Color.appGreen.opacity(0.18), lineWidth: 3)
                    .frame(width: 30, height: 30)

                Circle()
                    .trim(from: 0, to: CGFloat(milestone.percent) / 100)
                    .stroke(Color.appGreen, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 30, height: 30)
                    .rotationEffect(.degrees(-90))

                Text("\(milestone.percent)%")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(.appGreen)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(milestone.percent)% of goal")
                    .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)

                Text(AppFormatter.currencyRounded(milestone.amount(of: form.amountValue)))
                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 6)

            Button {
                Haptics.light()
                milestoneBeingEdited = milestone
            } label: {
                Image(systemName: AppIcon.Action.edit)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)

            Button {
                Haptics.light()
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    form.milestones.removeAll { $0.id == milestone.id }
                }
            } label: {
                Image(systemName: AppIcon.Action.delete)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.appExpenseRed.opacity(0.85))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    /// Adds a milestone halfway between the last one and the finish line, so repeated taps
    /// subdivide the remaining distance instead of piling up duplicates at 100%.
    private func addMilestone() {
        Haptics.light()
        let highest = form.milestones.map(\.percent).max() ?? 0
        let next = highest >= 95 ? 100 : highest + (100 - highest) / 2
        guard !form.milestones.contains(where: { $0.percent == next }) else { return }

        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            form.milestones.append(GoalMilestone(percent: next))
            sortMilestones()
        }
    }

    private func sortMilestones() {
        form.milestones.sort { $0.percent < $1.percent }
    }
}

/// Percent editor for a single milestone.
private struct MilestoneEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State var percent: Int
    let target: Double
    var onSave: (Int) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 6) {
                    Text("\(percent)%")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(.appGreen)

                    Text(AppFormatter.currencyRounded(target * Double(percent) / 100))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)

                Slider(
                    value: Binding(
                        get: { Double(percent) },
                        set: { percent = Int($0.rounded()) }
                    ),
                    in: 5...100,
                    step: 5
                )
                .tint(.appGreen)
                .padding(.horizontal, 24)

                Spacer()

                Button {
                    Haptics.medium()
                    onSave(percent)
                    dismiss()
                } label: {
                    Text("Save Milestone")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .primaryButton()
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Edit Milestone")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.height(320)])
    }
}

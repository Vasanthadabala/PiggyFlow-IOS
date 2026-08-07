import SwiftUI

/// Budget tab of the Add Tracker form — a spending cap on a category, over a period.
struct BudgetTrackerForm: View {
    @Binding var form: TrackerFormState

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            TrackerField(title: "Title") {
                TrackerTextField(
                    icon: AppIcon.Action.edit,
                    placeholder: "e.g. Monthly Groceries",
                    text: $form.title
                )
            }

            TrackerField(title: "Category") {
                TrackerMenuField(
                    options: TrackerOptions.expenseCategories,
                    selection: $form.category
                )
            }

            TrackerFieldPair {
                TrackerField(title: "Amount / Budget") {
                    TrackerAmountField(amount: $form.amount, currency: $form.currency)
                }
            } trailing: {
                TrackerField(title: "Period") {
                    TrackerMenuField(options: TrackerOptions.periods, selection: $form.period)
                }
            }

            TrackerField(title: "Start Date") {
                TrackerDateField(date: $form.startDate, emptyLabel: "Select start date")
            }

            TrackerField(title: "End Date (Optional)") {
                TrackerDateField(
                    date: $form.endDate,
                    emptyLabel: "No end date",
                    allowsClearing: true,
                    range: (form.startDate ?? Date())...
                )
            }

            TrackerField(title: "Description (Optional)") {
                TrackerNotesField(
                    placeholder: "Add details about this tracker...",
                    text: $form.notes
                )
            }

            TrackerField(title: "Set Alert / Reminder") {
                TrackerReminderField(selection: $form.reminder)
            }

            TrackerField(title: "Icon & Color") {
                TrackerIconColorPicker(
                    icons: TrackerKind.budget.iconChoices,
                    selectedIcon: $form.icon,
                    selectedColor: $form.color
                )
            }
        }
    }
}

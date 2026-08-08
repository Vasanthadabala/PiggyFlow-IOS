import SwiftUI

/// Subscription tab — a recurring charge with a billing cycle and a next-due date.
struct SubscriptionTrackerForm: View {
    @Binding var form: TrackerFormState

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            TrackerField(title: "Subscription Name") {
                TrackerTextField(
                    icon: "play.rectangle.fill",
                    iconTint: form.color,
                    placeholder: "e.g. Netflix Premium",
                    text: $form.title
                )
            }

            TrackerFieldPair {
                TrackerField(title: "Category") {
                    TrackerMenuField(
                        options: TrackerOptions.expenseCategories,
                        selection: $form.subscriptionCategory
                    )
                }
            } trailing: {
                TrackerField(title: "Billing Cycle") {
                    TrackerMenuField(
                        options: TrackerOptions.billingCycles,
                        selection: $form.billingCycle
                    )
                }
            }

            TrackerFieldPair {
                TrackerField(title: "Amount") {
                    TrackerAmountField(amount: $form.amount, currency: $form.currency)
                }
            } trailing: {
                TrackerField(title: "Next Billing Date") {
                    TrackerDateField(date: $form.nextBillingDate, emptyLabel: "Select date")
                }
            }

            // Full width rather than paired: payment methods here carry a masked card suffix
            // ("HDFC Bank •••• 2345") that a half-width field can't fit at any legible scale —
            // unlike Loan Type/Lender on the EMI form, whose values are short bank names alone.
            TrackerField(title: "Payment Method") {
                TrackerMenuField(
                    options: TrackerOptions.paymentMethods,
                    selection: $form.paymentMethod,
                    fallbackIcon: "creditcard.fill"
                )
            }

            TrackerField(title: "Account") {
                TrackerMenuField(
                    options: TrackerOptions.accounts(),
                    selection: $form.account,
                    fallbackIcon: "wallet.pass.fill"
                )
            }

            TrackerField(title: "Vendor / Provider (Optional)") {
                TrackerTextField(
                    icon: "building.2.fill",
                    placeholder: "e.g. Netflix, Spotify, Amazon Prime",
                    text: $form.vendor
                )
            }

            TrackerToggleField(
                title: "Auto-deducts from account",
                subtitle: "Enable if the amount is auto-deducted on due date",
                isOn: $form.autoDeducts
            )

            TrackerField(title: "Set Reminder") {
                TrackerReminderField(selection: $form.reminder)
            }

            TrackerField(title: "Notes (Optional)") {
                TrackerNotesField(
                    icon: "note.text",
                    placeholder: "Add a note about this subscription...",
                    text: $form.notes
                )
            }

            TrackerField(title: "Icon & Color") {
                TrackerIconColorPicker(
                    icons: TrackerKind.subscription.iconChoices,
                    selectedIcon: $form.icon,
                    selectedColor: $form.color
                )
            }

            summaryCard
        }
    }

    // MARK: - Summary

    /// Restates the entry as a sentence plus the annual cost — the number people actually
    /// react to, and the one a monthly price hides.
    private var summaryCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Color.appGreen.opacity(0.2), lineWidth: 6)
                    .frame(width: 54, height: 54)

                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(Color.appGreen, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 54, height: 54)
                    .rotationEffect(.degrees(-90))

                Image(systemName: "calendar")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.appGreen)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("You'll pay \(AppFormatter.currency(form.amountValue)) \(form.billingCadencePhrase)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                summaryRow(
                    icon: "clock",
                    label: "Next billing date",
                    value: form.nextBillingDate.map { $0.formatted(.dateTime.day().month(.wide).year()) } ?? "—"
                )

                summaryRow(
                    icon: "arrow.triangle.2.circlepath",
                    label: "Annual cost",
                    value: AppFormatter.currency(form.annualSubscriptionCost)
                )
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color(red: 240/255, green: 250/255, blue: 244/255))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private func summaryRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundColor(.secondary)

            Text(label)
                .font(.system(size: 11.5, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)

            Spacer(minLength: 8)

            Text(value)
                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                .foregroundColor(.appGreen)
        }
    }
}

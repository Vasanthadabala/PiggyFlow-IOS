import SwiftUI

/// EMI / Loan tab — principal, rate and tenure, with the instalment and total cost derived.
struct EMITrackerForm: View {
    @Binding var form: TrackerFormState

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            TrackerField(title: "Loan / EMI Name") {
                TrackerTextField(
                    icon: "house.fill",
                    iconTint: form.color,
                    placeholder: "e.g. Home Loan, Car Loan",
                    text: $form.title
                )
            }

            TrackerFieldPair {
                TrackerField(title: "Loan Type") {
                    TrackerMenuField(
                        options: TrackerOptions.loanTypes,
                        selection: $form.loanType
                    )
                }
            } trailing: {
                TrackerField(title: "Lender / Bank") {
                    TrackerMenuField(
                        options: TrackerOptions.lenders,
                        selection: $form.lender,
                        fallbackIcon: "building.columns.fill"
                    )
                }
            }

            TrackerFieldPair {
                TrackerField(title: "Loan Amount") {
                    TrackerAmountField(amount: $form.loanAmount)
                }
            } trailing: {
                TrackerField(title: "Interest Rate (p.a.)") {
                    TrackerPercentField(value: $form.interestRate)
                }
            }

            TrackerFieldPair {
                TrackerField(title: "EMI Amount") {
                    TrackerAmountField(amount: $form.emiAmount, placeholder: emiPlaceholder)
                }
            } trailing: {
                TrackerField(title: "Tenure") {
                    TrackerMenuField(options: TrackerOptions.tenures, selection: $form.tenure)
                }
            }

            TrackerFieldPair {
                TrackerField(title: "EMI Start Date") {
                    TrackerDateField(date: $form.emiStartDate, emptyLabel: "Select date")
                }
            } trailing: {
                TrackerField(title: "Next EMI Date") {
                    TrackerDateField(date: $form.nextEMIDate, emptyLabel: "Select date")
                }
            }

            TrackerField(title: "Payment Account") {
                TrackerMenuField(
                    options: TrackerOptions.paymentMethods,
                    selection: $form.paymentAccount,
                    fallbackIcon: "wallet.pass.fill"
                )
            }

            TrackerField(title: "Loan Account Number (Optional)") {
                TrackerTextField(
                    icon: "number",
                    placeholder: "e.g. your loan account number",
                    text: $form.referenceID
                )
            }

            TrackerField(title: "Set Reminder") {
                TrackerReminderField(selection: $form.reminder)
            }

            loanSummaryCard

            TrackerField(title: "Notes (Optional)") {
                TrackerNotesField(
                    icon: "note.text",
                    placeholder: "Add a note about this loan...",
                    text: $form.notes
                )
            }

            TrackerField(title: "Icon & Color") {
                TrackerIconColorPicker(
                    icons: TrackerKind.emi.iconChoices,
                    selectedIcon: $form.icon,
                    selectedColor: $form.color
                )
            }
        }
    }

    /// The computed instalment doubles as the placeholder, so leaving the field empty is a
    /// deliberate "use the standard EMI" rather than an omission.
    private var emiPlaceholder: String {
        form.computedEMI > 0 ? AppFormatter.currencyRounded(form.computedEMI) : "0.00"
    }

    // MARK: - Loan Summary

    private var loanSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                TintedIconCircle(color: .appGreen, size: 42, cornerRadius: 12) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 17, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Loan Summary")
                        .font(.system(size: 14.5, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    HStack(spacing: 0) {
                        summaryColumn(
                            label: "Total Payable",
                            value: AppFormatter.currencyRounded(form.totalPayable),
                            valueColor: .appGreen
                        )

                        Rectangle()
                            .fill(Color.primary.opacity(0.08))
                            .frame(width: 1, height: 32)

                        summaryColumn(
                            label: "Total Interest",
                            value: AppFormatter.currencyRounded(form.totalInterest)
                        )
                        .padding(.leading, 12)

                        Rectangle()
                            .fill(Color.primary.opacity(0.08))
                            .frame(width: 1, height: 32)

                        summaryColumn(
                            label: "Total EMIs",
                            value: "\(form.tenureMonths)"
                        )
                        .padding(.leading, 12)
                    }
                }
            }

            HStack {
                Text("0 of \(form.tenureMonths) EMIs paid")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)

                Spacer()

                Text("0%")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Capsule()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 6)
        }
        .padding(14)
        .background(Color(red: 240/255, green: 250/255, blue: 244/255))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private func summaryColumn(label: String, value: String, valueColor: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)

            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

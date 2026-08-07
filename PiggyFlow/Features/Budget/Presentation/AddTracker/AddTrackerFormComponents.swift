import SwiftUI

/// Building blocks for the Add Tracker form.
///
/// The four tracker types ask for different things but share a visual grammar: a small
/// grey label, then a filled control with a tinted leading icon. Defining that grammar
/// once keeps the Budget form from drifting away from the EMI form as fields are added.

// MARK: - Option

/// One choice in a dropdown — the icon travels with the label so menus stay recognisable.
struct TrackerOption: Identifiable, Hashable {
    var name: String
    var icon: String
    var tint: Color = .appGreen

    var id: String { name }
}

// MARK: - Scaffolding

/// Label + control pair. Every row on the form is one of these.
struct TrackerField<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            content
        }
    }
}

/// The container a control sits in.
///
/// A white surface lifted off the page, matching the dropdown rows on Add Expense and Add
/// Income. It used to be a grey fill, which only worked while the whole form was wrapped in
/// one white card — on the page background that reads as a disabled field.
struct FieldShell<Content: View>: View {
    var vertical: CGFloat = 12
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, vertical)
            .liftedControl(cornerRadius: 14)
    }
}

/// Tinted glyph tile that leads a field.
///
/// Built on `TintedIconCircle` so the fill opacity matches the icon tiles on every other
/// screen — it used to carry its own slightly heavier 0.14 tint.
struct FieldIcon: View {
    var systemName: String
    var tint: Color = .appGreen
    /// 30 rather than 34: half the fields sit two-to-a-row, where every point the tile gives
    /// back is a point the value gets before it has to truncate.
    var size: CGFloat = 30

    var body: some View {
        TintedIconCircle(color: tint, size: size, cornerRadius: 10) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.44, weight: .semibold))
        }
    }
}

/// Trailing `12/40` counter.
private struct CharacterCounter: View {
    var count: Int
    var limit: Int

    var body: some View {
        Text("\(count)/\(limit)")
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundColor(count >= limit ? Color.appWarningAmber : .secondary.opacity(0.7))
    }
}

// MARK: - Text

struct TrackerTextField: View {
    var icon: String
    var iconTint: Color = .appGreen
    var placeholder: String
    @Binding var text: String
    var limit: Int = 40

    var body: some View {
        FieldShell {
            HStack(spacing: 11) {
                FieldIcon(systemName: icon, tint: iconTint)

                TextField(placeholder, text: $text)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)

                CharacterCounter(count: text.count, limit: limit)
            }
        }
        .onChange(of: text) { _, newValue in
            if newValue.count > limit { text = String(newValue.prefix(limit)) }
        }
    }
}

/// Multi-line notes/description field.
struct TrackerNotesField: View {
    var icon: String = "doc.text"
    var placeholder: String
    @Binding var text: String
    var limit: Int = 100

    var body: some View {
        FieldShell(vertical: 12) {
            HStack(alignment: .top, spacing: 11) {
                FieldIcon(systemName: icon)

                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text(placeholder)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary.opacity(0.8))
                            .padding(.top, 7)
                    }

                    TextEditor(text: $text)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .scrollContentBackground(.hidden)
                        .frame(height: 58)
                }

                VStack {
                    Spacer()
                    CharacterCounter(count: text.count, limit: limit)
                }
            }
        }
        .onChange(of: text) { _, newValue in
            if newValue.count > limit { text = String(newValue.prefix(limit)) }
        }
    }
}

// MARK: - Amount

struct TrackerAmountField: View {
    @Binding var amount: String
    var placeholder: String = "0.00"
    /// Non-nil renders the currency dropdown beside the amount.
    var currency: Binding<String>? = nil

    private let currencies = ["INR (₹)", "USD ($)", "EUR (€)", "GBP (£)", "AED (د.إ)"]

    /// `"INR (₹)"` → `"INR"`. The menu keeps the full label; the collapsed row shows the code.
    private func currencyCode(_ value: String) -> String {
        String(value.prefix(while: { $0 != " " }))
    }

    var body: some View {
        FieldShell {
            HStack(spacing: 11) {
                FieldIcon(systemName: "indianrupeesign")

                TextField(placeholder, text: $amount)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .keyboardType(.decimalPad)
                    .foregroundColor(.primary)

                if let currency {
                    Menu {
                        ForEach(currencies, id: \.self) { code in
                            Button(code) {
                                currency.wrappedValue = code
                                Haptics.light()
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            // Just the code: the field is half-width when paired with Period,
                            // and "INR (₹)" wrapped onto a second line there.
                            Text(currencyCode(currency.wrappedValue))
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                        .fixedSize()
                    }
                }
            }
        }
    }
}

/// Percentage input — used for the loan interest rate.
struct TrackerPercentField: View {
    @Binding var value: String
    var placeholder: String = "0.0"

    var body: some View {
        FieldShell {
            HStack(spacing: 11) {
                FieldIcon(systemName: "percent")

                TextField(placeholder, text: $value)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .keyboardType(.decimalPad)

                Text("%")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Menu

struct TrackerMenuField: View {
    var options: [TrackerOption]
    @Binding var selection: String
    /// Shown when `selection` matches nothing — e.g. before a bank is picked.
    var fallbackIcon: String = "square.grid.2x2"

    private var selected: TrackerOption? {
        options.first { $0.name == selection }
    }

    var body: some View {
        Menu {
            ForEach(options) { option in
                Button {
                    selection = option.name
                    Haptics.light()
                } label: {
                    Label(option.name, systemImage: option.icon)
                }
            }
        } label: {
            FieldShell {
                HStack(spacing: 11) {
                    FieldIcon(
                        systemName: selected?.icon ?? fallbackIcon,
                        tint: selected?.tint ?? .appGreen
                    )

                    Text(selection)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        // Shrinks further before truncating: "Entertainment" and "Home Loan"
                        // both land in half-width pairs where an ellipsis loses the meaning.
                        .minimumScaleFactor(0.7)

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

/// Compact reminder row — the chosen lead time, as a dropdown.
///
/// Carries no label of its own: the enclosing `TrackerField` already names it, and the two
/// together ("Remind me" above, "Alert" inside) left no room for the value in a half-width
/// pair — the inner label wrapped mid-word and the value truncated to an ellipsis.
struct TrackerReminderField: View {
    @Binding var selection: String

    static let options = [
        "On due date",
        "1 day before",
        "2 days before",
        "3 days before",
        "1 week before",
        "No reminder"
    ]

    var body: some View {
        Menu {
            ForEach(Self.options, id: \.self) { option in
                Button(option) {
                    selection = option
                    Haptics.light()
                }
            }
        } label: {
            FieldShell {
                HStack(spacing: 11) {
                    FieldIcon(systemName: "bell")

                    Text(selection)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Date

/// Date row that opens a calendar sheet. A `nil` binding renders `emptyLabel`, which is
/// how optional dates ("No end date") stay distinguishable from today's date.
struct TrackerDateField: View {
    @Binding var date: Date?
    var emptyLabel: String = "No end date"
    var allowsClearing: Bool = false
    var range: PartialRangeFrom<Date>? = nil

    @State private var isPickerPresented = false
    @State private var draft = Date()

    var body: some View {
        Button {
            draft = date ?? Date()
            isPickerPresented = true
            Haptics.light()
        } label: {
            FieldShell {
                HStack(spacing: 11) {
                    FieldIcon(systemName: "calendar")

                    // Abbreviated month — "7 Aug 2026" fits the half-width pairs the date
                    // fields land in, where the full month name truncated to "7 August…"
                    // and cost you the year.
                    Text(date.map { $0.formatted(.dateTime.day().month(.abbreviated).year()) } ?? emptyLabel)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(date == nil ? .secondary : .primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isPickerPresented) {
            datePickerSheet
        }
    }

    private var datePickerSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Group {
                    if let range {
                        DatePicker("", selection: $draft, in: range, displayedComponents: .date)
                    } else {
                        DatePicker("", selection: $draft, displayedComponents: .date)
                    }
                }
                .datePickerStyle(.graphical)
                .tint(.appGreen)
                .padding(.horizontal, 12)

                Spacer()

                if allowsClearing && date != nil {
                    Button {
                        date = nil
                        isPickerPresented = false
                        Haptics.light()
                    } label: {
                        Text("Clear date")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .secondaryButton(tint: .appExpenseRed)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                }

                Button {
                    date = draft
                    isPickerPresented = false
                    Haptics.medium()
                } label: {
                    Text("Done")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .primaryButton()
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Select Date")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Toggle

struct TrackerToggleField: View {
    var title: String
    var subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        FieldShell(vertical: 12) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)

                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .tint(.appGreen)
            }
        }
    }
}

// MARK: - Icon & colour

/// Icon and colour picker. The preview tile on the left shows the pairing as it will
/// appear in lists, so the choice is judged the way it will actually be seen.
struct TrackerIconColorPicker: View {
    var icons: [String]
    @Binding var selectedIcon: String
    @Binding var selectedColor: Color

    static let palette: [Color] = [
        .appGreen,
        Color(red: 59/255, green: 130/255, blue: 246/255),
        Color(red: 147/255, green: 51/255, blue: 234/255),
        Color(red: 236/255, green: 72/255, blue: 153/255),
        Color(red: 249/255, green: 115/255, blue: 22/255),
        Color(red: 245/255, green: 197/255, blue: 66/255),
        .appTeal,
        .appExpenseRed,
        .appIndigo
    ]

    var body: some View {
        // Shares the field surface with every other control: it is the one picker that isn't
        // built on FieldShell, so on the page background it would otherwise have no card.
        FieldShell {
            pickerBody
        }
    }

    private var pickerBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selectedColor.opacity(0.16))
                    .frame(width: 46, height: 46)
                    .overlay(
                        Image(systemName: selectedIcon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(selectedColor)
                    )

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(icons, id: \.self) { icon in
                            Button {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                    selectedIcon = icon
                                }
                                Haptics.light()
                            } label: {
                                Circle()
                                    .fill(selectedIcon == icon ? selectedColor.opacity(0.14) : Color.primary.opacity(0.05))
                                    .frame(width: 38, height: 38)
                                    .overlay(
                                        Image(systemName: icon)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(selectedIcon == icon ? selectedColor : .secondary)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(Self.palette.enumerated()), id: \.offset) { _, color in
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                selectedColor = color
                            }
                            Haptics.light()
                        } label: {
                            Circle()
                                .fill(color)
                                .frame(width: 26, height: 26)
                                .overlay(
                                    Circle()
                                        .stroke(color, lineWidth: 2)
                                        .padding(-4)
                                        .opacity(selectedColor == color ? 1 : 0)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 4)
            }
        }
    }
}

// MARK: - Banner

/// Encouragement banner above the primary action.
struct TrackerInfoBanner: View {
    var icon: String
    var title: String
    var message: String
    var tint: Color = .appGreen

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text(message)
                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Circle()
                .fill(tint.opacity(0.14))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundColor(tint)
                )
        }
        .padding(14)
        .background(Color(red: 240/255, green: 250/255, blue: 244/255))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Layout helpers

/// Two fields side by side, as the mockups pair Category/Priority and Amount/Date.
struct TrackerFieldPair<Leading: View, Trailing: View>: View {
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            leading.frame(maxWidth: .infinity, alignment: .leading)
            trailing.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

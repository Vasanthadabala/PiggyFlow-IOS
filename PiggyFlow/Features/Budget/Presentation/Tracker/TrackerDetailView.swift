import SwiftUI
import SwiftData
import UIKit

/// Detail screen for a single bill/subscription/EMI tracker, reached by tapping a row in
/// Upcoming Payments. Every field here maps to a real `TrackerRecord` property — Category,
/// Provider, Payment Method and Reference ID are all collected by the Add Subscription/EMI
/// forms and now persisted (they used to be typed in and silently discarded). Payment History
/// is a real, growing log: one entry per "Mark as Paid" tap, starting empty for every tracker
/// rather than inventing past payments that never happened.
struct TrackerDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let record: TrackerRecord

    @State private var showDeleteAlert = false
    @State private var showRescheduleSheet = false
    @State private var notesText: String
    @FocusState private var notesFocused: Bool

    init(record: TrackerRecord) {
        self.record = record
        _notesText = State(initialValue: record.notes)
    }

    private var calendar: Calendar { .current }

    private var daysUntilDue: Int {
        let today = calendar.startOfDay(for: Date())
        let due = calendar.startOfDay(for: record.dueDate)
        return calendar.dateComponents([.day], from: today, to: due).day ?? 0
    }

    private var statusText: String {
        if record.isPaid { return "Paid" }
        return daysUntilDue < 0 ? "Overdue" : "Upcoming"
    }

    private var statusColor: Color {
        if record.isPaid { return .appGreen }
        return daysUntilDue < 0 ? .appExpenseRed : .appGreen
    }

    private var duePillText: String {
        if record.isPaid { return "Paid" }
        if daysUntilDue < 0 { return "Overdue by \(abs(daysUntilDue)) day\(abs(daysUntilDue) == 1 ? "" : "s")" }
        if daysUntilDue == 0 { return "Due today" }
        return "Due in \(daysUntilDue) day\(daysUntilDue == 1 ? "" : "s")"
    }

    /// The date this would next be due after the current one — one recurrence cycle past
    /// `dueDate`, derived from `subType` rather than stored. `nil` for kinds whose `subType`
    /// isn't a cadence word (Goal stores a priority there, not a recurrence).
    private var nextCycleDate: Date? {
        switch record.subType.lowercased() {
        case "weekly": return calendar.date(byAdding: .weekOfYear, value: 1, to: record.dueDate)
        case "monthly": return calendar.date(byAdding: .month, value: 1, to: record.dueDate)
        case "quarterly": return calendar.date(byAdding: .month, value: 3, to: record.dueDate)
        case "half-yearly": return calendar.date(byAdding: .month, value: 6, to: record.dueDate)
        case "yearly": return calendar.date(byAdding: .year, value: 1, to: record.dueDate)
        default: return nil
        }
    }

    private var providerLabel: String { record.type == "emi" ? "Lender" : "Provider" }
    private var referenceLabel: String { record.type == "emi" ? "Account Number" : "Reference ID" }
    private var cancelActionTitle: String {
        switch record.type {
        case "subscription": return "Cancel Subscription"
        case "emi": return "Cancel EMI"
        default: return "Delete Tracker"
        }
    }

    private var detailRows: [(icon: String, label: String, value: String, copyable: Bool)] {
        var rows: [(String, String, String, Bool)] = []
        if !record.category.isEmpty { rows.append(("tag.fill", "Category", record.category, false)) }
        if !record.provider.isEmpty { rows.append(("person.fill", providerLabel, record.provider, false)) }
        if !record.paymentMethod.isEmpty { rows.append(("creditcard.fill", "Payment Method", record.paymentMethod, false)) }
        if !record.referenceID.isEmpty { rows.append(("number", referenceLabel, record.referenceID, true)) }
        if let nextCycleDate {
            rows.append(("calendar", "Next Billing Date", nextCycleDate.formatted(.dateTime.month(.abbreviated).day().year()), false))
        }
        return rows
    }

    private var recentPayments: [Date] { record.paidDates.sorted(by: >).prefix(5).map { $0 } }

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    heroCard
                    overviewGrid
                    detailsCard
                    paymentHistoryCard
                    notesCard
                    moreActionsSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 12)
            }
            .safeAreaInset(edge: .bottom) { bottomBar }
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .background(Color.appBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .sheet(isPresented: $showRescheduleSheet) {
            RescheduleTrackerSheet(dueDate: record.dueDate) { newDate in
                record.dueDate = newDate
                try? context.save()
            }
        }
        .alert("Delete Tracker?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) { deleteTracker() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove \(record.name) from your trackers. This action cannot be undone.")
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            BackButton { dismiss() }

            Spacer()

            VStack(spacing: 2) {
                Text(record.name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(record.type.capitalized)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Menu {
                Button(role: .destructive) { showDeleteAlert = true } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.appSurface)
                        .frame(width: 40, height: 40)
                        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
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

    // MARK: - Hero Card

    private var heroCard: some View {
        HStack(spacing: 14) {
            TrackerAvatar(record: record, size: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(record.name)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(record.subType.isEmpty ? record.type.capitalized : "\(record.type.capitalized) • \(record.subType.capitalized)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Text(duePillText)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(statusColor.opacity(0.12))
                    .clipShape(Capsule())
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 2) {
                Text(AppFormatter.currency(record.amount))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("Amount")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .groupedCard(cornerRadius: 18)
    }

    // MARK: - Overview Grid

    private var overviewGrid: some View {
        HStack(spacing: 10) {
            overviewCell(
                icon: "calendar",
                iconColor: .appGreen,
                value: record.dueDate.formatted(.dateTime.month(.abbreviated).day().year()),
                title: "Due Date",
                caption: daysUntilDue < 0 ? "\(abs(daysUntilDue))d overdue" : "In \(daysUntilDue)d"
            )
            overviewCell(
                icon: "arrow.triangle.2.circlepath",
                iconColor: Color(red: 217/255, green: 119/255, blue: 6/255),
                value: record.subType.isEmpty ? "—" : record.subType.capitalized,
                title: "Recurrence",
                caption: record.type.capitalized
            )
            overviewCell(
                icon: "indianrupeesign.circle",
                iconColor: Color(red: 225/255, green: 29/255, blue: 72/255),
                value: AppFormatter.currencyRounded(record.amount),
                title: "Amount",
                caption: "Due amount"
            )
            overviewCell(
                icon: record.isPaid ? "checkmark.circle" : "clock",
                iconColor: statusColor,
                value: statusText,
                title: "Status",
                caption: record.isPaid ? "Completed" : "Not paid yet"
            )
        }
    }

    @ViewBuilder
    private func overviewCell(icon: String, iconColor: Color, value: String, title: String, caption: String) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(caption)
                .font(.system(size: 8.5, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    // MARK: - Details

    @ViewBuilder
    private var detailsCard: some View {
        if !detailRows.isEmpty {
            VStack(spacing: 0) {
                HStack {
                    Text("Details")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(16)

                RowDivider().padding(.horizontal, 16)

                VStack(spacing: 0) {
                    ForEach(Array(detailRows.enumerated()), id: \.offset) { index, row in
                        detailRow(icon: row.icon, label: row.label, value: row.value, copyable: row.copyable)
                        if index < detailRows.count - 1 {
                            RowDivider().padding(.leading, 48)
                        }
                    }
                }
            }
            .groupedCard(cornerRadius: 18)
        }
    }

    @ViewBuilder
    private func detailRow(icon: String, label: String, value: String, copyable: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.appGreen)
                .frame(width: 24)
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if copyable {
                Button {
                    Haptics.light()
                    UIPasteboard.general.string = value
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Payment History

    private var paymentHistoryCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Payment History")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(16)

            RowDivider().padding(.horizontal, 16)

            if recentPayments.isEmpty {
                Text("No payments recorded yet")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.7))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recentPayments.enumerated()), id: \.offset) { index, date in
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 15))
                                .foregroundColor(.appGreen)
                            Text(date.formatted(.dateTime.month(.abbreviated).day().year()))
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(.primary)
                            Spacer()
                            Text(AppFormatter.currency(record.amount))
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        if index < recentPayments.count - 1 {
                            RowDivider().padding(.leading, 42)
                        }
                    }
                }
            }
        }
        .groupedCard(cornerRadius: 18)
    }

    // MARK: - Notes

    private var notesCard: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Text("Notes")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                Spacer()
            }
            .padding(16)

            RowDivider().padding(.horizontal, 16)

            ZStack(alignment: .topLeading) {
                if notesText.isEmpty {
                    Text("Add a note")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.7))
                        .padding(.top, 2)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $notesText)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .scrollContentBackground(.hidden)
                    .frame(height: 60)
                    .focused($notesFocused)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .groupedCard(cornerRadius: 18)
        .onChange(of: notesFocused) { _, isFocused in
            guard !isFocused else { return }
            saveNotesIfChanged()
        }
    }

    // MARK: - More Actions

    private var moreActionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("More Actions")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            HStack(spacing: 10) {
                actionButton(icon: "calendar.badge.clock", title: "Reschedule", tint: .primary) {
                    Haptics.light()
                    showRescheduleSheet = true
                }
                actionButton(icon: "xmark.circle", title: cancelActionTitle, tint: .appExpenseRed) {
                    Haptics.light()
                    showDeleteAlert = true
                }
            }
        }
    }

    @ViewBuilder
    private func actionButton(icon: String, title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .foregroundColor(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.appSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(tint.opacity(0.2), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bottom Bar

    @ViewBuilder
    private var bottomBar: some View {
        if !record.isPaid {
            VStack(spacing: 0) {
                Button {
                    markAsPaid()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text("Mark as Paid")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color.appGreenDeep)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .background(Color.appBackground.ignoresSafeArea(edges: .bottom))
        }
    }

    // MARK: - Actions

    private func saveNotesIfChanged() {
        guard notesText != record.notes else { return }
        record.notes = notesText
        try? context.save()
    }

    private func markAsPaid() {
        Haptics.medium()
        record.isPaid = true
        record.paidDates.append(Date())
        try? context.save()
    }

    private func deleteTracker() {
        Haptics.medium()
        context.delete(record)
        try? context.save()
        dismiss()
    }
}

// MARK: - Reschedule Sheet

private struct RescheduleTrackerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var dueDate: Date
    let onSave: (Date) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(Color.appGreen)

                Spacer()

                Button {
                    Haptics.medium()
                    onSave(dueDate)
                    dismiss()
                } label: {
                    Text("Save")
                        .font(.system(size: 15.5, weight: .bold, design: .rounded))
                        .primaryButton(tint: .appGreenDeep, enabled: true, cornerRadius: 16)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Reschedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

import SwiftUI
import SwiftData

struct UpcomingPaymentsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query private var trackerRecords: [TrackerRecord]

    @State private var showAddTrackerSheet: Bool = false

    // Sample fallback records when SwiftData is empty
    private var allPaymentRecords: [TrackerRecord] {
        if !trackerRecords.isEmpty {
            return trackerRecords.sorted { $0.dueDate < $1.dueDate }
        }
        let cal = Calendar.current
        let today = Date()
        return [
            TrackerRecord(type: "subscription", name: "Netflix", subType: "Entertainment", amount: 649, dueDate: cal.date(byAdding: .day, value: 2, to: today) ?? today, logoUrl: ""),
            TrackerRecord(type: "subscription", name: "Spotify Premium", subType: "Music", amount: 119, dueDate: cal.date(byAdding: .day, value: 4, to: today) ?? today, logoUrl: ""),
            TrackerRecord(type: "bill", name: "Mobile Phone Bill", subType: "Airtel", amount: 599, dueDate: cal.date(byAdding: .day, value: 5, to: today) ?? today),
            TrackerRecord(type: "bill", name: "Electricity Bill", subType: "TNEB", amount: 1245, dueDate: cal.date(byAdding: .day, value: 6, to: today) ?? today),
            TrackerRecord(type: "emi", name: "HDFC Home Loan EMI", subType: "Home Loan", amount: 28500, dueDate: cal.date(byAdding: .day, value: 9, to: today) ?? today),
            TrackerRecord(type: "subscription", name: "Amazon Prime", subType: "Shopping", amount: 299, dueDate: cal.date(byAdding: .day, value: 10, to: today) ?? today, logoUrl: ""),
            TrackerRecord(type: "bill", name: "Gas Bill", subType: "HP Gas", amount: 1100, dueDate: cal.date(byAdding: .day, value: 11, to: today) ?? today),
            TrackerRecord(type: "bill", name: "Internet Bill", subType: "Jio Fiber", amount: 799, dueDate: cal.date(byAdding: .day, value: 12, to: today) ?? today),
            TrackerRecord(type: "subscription", name: "Swiggy One", subType: "Food", amount: 149, dueDate: cal.date(byAdding: .day, value: 14, to: today) ?? today, logoUrl: "")
        ]
    }

    private var dueSoonRecords: [TrackerRecord] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return allPaymentRecords.filter { record in
            let dueDay = cal.startOfDay(for: record.dueDate)
            let diff = cal.dateComponents([.day], from: today, to: dueDay).day ?? 999
            return diff >= 0 && diff <= 7 && !record.isPaid
        }
    }

    private var dueThisMonthRecords: [TrackerRecord] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return allPaymentRecords.filter { record in
            let dueDay = cal.startOfDay(for: record.dueDate)
            let diff = cal.dateComponents([.day], from: today, to: dueDay).day ?? 999
            // Due this month but NOT in due soon
            return diff > 7 && cal.isDate(record.dueDate, equalTo: Date(), toGranularity: .month) && !record.isPaid
        }
    }

    private var totalAmount: Double {
        allPaymentRecords.filter { !$0.isPaid }.reduce(0) { $0 + $1.amount }
    }

    private var thisMonthCount: Int {
        let cal = Calendar.current
        return allPaymentRecords.filter {
            cal.isDate($0.dueDate, equalTo: Date(), toGranularity: .month) && !$0.isPaid
        }.count
    }

    private var paidThisMonthCount: Int {
        let cal = Calendar.current
        return allPaymentRecords.filter {
            cal.isDate($0.dueDate, equalTo: Date(), toGranularity: .month) && $0.isPaid
        }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerBar

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // 4-Stat Summary Grid
                    statsSummaryGrid

                    // Due Soon Section
                    if !dueSoonRecords.isEmpty {
                        dueSoonSection
                    }

                    // Due This Month Section
                    if !dueThisMonthRecords.isEmpty {
                        dueThisMonthSection
                    }

                    // Never Miss a Payment Banner
                    enableRemindersBanner
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 16)
            }
            // Reserves exactly the CTA's real height as scroll clearance, so list content
            // can never render behind the floating button regardless of how long the list is.
            .safeAreaInset(edge: .bottom) { stickyBottomCTA }
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .background(Color.appBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .sheet(isPresented: $showAddTrackerSheet) {
            AddTrackerModalSheet(onSave: { newRecord in
                context.insert(newRecord)
                try? context.save()
            })
        }
    }

    // MARK: - Header Bar
    private var headerBar: some View {
        VStack(spacing: 4) {
            HStack {
                BackButton { dismiss() }

                Spacer()

                Text("Upcoming Payments")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Spacer()

                Button {
                    Haptics.light()
                } label: {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color.appGreen)
                        .frame(width: 40, height: 40)
                        .background(Color.appGreen.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)

            Text("Track and manage all your upcoming bills, subscriptions and EMIs")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(Color.appBackground)
    }

    // MARK: - 4-Stat Summary Grid
    private var statsSummaryGrid: some View {
        HStack(spacing: 10) {
            statCell(
                icon: "calendar.badge.exclamationmark",
                iconColor: Color.appGreen,
                bgColor: Color.appGreen.opacity(0.1),
                title: "\(dueSoonRecords.count)",
                subtitle: "Due Soon",
                caption: "Next 7 days"
            )
            statCell(
                icon: "calendar",
                iconColor: Color(red: 217/255, green: 119/255, blue: 6/255),
                bgColor: Color(red: 217/255, green: 119/255, blue: 6/255).opacity(0.1),
                title: "\(thisMonthCount)",
                subtitle: "This Month",
                caption: "Total payments"
            )
            statCell(
                icon: "indianrupeesign.circle",
                iconColor: Color(red: 225/255, green: 29/255, blue: 72/255),
                bgColor: Color(red: 225/255, green: 29/255, blue: 72/255).opacity(0.1),
                title: "₹\(formatCompact(totalAmount))",
                subtitle: "Total Amount",
                caption: "This month"
            )
            statCell(
                icon: "checkmark.circle",
                iconColor: Color(red: 30/255, green: 64/255, blue: 175/255),
                bgColor: Color(red: 30/255, green: 64/255, blue: 175/255).opacity(0.1),
                title: "\(paidThisMonthCount)",
                subtitle: "Paid This Month",
                caption: "Payments"
            )
        }
    }

    private func formatCompact(_ value: Double) -> String {
        if value >= 1_00_000 {
            return String(format: "%.1fL", value / 1_00_000)
        } else if value >= 1000 {
            return String(format: "%.0fK", value / 1000)
        }
        return "\(Int(value))"
    }

    @ViewBuilder
    private func statCell(icon: String, iconColor: Color, bgColor: Color, title: String, subtitle: String, caption: String) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(bgColor)
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            Text(title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(subtitle)
                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.85)
            Text(caption)
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 4)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    // MARK: - Due Soon Section
    private var dueSoonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Due Soon")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
                Text("Next 7 days")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.appGreen)
            }

            VStack(spacing: 0) {
                ForEach(Array(dueSoonRecords.enumerated()), id: \.element.id) { idx, record in
                    dueSoonPaymentRow(record)
                    if idx < dueSoonRecords.count - 1 {
                        Divider().padding(.leading, 72)
                    }
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
        }
    }

    @ViewBuilder
    private func dueSoonPaymentRow(_ record: TrackerRecord) -> some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let dueDay = cal.startOfDay(for: record.dueDate)
        let daysDiff = cal.dateComponents([.day], from: today, to: dueDay).day ?? 0

        HStack(spacing: 14) {
            paymentAvatar(record)

            VStack(alignment: .leading, spacing: 3) {
                Text(record.name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(record.type.capitalized)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(record.subType.isEmpty ? record.type.capitalized : record.subType)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Text("Due in \(daysDiff) day\(daysDiff == 1 ? "" : "s")")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(Color.appGreen)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.appGreen.opacity(0.12))
                    .clipShape(Capsule())
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("₹\(Int(record.amount).formatted())")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text(record.dueDate.formatted(.dateTime.month(.abbreviated).day().year()))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white)
    }

    // MARK: - Due This Month Section
    private var dueThisMonthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Due This Month")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
                Text(Date().formatted(.dateTime.month(.wide).year()))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.appGreen)

                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 0) {
                ForEach(Array(dueThisMonthRecords.enumerated()), id: \.element.id) { idx, record in
                    dueThisMonthPaymentRow(record)
                    if idx < dueThisMonthRecords.count - 1 {
                        Divider().padding(.leading, 72)
                    }
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
        }
    }

    @ViewBuilder
    private func dueThisMonthPaymentRow(_ record: TrackerRecord) -> some View {
        HStack(spacing: 14) {
            paymentAvatar(record)

            VStack(alignment: .leading, spacing: 3) {
                Text(record.name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(record.type.capitalized)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(record.subType.isEmpty ? record.type.capitalized : record.subType)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Image(systemName: "calendar")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text(record.dueDate.formatted(.dateTime.month(.abbreviated).day().year()))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("₹\(Int(record.amount).formatted())")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                // Type badge for subscriptions
                if record.type.lowercased() == "subscription" {
                    Text("Subscription")
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundColor(Color.appGreen)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.appGreen.opacity(0.12))
                        .clipShape(Capsule())
                } else if record.type.lowercased() == "emi" {
                    Text("EMI")
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 30/255, green: 64/255, blue: 175/255))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(red: 30/255, green: 64/255, blue: 175/255).opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white)
    }

    // MARK: - Payment Avatar
    @ViewBuilder
    private func paymentAvatar(_ record: TrackerRecord) -> some View {
        let nameLower = record.name.lowercased()
        if nameLower.contains("netflix") {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.black)
                Text("N")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(.red)
            }
            .frame(width: 46, height: 46)
        } else if nameLower.contains("spotify") {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black)
                Image(systemName: "waveform")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(red: 30/255, green: 215/255, blue: 96/255))
            }
            .frame(width: 46, height: 46)
        } else if nameLower.contains("amazon") {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(red: 255/255, green: 153/255, blue: 0/255))
                Text("prime")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            }
            .frame(width: 46, height: 46)
        } else if nameLower.contains("mobile") || nameLower.contains("phone") {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(red: 30/255, green: 64/255, blue: 175/255))
                Image(systemName: "phone.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(width: 46, height: 46)
        } else if nameLower.contains("electricity") {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(red: 217/255, green: 119/255, blue: 6/255))
                Image(systemName: "bolt.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(width: 46, height: 46)
        } else if nameLower.contains("loan") || nameLower.contains("emi") || record.type.lowercased() == "emi" {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.appGreen.opacity(0.15))
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color.appGreen)
            }
            .frame(width: 46, height: 46)
        } else if nameLower.contains("gas") {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.orange.opacity(0.15))
                Image(systemName: "flame.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.orange)
            }
            .frame(width: 46, height: 46)
        } else if nameLower.contains("internet") {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.blue.opacity(0.15))
                Image(systemName: "wifi")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.blue)
            }
            .frame(width: 46, height: 46)
        } else if nameLower.contains("swiggy") {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.orange)
                Image(systemName: "bag.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(width: 46, height: 46)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.appGreen.opacity(0.12))
                Text(String(record.name.prefix(1)).uppercased())
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(Color.appGreen)
            }
            .frame(width: 46, height: 46)
        }
    }

    // MARK: - Enable Reminders Banner
    private var enableRemindersBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.appGreen)

                Text("Never miss a payment. Enable reminders for all your bills.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                Haptics.light()
            } label: {
                HStack(spacing: 4) {
                    Text("Enable Reminders")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(Color.appGreen)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.appGreen.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Sticky Bottom CTA
    private var stickyBottomCTA: some View {
        VStack(spacing: 0) {
            Button {
                Haptics.medium()
                showAddTrackerSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                    Text("Add Payment Tracker")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(red: 22/255, green: 120/255, blue: 70/255))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 28)
            .background(Color.appBackground.ignoresSafeArea())
        }
    }
}

// MARK: - Add Tracker Modal Sheet
struct AddTrackerModalSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var trackerName: String = ""
    @State private var trackerType: String = "subscription"
    @State private var billingCycle: String = "monthly"
    @State private var trackerAmount: String = ""
    @State private var dueDate: Date = Date()

    let onSave: (TrackerRecord) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Tracker Name")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                        TextField("e.g. Netflix, Car Loan EMI", text: $trackerName)
                            .padding(12)
                            .background(Color.primary.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Type")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                        Picker("Type", selection: $trackerType) {
                            Text("Subscription").tag("subscription")
                            Text("EMI").tag("emi")
                            Text("Bill").tag("bill")
                        }
                        .pickerStyle(.segmented)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Amount (₹)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                        TextField("e.g. 649", text: $trackerAmount)
                            .keyboardType(.numberPad)
                            .padding(12)
                            .background(Color.primary.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Due Date")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                        DatePicker("", selection: $dueDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .tint(Color.appGreen)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)

                Spacer()

                Button {
                    let amt = Double(trackerAmount) ?? 0
                    let record = TrackerRecord(
                        type: trackerType,
                        name: trackerName.isEmpty ? "New Tracker" : trackerName,
                        subType: billingCycle,
                        amount: amt,
                        dueDate: dueDate
                    )
                    onSave(record)
                    dismiss()
                } label: {
                    Text("Save Tracker")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.appGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle("Add Payment Tracker")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    UpcomingPaymentsView()
}

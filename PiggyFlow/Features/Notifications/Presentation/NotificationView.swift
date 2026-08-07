import SwiftUI
import SwiftData
import UserNotifications

struct NotificationView: View {
    @Query private var trackerRecords: [TrackerRecord]

    private var upcomingAlerts: [TrackerRecord] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return trackerRecords.filter { record in
            let dueDay = calendar.startOfDay(for: record.dueDate)
            let diff = calendar.dateComponents([.day], from: today, to: dueDay).day ?? 999
            return diff >= 0 && diff <= 7 && !record.isPaid
        }.sorted { $0.dueDate < $1.dueDate }
    }

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 16) {
                if upcomingAlerts.isEmpty {
                    VStack(spacing: 14) {
                        Spacer()

                        TintedIconCircle(color: .appGreen, size: 80) {
                            Image(systemName: "bell.slash.fill")
                                .font(.system(size: 28))
                        }

                        Text("No Pending Alerts")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)

                        Text("You are all caught up! No upcoming bill due dates in the next 7 days.")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)

                        Spacer()
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("UPCOMING REMINDERS")
                                    .sectionEyebrow()

                                Spacer()

                                Button("Clear All") {
                                    clearNotifications()
                                }
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(.appExpenseRed)
                            }
                            .padding(.leading, 4)

                            VStack(spacing: 0) {
                                ForEach(Array(upcomingAlerts.enumerated()), id: \.element.id) { pair in
                                    let record = pair.element
                                    HStack(spacing: 14) {
                                        TintedIconCircle(color: .appWarningAmber, size: 44, cornerRadius: 14) {
                                            Image(systemName: "bell.fill")
                                                .font(.system(size: 18))
                                        }

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text("\(record.name) Payment Due")
                                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                                .foregroundColor(.primary)

                                            Text("Due \(record.dueDate.formatted(.dateTime.day().month(.abbreviated).year()))")
                                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                                .foregroundColor(.appWarningAmber)
                                        }

                                        Spacer()

                                        Text("₹\(record.amount, specifier: "%.2f")")
                                            .font(.system(size: 15, weight: .bold, design: .rounded))
                                            .foregroundColor(.primary)
                                    }
                                    .flatRow(vertical: 14, horizontal: 16)

                                    if pair.offset != upcomingAlerts.count - 1 {
                                        RowDivider()
                                    }
                                }
                            }
                            .groupedCard()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    }
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func clearNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}

#Preview {
    NavigationStack {
        NotificationView()
    }
}

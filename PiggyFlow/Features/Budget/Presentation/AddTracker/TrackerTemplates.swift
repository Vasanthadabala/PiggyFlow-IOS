import SwiftUI

/// A saved starting point for a tracker.
///
/// Most trackers people add are near-copies of ones they've added before — the same rent
/// budget every year, the same streaming subscriptions. A template carries the handful of
/// fields worth pre-filling; everything else stays at its default so nothing is silently
/// wrong after applying one.
struct TrackerTemplate: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var kindRawValue: String
    var title: String
    var category: String
    var amount: String
    var recurrence: String
    var icon: String
    /// Index into `TrackerIconColorPicker.palette` — `Color` isn't `Codable`.
    var colorIndex: Int

    var kind: TrackerKind {
        TrackerKind(rawValue: kindRawValue) ?? .budget
    }

    var color: Color {
        let palette = TrackerIconColorPicker.palette
        return palette.indices.contains(colorIndex) ? palette[colorIndex] : .appGreen
    }
}

/// Built-in and user-saved templates.
enum TrackerTemplateStore {

    private static let storageKey = "tracker.user.templates"

    static let builtIn: [TrackerTemplate] = [
        TrackerTemplate(kindRawValue: TrackerKind.budget.rawValue, title: "Monthly Groceries", category: "Food & Dining", amount: "12000", recurrence: "Monthly", icon: "cart.fill", colorIndex: 0),
        TrackerTemplate(kindRawValue: TrackerKind.budget.rawValue, title: "Fuel & Commute", category: "Transport", amount: "6000", recurrence: "Monthly", icon: "car.fill", colorIndex: 2),
        TrackerTemplate(kindRawValue: TrackerKind.budget.rawValue, title: "Dining Out", category: "Food & Dining", amount: "5000", recurrence: "Monthly", icon: "fork.knife", colorIndex: 4),

        TrackerTemplate(kindRawValue: TrackerKind.goal.rawValue, title: "Emergency Fund", category: "Emergency Fund", amount: "100000", recurrence: "High", icon: "shield.fill", colorIndex: 0),
        TrackerTemplate(kindRawValue: TrackerKind.goal.rawValue, title: "Vacation", category: "Travel", amount: "50000", recurrence: "Medium", icon: "airplane", colorIndex: 1),
        TrackerTemplate(kindRawValue: TrackerKind.goal.rawValue, title: "New Laptop", category: "Shopping", amount: "80000", recurrence: "Medium", icon: "trophy.fill", colorIndex: 2),

        TrackerTemplate(kindRawValue: TrackerKind.subscription.rawValue, title: "Netflix Premium", category: "Entertainment", amount: "649", recurrence: "Monthly", icon: "play.rectangle.fill", colorIndex: 7),
        TrackerTemplate(kindRawValue: TrackerKind.subscription.rawValue, title: "Spotify", category: "Entertainment", amount: "119", recurrence: "Monthly", icon: "music.note", colorIndex: 0),
        TrackerTemplate(kindRawValue: TrackerKind.subscription.rawValue, title: "iCloud+ Storage", category: "Utilities", amount: "219", recurrence: "Monthly", icon: "icloud.fill", colorIndex: 1),

        TrackerTemplate(kindRawValue: TrackerKind.emi.rawValue, title: "Home Loan", category: "Home Loan", amount: "2000000", recurrence: "20 Years", icon: "house.fill", colorIndex: 0),
        TrackerTemplate(kindRawValue: TrackerKind.emi.rawValue, title: "Car Loan", category: "Car Loan", amount: "800000", recurrence: "7 Years", icon: "car.fill", colorIndex: 1)
    ]

    static func userTemplates() -> [TrackerTemplate] {
        UserDefaultsManager.shared.decode([TrackerTemplate].self, for: storageKey) ?? []
    }

    static func save(_ template: TrackerTemplate) {
        var templates = userTemplates()
        templates.removeAll { $0.title == template.title && $0.kindRawValue == template.kindRawValue }
        templates.insert(template, at: 0)
        UserDefaultsManager.shared.encode(templates, for: storageKey)
    }

    static func delete(_ template: TrackerTemplate) {
        let remaining = userTemplates().filter { $0.id != template.id }
        UserDefaultsManager.shared.encode(remaining, for: storageKey)
    }

    static func templates(for kind: TrackerKind) -> (saved: [TrackerTemplate], builtIn: [TrackerTemplate]) {
        (
            saved: userTemplates().filter { $0.kind == kind },
            builtIn: builtIn.filter { $0.kind == kind }
        )
    }
}

/// Template picker presented from the "Templates" action in the header.
struct TrackerTemplatesSheet: View {
    @Environment(\.dismiss) private var dismiss

    let kind: TrackerKind
    var onSelect: (TrackerTemplate) -> Void

    @State private var saved: [TrackerTemplate] = []

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    if !saved.isEmpty {
                        templateGroup(title: "Your Templates", templates: saved, deletable: true)
                    }

                    templateGroup(
                        title: "Suggested",
                        templates: TrackerTemplateStore.templates(for: kind).builtIn,
                        deletable: false
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("\(kind.rawValue) Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.appGreen)
                }
            }
            .onAppear {
                saved = TrackerTemplateStore.templates(for: kind).saved
            }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private func templateGroup(title: String, templates: [TrackerTemplate], deletable: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .sectionEyebrow()

            VStack(spacing: 0) {
                ForEach(Array(templates.enumerated()), id: \.element.id) { index, template in
                    HStack(spacing: 8) {
                        Button {
                            Haptics.medium()
                            onSelect(template)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                TintedIconCircle(color: template.color, size: 40, cornerRadius: 12) {
                                    Image(systemName: template.icon)
                                        .font(.system(size: 17, weight: .semibold))
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(template.title)
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .foregroundColor(.primary)

                                    Text("\(template.category)  •  \(template.recurrence)")
                                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                                        .foregroundColor(.secondary)
                                }

                                Spacer(minLength: 6)

                                Text(AppFormatter.currencyRounded(Double(template.amount) ?? 0))
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if deletable {
                            Button {
                                Haptics.light()
                                TrackerTemplateStore.delete(template)
                                saved = TrackerTemplateStore.templates(for: kind).saved
                            } label: {
                                Image(systemName: AppIcon.Action.delete)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.appExpenseRed)
                                    .frame(width: 30, height: 30)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .flatRow()

                    if index < templates.count - 1 {
                        RowDivider(leadingInset: 68)
                    }
                }
            }
            .groupedCard()
        }
    }
}

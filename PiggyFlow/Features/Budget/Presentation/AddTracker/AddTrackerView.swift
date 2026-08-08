import SwiftUI
import SwiftData

/// Creates a budget, goal, subscription or EMI tracker.
///
/// The type picker at the top swaps the form body while keeping shared entries (title,
/// amount, icon), so changing your mind about what you're tracking doesn't reset the screen.
/// `lockedToInitialKind` hides that picker for callers that already committed to one kind.
struct AddTrackerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    /// Which tab opens first — callers that already know the type skip the picker step.
    var initialKind: TrackerKind = .budget

    /// Hides the type picker and keeps `kind` fixed to `initialKind` — for entry points that
    /// already commit to one kind (the Budget screen's own "Add Budget" action), where
    /// offering a switcher to Goal/Subscription/EMI would just be noise.
    var lockedToInitialKind: Bool = false

    /// Called with the saved record, for callers that want to react (scroll to it, refresh).
    var onSave: ((TrackerRecord) -> Void)? = nil

    @State private var kind: TrackerKind = .budget
    @State private var form = TrackerFormState()
    @State private var showTemplates = false
    @State private var didLoadInitialKind = false
    @State private var savedTemplateConfirmation = false

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        formSections

                        TrackerInfoBanner(
                            icon: bannerIcon,
                            title: bannerTitle,
                            message: bannerMessage
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 2)
                    .padding(.bottom, 24)
                }
                // Inset by the action bar itself rather than a guessed height — the old fixed
                // 132pt was shorter than the two stacked buttons, so the last field stayed
                // trapped underneath them no matter how far you scrolled.
                .safeAreaInset(edge: .bottom) { bottomActions }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            // Only on first appearance: coming back from a sheet shouldn't undo a tab change.
            guard !didLoadInitialKind else { return }
            didLoadInitialKind = true
            kind = initialKind
            form.icon = initialKind.defaultIcon
        }
        .sheet(isPresented: $showTemplates) {
            TrackerTemplatesSheet(kind: kind) { template in
                apply(template)
            }
        }
        .alert("Template saved", isPresented: $savedTemplateConfirmation) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("\"\(form.title)\" is now available from Templates.")
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        ScreenHeader(
            title: kind.screenTitle,
            subtitle: kind.screenSubtitle,
            onBack: { dismiss() }
        ) {
            ScreenHeaderAction(icon: "doc.on.doc", title: "Templates") {
                showTemplates = true
            }
        }
    }

    // MARK: - Form

    /// Sections sit directly on the page rather than inside one enclosing card, matching Add
    /// Expense and Add Income: an outside label, then the control itself as a white surface.
    private var formSections: some View {
        VStack(alignment: .leading, spacing: 18) {
            if !lockedToInitialKind {
                TrackerField(title: "Tracker Type") {
                    typePicker
                }
            }

            switch kind {
            case .budget:       BudgetTrackerForm(form: $form)
            case .goal:         GoalTrackerForm(form: $form)
            case .subscription: SubscriptionTrackerForm(form: $form)
            case .emi:          EMITrackerForm(form: $form)
            }
        }
    }

    private var typePicker: some View {
        HStack(spacing: 0) {
            ForEach(Array(TrackerKind.allCases.enumerated()), id: \.element.id) { index, item in
                Button {
                    Haptics.light()
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                        select(item)
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.tabIcon)
                            .font(.system(size: 15, weight: .semibold))

                        Text(item.rawValue)
                            .font(.system(size: 11, weight: kind == item ? .bold : .medium, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .foregroundColor(kind == item ? Color.appGreenDeep : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(kind == item ? Color.appGreen.opacity(0.12) : Color.clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if index < TrackerKind.allCases.count - 1 {
                    Rectangle()
                        .fill(Color.primary.opacity(0.07))
                        .frame(width: 1, height: 30)
                }
            }
        }
        .padding(4)
        .liftedControl(cornerRadius: 14)
    }

    // MARK: - Bottom actions

    private var bottomActions: some View {
        VStack(spacing: 10) {
            Button {
                Haptics.medium()
                save()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: AppIcon.Status.success)
                        .font(.system(size: 15, weight: .bold))
                    Text(kind.ctaTitle)
                        .font(.system(size: 15.5, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .primaryButton(tint: .appGreenDeep, enabled: form.isValid(for: kind))
            }
            .buttonStyle(.plain)
            .disabled(!form.isValid(for: kind))

            Button {
                Haptics.light()
                saveAsTemplate()
            } label: {
                Text("Save as Template")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(form.title.isEmpty ? .secondary : .appGreen)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .disabled(form.title.isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
        // Fully opaque: at 0.98 the form scrolled visibly through the bar behind the buttons.
        .background(Color.appBackground)
    }

    // MARK: - Banner copy

    private var bannerIcon: String {
        switch kind {
        case .budget:       return "target"
        case .goal:         return "flag.fill"
        case .subscription: return "calendar.badge.clock"
        case .emi:          return "checkmark.shield.fill"
        }
    }

    private var bannerTitle: String {
        switch kind {
        case .budget:       return "Stay consistent, achieve more!"
        case .goal:         return "Stay focused. Achieve your dreams!"
        case .subscription: return "Never miss a renewal"
        case .emi:          return "Stay on track and become debt free!"
        }
    }

    private var bannerMessage: String {
        switch kind {
        case .budget:       return "Track your progress and achieve your financial goals."
        case .goal:         return "Track your progress and turn your goals into reality."
        case .subscription: return "We'll remind you before every billing date."
        case .emi:          return "We'll remind you so you never miss an important EMI."
        }
    }

    // MARK: - Actions

    /// Switching type carries the icon over only if it was still the previous type's default —
    /// a deliberately chosen icon survives the switch.
    private func select(_ newKind: TrackerKind) {
        if form.icon == kind.defaultIcon {
            form.icon = newKind.defaultIcon
        }
        kind = newKind
    }

    private func apply(_ template: TrackerTemplate) {
        kind = template.kind
        form.title = template.title
        form.amount = template.amount
        form.icon = template.icon
        form.color = template.color

        switch template.kind {
        case .budget:
            form.category = template.category
            form.period = template.recurrence
        case .goal:
            form.goalCategory = template.category
            form.priority = template.recurrence
        case .subscription:
            form.subscriptionCategory = template.category
            form.billingCycle = template.recurrence
        case .emi:
            form.loanType = template.category
            form.loanAmount = template.amount
            form.amount = ""
            form.tenure = template.recurrence
        }
    }

    private func saveAsTemplate() {
        let palette = TrackerIconColorPicker.palette
        let colorIndex = palette.firstIndex(of: form.color) ?? 0

        let recurrence: String
        let category: String
        switch kind {
        case .budget:       recurrence = form.period;        category = form.category
        case .goal:         recurrence = form.priority;      category = form.goalCategory
        case .subscription: recurrence = form.billingCycle;  category = form.subscriptionCategory
        case .emi:          recurrence = form.tenure;        category = form.loanType
        }

        TrackerTemplateStore.save(
            TrackerTemplate(
                kindRawValue: kind.rawValue,
                title: form.title,
                category: category,
                amount: kind == .emi ? form.loanAmount : form.amount,
                recurrence: recurrence,
                icon: form.icon,
                colorIndex: colorIndex
            )
        )

        savedTemplateConfirmation = true
    }

    private func save() {
        guard form.isValid(for: kind) else { return }

        let record = TrackerRecord(
            type: kind.storageType,
            name: form.title.trimmingCharacters(in: .whitespacesAndNewlines),
            subType: form.storedSubType(for: kind),
            amount: form.storedAmount(for: kind),
            dueDate: form.dueDate(for: kind),
            logoUrl: form.icon,
            isPaid: false,
            category: form.storedCategory(for: kind),
            currentAmount: kind == .goal ? form.currentAmountValue : 0,
            notes: form.notes
        )

        context.insert(record)
        try? context.save()

        onSave?(record)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        AddTrackerView()
    }
    .modelContainer(for: TrackerRecord.self, inMemory: true)
}

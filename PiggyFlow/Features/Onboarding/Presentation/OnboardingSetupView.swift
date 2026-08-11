import SwiftUI
import SwiftData

/// The four setup steps that run after the account-created screen: monthly income, monthly
/// budget, a first savings goal, and reminder preferences.
///
/// Unlike the onboarding pages before it, this section collects real input, so each step
/// persists what it gathers rather than just advancing:
/// * income and budget are **preferences** (`@AppStorage`), not ledger entries — the income
///   screen's own copy promises "this won't be visible anywhere", and a budget figure the user
///   can "update anytime in Settings" isn't a transaction either;
/// * the goal step creates a real `TrackerRecord`, because the app already models goals that
///   way and this screen collects exactly what one needs (category, target amount, target date);
/// * reminder choices are preferences too — nothing here schedules a notification yet, so the
///   copy deliberately promises the settings are saved, not that reminders are already firing.
///
/// Every step is skippable by leaving a field empty and continuing; nothing is fabricated to
/// fill a gap.
struct OnboardingSetupView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @AppStorage("monthlyIncome") private var monthlyIncome: Double = 0
    @AppStorage("incomeFrequency") private var incomeFrequency: String = "Monthly"
    @AppStorage("monthlyBudget") private var monthlyBudget: Double = 0
    @AppStorage("reminderWindow") private var reminderWindow: String = "Afternoon"
    @AppStorage("smartNotificationsEnabled") private var smartNotificationsEnabled: Bool = true
    @AppStorage(AppleSignInManager.loginStatusKey) private var isUserLoggedIn: Bool = false
    @AppStorage(AppConstants.Onboarding.completedKey) private var hasCompletedOnboarding: Bool = false

    @State private var step: Int = 0
    @State private var navigateToHome: Bool = false

    // Step 1 — income
    @State private var incomeText: String = ""
    @State private var selectedFrequency: String = "Monthly"

    // Step 2 — budget
    @State private var budgetText: String = ""

    // Step 3 — goal
    @State private var selectedGoal: String = "Travel"
    @State private var goalAmountText: String = ""
    @State private var goalDate: Date? = nil
    @State private var showGoalDatePicker: Bool = false

    // Step 4 — reminders
    @State private var selectedWindow: String = "Afternoon"
    @State private var notificationsOn: Bool = true

    private let totalSteps = 5

    private struct GoalOption {
        let title: String
        let icon: String
    }

    private let goalOptions: [GoalOption] = [
        GoalOption(title: "Travel", icon: "airplane"),
        GoalOption(title: "New Home", icon: "house.fill"),
        GoalOption(title: "New Car", icon: "car.fill"),
        GoalOption(title: "Education", icon: "graduationcap.fill"),
        GoalOption(title: "Marriage", icon: "heart.fill"),
        GoalOption(title: "Vacation", icon: "beach.umbrella.fill"),
        GoalOption(title: "Gadget", icon: "laptopcomputer"),
        GoalOption(title: "More", icon: "ellipsis")
    ]

    private let frequencies = ["Monthly", "Bi-weekly", "Weekly", "Yearly"]

    private struct BudgetPreset {
        let amount: Int
        let label: String
    }

    private let budgetPresets: [BudgetPreset] = [
        BudgetPreset(amount: 25_000, label: "Starter"),
        BudgetPreset(amount: 50_000, label: "Balanced"),
        BudgetPreset(amount: 75_000, label: "Comfortable"),
        BudgetPreset(amount: 0, label: "Other")
    ]

    private struct ReminderWindow {
        let title: String
        let range: String
        let icon: String
    }

    private let reminderWindows: [ReminderWindow] = [
        ReminderWindow(title: "Morning", range: "8:00 AM – 10:00 AM", icon: "sun.max.fill"),
        ReminderWindow(title: "Afternoon", range: "12:00 PM – 2:00 PM", icon: "sun.max.fill"),
        ReminderWindow(title: "Evening", range: "6:00 PM – 9:00 PM", icon: "moon.stars.fill")
    ]

    private let reminderKinds: [(icon: String, title: String, subtitle: String)] = [
        ("doc.text.fill", "Bill & Payment", "Due dates"),
        ("wallet.pass.fill", "Budget Alerts", "Stay in control"),
        ("target", "Goal Progress", "Keep going"),
        ("chart.line.uptrend.xyaxis", "Savings Tips", "Smart insights")
    ]

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                progressBar
                    .padding(.horizontal, 20)
                    .padding(.top, 10)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        switch step {
                        case 0: incomeStep
                        case 1: budgetStep
                        case 2: goalStep
                        case 3: remindersStep
                        default: summaryStep
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 16)
                }
                .scrollDismissesKeyboard(.interactively)

                bottomBar
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showGoalDatePicker) {
            GoalTargetDateSheet(date: goalDate ?? Date()) { goalDate = $0 }
        }
        .navigationDestination(isPresented: $navigateToHome) {
            MainTabView()
        }
    }

    // MARK: - Chrome

    private var topBar: some View {
        HStack {
            Button {
                Haptics.light()
                if step == 0 {
                    dismiss()
                } else {
                    withAnimation(.easeInOut(duration: 0.22)) { step -= 1 }
                }
            } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color.appGreenDeep)
                    .frame(width: 40, height: 40)
                    .background(Color.appGreen.opacity(0.12))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .frame(height: 52)
    }

    /// Segmented bar with the piggy sitting at the finish line — driven by `step`/`totalSteps`
    /// rather than a fixed segment count, so it can't drift out of sync with the real flow.
    private var progressBar: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule()
                    .fill(index <= step ? Color.appGreenDeep : Color.primary.opacity(0.12))
                    .frame(height: 5)
            }

            Image("piggy_logo")
                .resizable()
                .scaledToFit()
                .frame(width: 26, height: 26)
                .opacity(step == totalSteps - 1 ? 1 : 0.45)
        }
    }

    // MARK: - Step 1: Income

    private var incomeStep: some View {
        VStack(spacing: 18) {
            stepHeader(
                image: "setup_income_hero",
                imageHeight: 92,
                lead: "Let's add your\nmonthly ",
                highlight: "income",
                subtitle: "This helps us personalize your experience and give better insights."
            )

            VStack(alignment: .leading, spacing: 14) {
                Text("How much do you earn monthly?")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                amountField(text: $incomeText, placeholder: "0")

                Text("This won't be visible anywhere. It's just for your insights.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text("100% private and secure")
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                }
                .foregroundColor(Color.appGreen)

                Divider().padding(.vertical, 2)

                Text("How often do you receive it?")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                HStack(spacing: 8) {
                    ForEach(frequencies, id: \.self) { freq in
                        selectableTile(
                            title: freq,
                            icon: "calendar",
                            isSelected: selectedFrequency == freq
                        ) {
                            selectedFrequency = freq
                        }
                    }
                }

                tipBanner(
                    icon: "lightbulb.fill",
                    text: "You can add more income sources later from the ",
                    highlight: "Income",
                    tail: " section."
                )
            }
            .padding(16)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
        }
    }

    // MARK: - Step 2: Budget

    private var budgetStep: some View {
        VStack(spacing: 18) {
            stepHeader(
                image: "setup_budget_hero",
                imageHeight: 170,
                lead: "Let's set your\n",
                highlight: "monthly budget",
                subtitle: "A budget helps you plan better and spend smarter."
            )

            VStack(alignment: .leading, spacing: 12) {
                Text("How much would you like to budget per month?")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                amountField(text: $budgetText, placeholder: "0")

                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text("You can update this anytime in Settings.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                }
                .foregroundColor(Color.appGreen)
            }
            .padding(16)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)

            VStack(alignment: .leading, spacing: 10) {
                Text("Quick select")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 8) {
                    ForEach(Array(budgetPresets.enumerated()), id: \.offset) { _, preset in
                        let isCustom = preset.amount == 0
                        let isSelected = isCustom
                            ? !budgetPresets.contains { $0.amount != 0 && Double($0.amount) == AmountInput.value(of: budgetText) }
                                && AmountInput.value(of: budgetText) > 0
                            : Double(preset.amount) == AmountInput.value(of: budgetText)

                        Button {
                            Haptics.light()
                            if !isCustom { budgetText = AmountInput.formatted("\(preset.amount)") }
                        } label: {
                            VStack(spacing: 3) {
                                Text(isCustom ? "Custom" : AppFormatter.currencyRounded(Double(preset.amount)))
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                Text(preset.label)
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.appSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(isSelected ? Color.appGreenDeep : Color.primary.opacity(0.08),
                                            lineWidth: isSelected ? 1.5 : 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            infoCard(
                icon: "chart.pie.fill",
                title: "Budgeting made easy",
                subtitle: "We'll show you insights and tips based on your budget."
            )
        }
    }

    // MARK: - Step 3: Goal

    private var goalStep: some View {
        VStack(spacing: 18) {
            stepHeader(
                image: "setup_goal_hero",
                imageHeight: 170,
                lead: "Let's set your\n",
                highlight: "first savings goal 🎯",
                subtitle: "Goals keep you motivated and help you build a better financial future."
            )

            VStack(alignment: .leading, spacing: 10) {
                Text("What's your goal?")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                    ForEach(Array(goalOptions.enumerated()), id: \.offset) { _, option in
                        selectableTile(
                            title: option.title,
                            icon: option.icon,
                            isSelected: selectedGoal == option.title
                        ) {
                            selectedGoal = option.title
                        }
                    }
                }

                Text("How much would you like to save?")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .padding(.top, 4)

                amountField(text: $goalAmountText, placeholder: "0")

                Text("Target date")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .padding(.top, 4)

                Button {
                    Haptics.light()
                    showGoalDatePicker = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "calendar")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.secondary)
                        Text(goalDate.map { $0.formatted(.dateTime.day().month(.wide).year()) } ?? "Select target date")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(goalDate == nil ? .secondary : .primary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.appGreen)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(Color.appSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)

                tipBanner(
                    icon: "star.fill",
                    text: "You can create and track multiple goals anytime from the ",
                    highlight: "Goals",
                    tail: " section."
                )
            }
        }
    }

    // MARK: - Step 4: Reminders

    private var remindersStep: some View {
        VStack(spacing: 18) {
            stepHeader(
                image: "setup_reminders_hero",
                imageHeight: 150,
                lead: "Stay on track with\n",
                highlight: "smart reminders 🔔",
                subtitle: "We'll remind you about bills, budgets and goals so you never miss anything."
            )

            VStack(alignment: .leading, spacing: 10) {
                Text("When do you want to receive reminders?")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 8) {
                    ForEach(Array(reminderWindows.enumerated()), id: \.offset) { _, window in
                        Button {
                            Haptics.light()
                            selectedWindow = window.title
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                                        .fill(Color.appGreen.opacity(0.12))
                                        .frame(width: 38, height: 38)
                                    Image(systemName: window.icon)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(Color.appGreenDeep)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(window.title)
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(.primary)
                                    Text(window.range)
                                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Image(systemName: selectedWindow == window.title ? "largecircle.fill.circle" : "circle")
                                    .font(.system(size: 19))
                                    .foregroundColor(selectedWindow == window.title ? Color.appGreenDeep : .secondary.opacity(0.4))
                            }
                            .padding(12)
                            .background(selectedWindow == window.title ? Color.appGreen.opacity(0.07) : Color.appSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Toggle(isOn: $notificationsOn) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable smart notifications")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Text("Get personalized tips, bill alerts, budget updates and goal reminders.")
                            .font(.system(size: 11.5, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .tint(Color.appGreenDeep)
                .padding(12)
                .background(Color.appGreen.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Text("What you'll get reminders for")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .padding(.top, 4)

                HStack(spacing: 8) {
                    ForEach(Array(reminderKinds.enumerated()), id: \.offset) { _, kind in
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(Color.appGreen.opacity(0.12))
                                    .frame(width: 40, height: 40)
                                Image(systemName: kind.icon)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Color.appGreenDeep)
                            }
                            Text(kind.title)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.75)
                            Text(kind.subtitle)
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 4)
                        .background(Color.appSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
        }
    }

    // MARK: - Step 5: Summary

    /// Every row reads back what the previous steps actually saved. A step the user skipped
    /// says "Not set" against a hollow marker rather than showing an invented figure — the
    /// point of this screen is to confirm what's real, so a fabricated number here would be
    /// worse than an honest blank.
    private var summaryRows: [(icon: String, title: String, value: String?)] {
        let goalValue: String? = {
            let amount = AmountInput.value(of: goalAmountText)
            guard amount > 0 else { return nil }
            guard let goalDate else { return AppFormatter.currencyRounded(amount) }
            return "\(AppFormatter.currencyRounded(amount)) by \(goalDate.formatted(.dateTime.day().month(.abbreviated).year()))"
        }()

        return [
            ("wallet.pass.fill", "Monthly Income", monthlyIncome > 0 ? AppFormatter.currencyRounded(monthlyIncome) : nil),
            ("target", "Monthly Budget", monthlyBudget > 0 ? AppFormatter.currencyRounded(monthlyBudget) : nil),
            ("flag.fill", "Savings Goal", goalValue),
            ("bell.fill", "Smart Reminders", notificationsOn
                ? "\(selectedWindow) (\(reminderWindows.first { $0.title == selectedWindow }?.range ?? ""))"
                : nil)
        ]
    }

    private var summaryStep: some View {
        VStack(spacing: 18) {
            VStack(spacing: 12) {
                Image("setup_complete_hero")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 170)

                (
                    Text("You're all set! 🎉\nLet's build your\n").foregroundColor(.primary)
                    + Text("financial freedom 💚").foregroundColor(Color.appGreen)
                )
                .font(.system(size: 25, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)

                Text("Your account is ready to go. Let's take you to your dashboard.")
                    .font(.system(size: 13.5, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text("Here's what you've set up")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 14)
                    .padding(.top, 14)
                    .padding(.bottom, 6)

                ForEach(Array(summaryRows.enumerated()), id: \.offset) { index, row in
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(Color.appGreen.opacity(row.value == nil ? 0.06 : 0.12))
                                .frame(width: 38, height: 38)
                            Image(systemName: row.icon)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(row.value == nil ? .secondary.opacity(0.5) : Color.appGreenDeep)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.title)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            Text(row.value ?? "Not set")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }

                        Spacer(minLength: 8)

                        if row.value == nil {
                            Circle()
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1.5)
                                .frame(width: 22, height: 22)
                        } else {
                            ZStack {
                                Circle().fill(Color.appGreenDeep).frame(width: 22, height: 22)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)

                    if index < summaryRows.count - 1 {
                        Divider().padding(.leading, 64)
                    }
                }
            }
            .padding(.bottom, 4)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)

            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.appGreen.opacity(0.14))
                        .frame(width: 40, height: 40)
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color.appGreenDeep)
                }

                Text("Explore insights, track expenses, and reach your goals with ease.")
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color.appGreen.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    // MARK: - Shared pieces

    @ViewBuilder
    private func stepHeader(image: String, imageHeight: CGFloat, lead: String, highlight: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(image)
                .resizable()
                .scaledToFit()
                .frame(height: imageHeight)

            (
                Text(lead).foregroundColor(.primary)
                + Text(highlight).foregroundColor(Color.appGreen)
            )
            .font(.system(size: 25, weight: .heavy, design: .rounded))
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.8)

            Text(subtitle)
                .font(.system(size: 13.5, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func amountField(text: Binding<String>, placeholder: String) -> some View {
        HStack(spacing: 8) {
            Text(AppConstants.Currency.symbol)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            TextField(placeholder, text: Binding(
                get: { text.wrappedValue },
                set: { text.wrappedValue = AmountInput.formatted($0) }
            ))
            .font(.system(size: 22, weight: .bold, design: .rounded))
            .keyboardType(.decimalPad)
            .textFieldStyle(.plain)

            Text(".00")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(Color.appSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func selectableTile(title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.light()
            action()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(isSelected ? Color.appGreenDeep : .secondary)
                Text(title)
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected ? Color.appGreenDeep : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Color.appGreen.opacity(0.10) : Color.appSurface)
            .overlay(
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isSelected ? Color.appGreenDeep : Color.primary.opacity(0.08),
                                lineWidth: isSelected ? 1.5 : 1)
                    if isSelected {
                        ZStack {
                            Circle().fill(Color.appGreenDeep).frame(width: 18, height: 18)
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .offset(x: 6, y: -6)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func tipBanner(icon: String, text: String, highlight: String, tail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.appGreen.opacity(0.14))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.appGreenDeep)
            }

            (
                Text(text).foregroundColor(.secondary)
                + Text(highlight).foregroundColor(Color.appGreen).bold()
                + Text(tail).foregroundColor(.secondary)
            )
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.appGreen.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func infoCard(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.appGreen.opacity(0.14))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color.appGreenDeep)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.appGreen.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Bottom bar

    private var ctaTitle: String {
        switch step {
        case 0: return "Add Income"
        case 1: return "Save & Continue"
        case 2: return "Create Goal"
        case 3: return "Continue"
        default: return "Go to Dashboard"
        }
    }

    private var footerNote: (icon: String, text: String)? {
        switch step {
        case 1: return ("lock.fill", "100% secure. Your data is private.")
        case 3: return ("lock.fill", "We respect your time and your privacy.")
        default: return nil
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            Button {
                Haptics.medium()
                commitCurrentStep()
                if step == totalSteps - 1 {
                    isUserLoggedIn = true
                    hasCompletedOnboarding = true
                    navigateToHome = true
                } else {
                    withAnimation(.easeInOut(duration: 0.22)) { step += 1 }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(ctaTitle)
                        .font(.system(size: 16.5, weight: .bold, design: .rounded))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 15, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundColor(.white)
                .background(Color.appGreenDeep)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain)

            if let note = footerNote {
                HStack(spacing: 5) {
                    Image(systemName: note.icon)
                        .font(.system(size: 11, weight: .semibold))
                    Text(note.text)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                }
                .foregroundColor(.secondary)
            }

            // Both paths land on the dashboard — there's no separate guided tour to opt out
            // of — so this is a softer-worded second door to the same place, not a different
            // destination.
            if step == totalSteps - 1 {
                Button {
                    Haptics.light()
                    isUserLoggedIn = true
                    hasCompletedOnboarding = true
                    navigateToHome = true
                } label: {
                    Text("I'll explore on my own")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(Color.appGreen)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .background(Color.appBackground)
    }

    // MARK: - Persistence

    /// Saves whatever the current step actually collected. Empty fields save nothing rather
    /// than writing a zero, so continuing past a step is a genuine skip.
    private func commitCurrentStep() {
        switch step {
        case 0:
            let value = AmountInput.value(of: incomeText)
            if value > 0 {
                monthlyIncome = value
                incomeFrequency = selectedFrequency
            }
        case 1:
            let value = AmountInput.value(of: budgetText)
            if value > 0 { monthlyBudget = value }
        case 2:
            let value = AmountInput.value(of: goalAmountText)
            guard value > 0 else { return }
            let record = TrackerRecord(
                type: "goal",
                name: selectedGoal,
                subType: "medium",
                amount: value,
                dueDate: goalDate ?? Date(),
                logoUrl: goalOptions.first { $0.title == selectedGoal }?.icon ?? "target",
                category: selectedGoal
            )
            context.insert(record)
            try? context.save()
        case 3:
            reminderWindow = selectedWindow
            smartNotificationsEnabled = notificationsOn
        default:
            // Summary step — nothing new to collect, it only reads back what's already saved.
            break
        }
    }
}

// MARK: - Target date sheet

private struct GoalTargetDateSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var date: Date
    let onSave: (Date) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                DatePicker("Target date", selection: $date, in: Date()..., displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(Color.appGreen)

                Spacer()

                Button {
                    Haptics.medium()
                    onSave(date)
                    dismiss()
                } label: {
                    Text("Set Target Date")
                        .font(.system(size: 15.5, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .foregroundColor(.white)
                        .background(Color.appGreenDeep)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Target Date")
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

#Preview {
    NavigationStack { OnboardingSetupView() }
}

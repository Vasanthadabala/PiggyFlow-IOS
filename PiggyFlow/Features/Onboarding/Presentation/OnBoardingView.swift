import SwiftUI
import Combine

struct OnBoardingScreen: View {
    @AppStorage("username") private var userName: String = ""
    @State private var currentSlide: Int = 0
    @State private var navigateToLoginOptions: Bool = false
    @State private var isButtonPressed = false

    private struct OnboardingSlide: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        let iconName: String
        let badge: String
        let accentColor: Color
    }

    private let slides: [OnboardingSlide] = [
        OnboardingSlide(
            title: "Smart Daily Expense Tracking",
            subtitle: "Log your income and expenses seamlessly with intuitive categorization and receipt bill scanning.",
            iconName: "wallet.pass.fill",
            badge: "EXPENSE TRACKER",
            accentColor: .appGreen
        ),
        OnboardingSlide(
            title: "Subscriptions & EMI Reminders",
            subtitle: "Never miss a bill due date again. Keep track of active EMIs, recurring subscriptions, and auto-renewals.",
            iconName: "clock.badge.checkmark.fill",
            badge: "BILL TRACKER",
            accentColor: .appTeal
        ),
        OnboardingSlide(
            title: "Category Budgets & Insights",
            subtitle: "Set monthly spending goals, analyze financial trends, and receive instant spending recommendations.",
            iconName: "chart.pie.fill",
            badge: "BUDGET & ANALYTICS",
            accentColor: .appIndigo
        )
    ]

    private let autoScrollTimer = Timer.publish(every: 3.5, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack {
                // Gradient Background
                LinearGradient(
                    colors: [Color.appGreen.opacity(0.06), Color.appBackground],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header Brand Badge
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: "piggy.bank.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.appGreen)
                            Text("PiggyFlow")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                    Spacer(minLength: 12)

                    // Hero Feature Carousel Card
                    TabView(selection: $currentSlide) {
                        ForEach(slides.indices, id: \.self) { index in
                            let slide = slides[index]
                            VStack(spacing: 24) {
                                // Hero Icon Container
                                ZStack {
                                    Circle()
                                        .fill(slide.accentColor.opacity(0.12))
                                        .frame(width: 150, height: 150)


                                    Image(systemName: slide.iconName)
                                        .font(.system(size: 56, weight: .semibold))
                                        .foregroundColor(slide.accentColor)
                                }
                                .padding(.top, 10)

                                VStack(spacing: 10) {
                                    Text(slide.badge)
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .tracking(1.2)
                                        .foregroundColor(slide.accentColor)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 5)
                                        .background(slide.accentColor.opacity(0.12))
                                        .clipShape(Capsule())

                                    Text(slide.title)
                                        .font(.system(size: 24, weight: .bold, design: .rounded))
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(.primary)
                                        .minimumScaleFactor(0.85)

                                    Text(slide.subtitle)
                                        .font(.system(size: 15, weight: .medium, design: .rounded))
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(.secondary)
                                        .lineSpacing(3)
                                        .padding(.horizontal, 16)
                                }
                            }
                            .padding(24)
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: 380)

                    // Indicator Dots
                    HStack(spacing: 8) {
                        ForEach(slides.indices, id: \.self) { index in
                            Capsule()
                                .fill(index == currentSlide ? Color.appGreen : Color.primary.opacity(0.15))
                                .frame(width: index == currentSlide ? 24 : 8, height: 8)
                                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: currentSlide)
                        }
                    }
                    .padding(.bottom, 28)

                    Spacer(minLength: 12)

                    // Actions
                    VStack(spacing: 14) {
                        Button {
                            Haptics.medium()
                            navigateToLoginOptions = true
                        } label: {
                            HStack(spacing: 8) {
                                Text("Get Started")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .foregroundColor(.white)
                            .background(Color.appGreen)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
                            .scaleEffect(isButtonPressed ? 0.97 : 1.0)
                            .animation(.spring(response: 0.2, dampingFraction: 0.5), value: isButtonPressed)
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in isButtonPressed = true }
                                .onEnded { _ in isButtonPressed = false }
                        )

                        HStack(spacing: 6) {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Text("100% Private & Secure · Syncs with your Cloud")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
            .onReceive(autoScrollTimer) { _ in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    currentSlide = (currentSlide + 1) % slides.count
                }
            }
            .navigationDestination(isPresented: $navigateToLoginOptions) {
                LoginOptionsView()
            }
        }
    }
}

#Preview {
    OnBoardingScreen()
}

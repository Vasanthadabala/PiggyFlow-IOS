import SwiftUI
import UIKit

struct OnBoardingScreen: View {
    @EnvironmentObject var appleSignInManager: AppleSignInManager
    @AppStorage(AppleSignInManager.loginStatusKey) private var isUserLoggedIn: Bool = false
    @AppStorage(AppConstants.Onboarding.completedKey) private var hasCompletedOnboarding: Bool = false
    @AppStorage(AppConstants.Onboarding.setupStartedKey) private var hasStartedSetup: Bool = false
    @State private var didStartAuthFlow: Bool = false
    @State private var showSignInToast: Bool = false
    @State private var isButtonPressed = false
    @State private var currentPage: Int = 0

    private struct Page {
        let heroImageName: String
        let titleLead: String
        let titleHighlight: String
        let subtitle: String
        let pills: [(icon: String, title: String)]
        let ctaTitle: String
        /// Most pages read hero image → headline; the sync page's mockup puts the headline
        /// first instead, so this is data-driven rather than assumed fixed.
        var headlineFirst: Bool = false
        /// Only the sync page has this — an extra reassurance banner between the hero and the
        /// pills. `nil` everywhere else, so nothing renders for the other pages.
        var securityBanner: (leadingIcon: String, title: String, subtitle: String, trailingIcon: String)? = nil
        /// The sync page's pills are a plain 3-column row with dividers, not individual cards.
        var compactPills: Bool = false
        /// Only the sign-up page has this — a dismissible-looking promo row with a trailing
        /// chevron, between the hero and the bottom actions.
        var promoBanner: (icon: String, title: String, subtitle: String)? = nil
        /// The sign-up page's bottom area is real auth actions (Google/Email/Log in), not the
        /// single generic CTA + "Log in" link every other page uses.
        var isFinalAuthPage: Bool = false
    }

    /// Onboarding is delivered a page at a time as designs come in — dots and swipe range
    /// always match `pages.count` exactly rather than a hardcoded total, so nothing here ever
    /// points at a page that doesn't exist yet.
    private let pages: [Page] = [
        Page(
            heroImageName: "onboarding_hero",
            titleLead: "Take control of your ",
            titleHighlight: "money",
            subtitle: "Track expenses, set budgets, achieve goals and build better financial habits.",
            pills: [
                ("wallet.pass.fill", "Track Expenses"),
                ("target", "Set Budgets & Goals"),
                ("chart.bar.fill", "Get Insights")
            ],
            ctaTitle: "Let's Get Started"
        ),
        Page(
            heroImageName: "onboarding_budget_hero",
            titleLead: "Budget smart, ",
            titleHighlight: "spend better",
            subtitle: "Create budgets for different categories and stay in control of your spending.",
            pills: [
                ("target", "Set monthly budgets"),
                ("bell.fill", "Get real-time alerts"),
                ("chart.pie.fill", "Avoid overspending with ease")
            ],
            ctaTitle: "Next"
        ),
        Page(
            heroImageName: "onboarding_goals_hero",
            titleLead: "Save for what ",
            titleHighlight: "truly matters",
            subtitle: "Create goals, track your progress and make your dreams a reality.",
            pills: [
                ("banknote.fill", "Create unlimited savings goals"),
                ("chart.line.uptrend.xyaxis", "Track progress visually"),
                ("calendar.badge.checkmark", "Stay motivated every day")
            ],
            ctaTitle: "Next"
        ),
        Page(
            heroImageName: "onboarding_scan_hero",
            titleLead: "Snap, scan and ",
            titleHighlight: "save",
            subtitle: "Capture bills, let AI do the work and save every expense effortlessly.",
            pills: [
                ("camera.fill", "Scan any bill or invoice"),
                ("sparkles", "AI extracts details instantly"),
                ("folder.fill", "Auto-categorize expenses")
            ],
            ctaTitle: "Next"
        ),
        Page(
            heroImageName: "onboarding_insights_hero",
            titleLead: "Understand today, plan for ",
            titleHighlight: "tomorrow",
            subtitle: "Get powerful insights and visual reports to analyze your finances and plan ahead.",
            pills: [
                ("chart.pie.fill", "Beautiful reports & charts"),
                ("chart.line.uptrend.xyaxis", "Track trends & patterns"),
                ("target", "Plan better & achieve more")
            ],
            ctaTitle: "Next"
        ),
        Page(
            heroImageName: "onboarding_sync_hero",
            titleLead: "All your finances, ",
            titleHighlight: "always in sync",
            subtitle: "Access your data securely from anywhere. Your financial world, across all your devices.",
            pills: [
                ("icloud.and.arrow.up.fill", "Backup & restore with ease"),
                ("macbook.and.iphone", "Works on all your devices"),
                ("wifi.slash", "Works offline, syncs when back")
            ],
            ctaTitle: "Continue",
            headlineFirst: true,
            securityBanner: (
                leadingIcon: "touchid",
                title: "Your security is our priority",
                subtitle: "Bank-level encryption keeps your data 100% safe and private.",
                trailingIcon: "checkmark.shield.fill"
            ),
            compactPills: true
        ),
        Page(
            heroImageName: "onboarding_signup_hero",
            titleLead: "Let's get started with ",
            titleHighlight: "PiggyFlow",
            subtitle: "Create your account in a few seconds and take control of your finances.",
            pills: [],
            ctaTitle: "Get Started",
            headlineFirst: true,
            promoBanner: (
                icon: "gift.fill",
                title: "Exclusive for you!",
                subtitle: "Sign up now and unlock premium features & personalized insights."
            ),
            isFinalAuthPage: true
        )
    ]

    /// Clamped so a page swap can never index past the end mid-transition.
    private var currentPageModel: Page {
        pages[min(max(currentPage, 0), pages.count - 1)]
    }

    private var isLastPage: Bool { currentPage == pages.count - 1 }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar

                    TabView(selection: $currentPage) {
                        ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                            pageContent(page, showLogo: index == 0)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut(duration: 0.25), value: currentPage)

                    // Outside the paged content so the dots sit at exactly the same height on
                    // every page — inside, they rode along with each page's content and drifted
                    // as the content above them changed height from page to page.
                    pageDots
                        .padding(.bottom, 4)

                    actions
                }

                if showSignInToast {
                    signInToast
                }
            }
        }
        .alert("Authentication Error", isPresented: Binding(
            get: { appleSignInManager.authErrorMessage != nil },
            set: { if !$0 { appleSignInManager.authErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { appleSignInManager.authErrorMessage = nil }
        } message: {
            Text(appleSignInManager.authErrorMessage ?? "Unknown error")
        }
        // Both flags have to be observed, not just `isAuthenticated`. The sign-in manager sets
        // `isAuthenticated = true` and only *then* clears `isAuthInProgress` on the following
        // line, so at the moment authentication flips true the "not still working" condition is
        // briefly false — watching only that one change meant the check never passed and the
        // screen sat there. Whichever of the two lands last completes the transition.
        .onChange(of: appleSignInManager.isAuthenticated) { _, _ in
            advanceIfAuthCompleted()
        }
        .onChange(of: appleSignInManager.isAuthInProgress) { _, _ in
            advanceIfAuthCompleted()
        }
        .onAppear {
            // If this screen is on-screen at all, onboarding demonstrably isn't finished, so the
            // flag can't be true — clearing it here keeps that invariant true by construction.
            //
            // Without this, a stale `true` left over from an earlier run (finishing setup once,
            // or "Skip Setup"/"Log in", all of which set it) combined with signing back in to
            // satisfy the root's `isSignedIn && hasCompletedOnboarding` check mid-flow, swapping
            // the root out to the dashboard the moment auth succeeded.
            hasCompletedOnboarding = false
            hasStartedSetup = false
        }
    }

    /// Skip and "Log in" both mean "take me to sign in", and the sign-up page *is* the sign-in
    /// screen — its Google/Apple buttons serve new and returning users alike. So both jump to
    /// the last page rather than pushing the older separate login screen on top of the tour.
    private func goToSignUpPage() {
        guard currentPage != pages.count - 1 else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            currentPage = pages.count - 1
        }
    }

    /// Signing in continues onboarding rather than dropping the user straight into the app:
    /// confirm with a brief toast and go on to the setup steps.
    private func advanceIfAuthCompleted() {
        guard didStartAuthFlow,
              appleSignInManager.isAuthenticated,
              !appleSignInManager.isAuthInProgress else { return }

        didStartAuthFlow = false
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            showSignInToast = true
        }

        // Long enough to register, short enough not to stall the flow. The push happens after
        // it so the toast is seen on this screen rather than flashing over the next one.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            withAnimation(.easeOut(duration: 0.2)) { showSignInToast = false }
            // Flips the root over to the setup steps — see `ContentView`. Not a push, so the
            // onboarding pages are dropped from the stack and can't be swiped back to.
            hasStartedSetup = true
        }
    }

    // MARK: - Sign-in Toast

    private var signInToast: some View {
        VStack {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color.appGreen)

                Text("Signed in successfully")
                    .font(.system(size: 14.5, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Color.appSurface)
            .clipShape(Capsule())
            .shadow(color: Color.black.opacity(0.12), radius: 14, x: 0, y: 6)
            .padding(.top, 8)

            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .zIndex(1)
    }

    // MARK: - Top Bar (Back + Skip)

    private var topBar: some View {
        HStack {
            if currentPage > 0 {
                Button {
                    Haptics.light()
                    withAnimation(.easeInOut(duration: 0.25)) { currentPage -= 1 }
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color.appGreenDeep)
                        .frame(width: 40, height: 40)
                        .background(Color.appGreen.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 40, height: 40)
            }

            Spacer()

            // No Skip on the sign-in page — it's the end of the tour, where the only things
            // left to do are sign in or log in. "Skip" there would just mean "skip signing in",
            // which the Google/Apple buttons and the "Log in" link below already cover.
            if !currentPageModel.isFinalAuthPage {
                Button {
                    Haptics.light()
                    goToSignUpPage()
                } label: {
                    HStack(spacing: 4) {
                        Text("Skip")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(Color.appGreenDeep)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(Color.appGreen.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .frame(height: 52)
    }

    // MARK: - Page Content

    /// A page always fits its own screen — no scrolling.
    ///
    /// This was a `ScrollView` with a fixed-size hero, which worked only while every page
    /// carried the same amount of content. Once later pages gained a taller (portrait) hero,
    /// a security banner, a four-row checklist or a promo banner, they overflowed and the top
    /// of the page silently scrolled out of view. Here the text blocks keep their intrinsic
    /// height and the illustration absorbs whatever vertical space is left over, so a dense
    /// page simply gets a smaller illustration instead of becoming scrollable — and it adapts
    /// per device rather than relying on hand-tuned heights.
    @ViewBuilder
    private func pageContent(_ page: Page, showLogo: Bool) -> some View {
        VStack(spacing: 16) {
            if showLogo {
                logoBlock
            }

            if page.headlineFirst {
                headline(lead: page.titleLead, highlight: page.titleHighlight, subtitle: page.subtitle)
                heroIllustration(page.heroImageName)
            } else {
                heroIllustration(page.heroImageName)
                headline(lead: page.titleLead, highlight: page.titleHighlight, subtitle: page.subtitle)
            }

            if let banner = page.securityBanner {
                securityBannerCard(banner)
            }

            if page.compactPills {
                compactFeatureRow(page.pills)
            } else if !page.pills.isEmpty {
                // The sign-up page carries no pills — rendering the row anyway would add
                // an empty band of padding between the hero and the promo banner.
                featurePills(page.pills)
            }

            if let promo = page.promoBanner {
                promoBannerCard(promo)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Logo

    private var logoBlock: some View {
        VStack(spacing: 6) {
            Image("piggy_logo")
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)

            Text("PiggyFlow")
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundColor(Color.appGreenDeep)
        }
    }

    // MARK: - Hero Illustration

    /// `maxHeight: .infinity` is what makes a page self-fitting: the illustration is the only
    /// element that flexes, so it takes the space the text blocks don't need and shrinks when
    /// they need more. `scaledToFit` keeps the aspect ratio intact at any resulting size, which
    /// also tames the one portrait-format asset (Insights) that used to run ~480pt tall.
    private func heroIllustration(_ imageName: String) -> some View {
        Image(imageName)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: 320, maxHeight: .infinity)
            .padding(.horizontal, 20)
    }

    // MARK: - Headline

    private func headline(lead: String, highlight: String, subtitle: String) -> some View {
        VStack(spacing: 10) {
            (
                Text(lead)
                    .foregroundColor(.primary)
                + Text(highlight)
                    .foregroundColor(Color.appGreen)
            )
            .font(.system(size: 30, weight: .heavy, design: .rounded))
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.85)

            Text(subtitle)
                .font(.system(size: 14.5, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Feature Pills

    private func featurePills(_ pills: [(icon: String, title: String)]) -> some View {
        HStack(spacing: 10) {
            ForEach(pills, id: \.title) { feature in
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.appGreen.opacity(0.16))
                            .frame(width: 30, height: 30)
                        Image(systemName: feature.icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color.appGreenDeep)
                    }
                    Text(feature.title)
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Security Banner (sync page only)

    private func securityBannerCard(_ banner: (leadingIcon: String, title: String, subtitle: String, trailingIcon: String)) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.appGreen.opacity(0.14))
                    .frame(width: 44, height: 44)
                Image(systemName: banner.leadingIcon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color.appGreenDeep)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(banner.title)
                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text(banner.subtitle)
                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)

            Image(systemName: banner.trailingIcon)
                .font(.system(size: 26, weight: .semibold))
                .foregroundColor(Color.appGreenDeep)
        }
        .padding(14)
        .background(Color.appGreen.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 20)
    }

    // MARK: - Promo Banner

    private func promoBannerCard(_ promo: (icon: String, title: String, subtitle: String)) -> some View {
        HStack(spacing: 14) {
            Image(systemName: promo.icon)
                .font(.system(size: 22))
                .foregroundColor(Color.appGreenDeep)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(promo.title)
                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                // The account-created variant puts everything in the title, so skip the
                // empty second line rather than rendering a blank row of leading.
                if !promo.subtitle.isEmpty {
                    Text(promo.subtitle)
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding(14)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 20)
    }

    // MARK: - Compact Feature Row (sync page only)

    private func compactFeatureRow(_ pills: [(icon: String, title: String)]) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(pills.enumerated()), id: \.offset) { index, feature in
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.appGreen.opacity(0.12))
                            .frame(width: 44, height: 44)
                        Image(systemName: feature.icon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Color.appGreenDeep)
                    }
                    Text(feature.title)
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)

                if index < pills.count - 1 {
                    Rectangle()
                        .fill(Color.primary.opacity(0.08))
                        .frame(width: 1, height: 44)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Page Dots

    private var pageDots: some View {
        HStack(spacing: 7) {
            ForEach(0..<pages.count, id: \.self) { index in
                if index == currentPage {
                    Capsule()
                        .fill(Color.appGreen)
                        .frame(width: 22, height: 7)
                } else {
                    Circle()
                        .fill(Color.primary.opacity(0.15))
                        .frame(width: 7, height: 7)
                }
            }
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private var actions: some View {
        if currentPageModel.isFinalAuthPage {
            authActions
        } else {
            standardActions
        }
    }

    private var standardActions: some View {
        VStack(spacing: 14) {
            Button {
                if isLastPage {
                    Haptics.medium()
                    goToSignUpPage()
                } else {
                    Haptics.light()
                    withAnimation(.easeInOut(duration: 0.25)) { currentPage += 1 }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(currentPageModel.ctaTitle)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 15, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundColor(.white)
                .background(Color.appGreenDeep)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
                .scaleEffect(isButtonPressed ? 0.97 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.5), value: isButtonPressed)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isButtonPressed = true }
                    .onEnded { _ in isButtonPressed = false }
            )

            Button {
                Haptics.light()
                goToSignUpPage()
            } label: {
                HStack(spacing: 4) {
                    Text("Already have an account?")
                        .foregroundColor(.secondary)
                    Text("Log in")
                        .foregroundColor(Color.appGreen)
                }
                .font(.system(size: 13.5, weight: .semibold, design: .rounded))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 20)
    }

    /// The sign-up page's real actions — both buttons call the exact same sign-in paths
    /// `LoginOptionsView` uses (real Firebase auth calls, not page-advances or fake flows).
    /// No "Continue with Email" — there's no email/password or magic-link auth anywhere in
    /// this app, so it isn't offered here rather than pretending to collect an email that
    /// goes nowhere.
    private var authActions: some View {
        VStack(spacing: 14) {
            Button {
                Haptics.medium()
                didStartAuthFlow = true
                guard let rootController = UIApplication.topViewController() else {
                    appleSignInManager.authErrorMessage = "Unable to open Google sign in screen."
                    return
                }
                appleSignInManager.signInWithGoogle(presentingViewController: rootController)
            } label: {
                HStack(spacing: 10) {
                    if appleSignInManager.isAuthInProgress {
                        ProgressView().tint(.primary)
                    } else {
                        Image("google")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                    }
                    Text(appleSignInManager.isAuthInProgress ? "Signing in..." : "Continue with Google")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(appleSignInManager.isAuthInProgress)

            Button {
                Haptics.medium()
                didStartAuthFlow = true
                appleSignInManager.handleSignIn()
            } label: {
                HStack(spacing: 10) {
                    if appleSignInManager.isAuthInProgress {
                        ProgressView().tint(Color(uiColor: .systemBackground))
                    } else {
                        Image(systemName: "applelogo")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    Text(appleSignInManager.isAuthInProgress ? "Signing in..." : "Sign in with Apple")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                .foregroundColor(Color(uiColor: .systemBackground))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.primary)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(appleSignInManager.isAuthInProgress)

            Button {
                Haptics.light()
                goToSignUpPage()
            } label: {
                HStack(spacing: 4) {
                    Text("Already have an account?")
                        .foregroundColor(.secondary)
                    Text("Log in")
                        .foregroundColor(Color.appGreen)
                }
                .font(.system(size: 13.5, weight: .semibold, design: .rounded))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 20)
    }
}

#Preview {
    OnBoardingScreen()
}

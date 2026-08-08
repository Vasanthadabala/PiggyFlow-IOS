import SwiftUI
import StoreKit

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var showWhatsNew = false
    @State private var showPrivacyPolicy = false
    @State private var showTermsOfService = false

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var copyrightYear: String {
        String(Calendar.current.component(.year, from: Date()))
    }

    private enum HighlightKind {
        case scanner, reports, budgets, cloudSync
    }

    private struct Highlight: Identifiable {
        let id = UUID()
        let kind: HighlightKind
        let icon: String
        let tint: Color
        let title: String
        let subtitle: String
    }

    private let highlights: [Highlight] = [
        Highlight(kind: .scanner, icon: "doc.text.viewfinder", tint: .appGreen, title: "AI Bill Scanner", subtitle: "Scan any bill or receipt and let AI extract details automatically."),
        Highlight(kind: .reports, icon: AppIcon.Chart.bar, tint: .blue, title: "Smart Reports", subtitle: "Detailed insights and beautiful reports to understand your money better."),
        Highlight(kind: .budgets, icon: AppIcon.Finance.budget, tint: .appIndigo, title: "Goals & Budgets", subtitle: "Set goals, create budgets and achieve your financial milestones."),
        Highlight(kind: .cloudSync, icon: "cloud.fill", tint: .appWarningAmber, title: "Cloud Sync", subtitle: "Secure backup and sync across all your devices.")
    ]

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    heroSection
                    financeControlCard
                    whatsInsideCard
                    builtWithLoveCard
                    aboutLinksSection
                    footerText
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("About PiggyFlow")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    Haptics.light()
                    dismiss()
                } label: {
                    Image(systemName: AppIcon.Nav.back)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.appGreenDeep)
                }
            }
        }
        .sheet(isPresented: $showWhatsNew) { WhatsNewSheet() }
        .sheet(isPresented: $showPrivacyPolicy) {
            LegalPlaceholderSheet(title: "Privacy Policy", icon: "shield.checkered")
        }
        .sheet(isPresented: $showTermsOfService) {
            LegalPlaceholderSheet(title: "Terms of Service", icon: "doc.text")
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 14) {
            piggyIllustration
                .padding(.top, 8)

            VStack(spacing: 4) {
                HStack(spacing: 0) {
                    Text("Piggy")
                        .foregroundColor(.primary)
                    Text("Flow")
                        .foregroundColor(.appGreen)
                }
                .font(.system(size: 30, weight: .bold, design: .rounded))

                Text("Scan. Track. Save. Grow.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Text("Version \(appVersion)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.appGreenDeep)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.appGreen.opacity(0.14))
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .background(
            ZStack {
                LinearGradient(
                    colors: [Color.appGreen.opacity(0.14), Color.appBackground],
                    startPoint: .top,
                    endPoint: .bottom
                )
                sparkle(size: 11).offset(x: -108, y: -46)
                sparkle(size: 7).offset(x: 100, y: -70)
                sparkle(size: 15).offset(x: 112, y: 14)
                sparkle(size: 8).offset(x: -96, y: 40)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    /// A simplified rendering of the app icon's own piggy silhouette — same shapes (rounded
    /// body, ear, snout, coin slot, coin on top), just recoloured for a light card instead of
    /// the icon's solid green tile, since the icon itself has no transparent version to reuse.
    private var piggyIllustration: some View {
        ZStack {
            HStack(spacing: 28) {
                Capsule().fill(Color.appGreen).frame(width: 15, height: 20)
                Capsule().fill(Color.appGreen).frame(width: 15, height: 20)
            }
            .offset(x: -4, y: 46)

            Ellipse()
                .fill(Color.appGreen)
                .frame(width: 26, height: 34)
                .rotationEffect(.degrees(-18))
                .offset(x: 32, y: -36)

            Circle()
                .fill(Color.appGreen)
                .frame(width: 100, height: 92)
                .offset(x: -8)

            Circle()
                .fill(Color.appGreen)
                .frame(width: 44, height: 44)
                .offset(x: 42, y: 6)

            HStack(spacing: 6) {
                Capsule().fill(Color.appGreenDeep.opacity(0.5)).frame(width: 5, height: 11)
                Capsule().fill(Color.appGreenDeep.opacity(0.5)).frame(width: 5, height: 11)
            }
            .offset(x: 42, y: 8)

            Capsule()
                .fill(Color.appGreenDeep.opacity(0.45))
                .frame(width: 15, height: 3)
                .rotationEffect(.degrees(-25))
                .offset(x: 22, y: -14)

            Capsule()
                .fill(Color.appGreenDeep.opacity(0.5))
                .frame(width: 24, height: 5)
                .rotationEffect(.degrees(-8))
                .offset(x: -10, y: -38)

            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color.appWarningAmber, Color.orange], startPoint: .top, endPoint: .bottom))
                    .frame(width: 32, height: 32)
                    .overlay(Circle().stroke(Color.white.opacity(0.55), lineWidth: 1.5))
                Text("₹")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .shadow(color: .black.opacity(0.10), radius: 3, x: 0, y: 2)
            .offset(x: -12, y: -62)
        }
        .frame(width: 140, height: 128)
    }

    private func sparkle(size: CGFloat) -> some View {
        Image(systemName: "sparkle")
            .font(.system(size: size))
            .foregroundColor(.appGreen.opacity(0.35))
    }

    // MARK: - Your Finance, Your Control

    private var financeControlCard: some View {
        HStack(alignment: .top, spacing: 14) {
            TintedIconCircle(color: .appGreen, size: 46, cornerRadius: 15) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 19, weight: .semibold))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Your Finance, Your Control")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text("PiggyFlow helps you take control of your money with smart tracking, AI-powered insights and beautiful reports.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .groupedCard(cornerRadius: 20)
    }

    // MARK: - What's Inside

    private var whatsInsideCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("What's Inside")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 10)

            ForEach(Array(highlights.enumerated()), id: \.element.id) { index, item in
                highlightDestination(for: item)

                if index < highlights.count - 1 {
                    RowDivider(leadingInset: 68)
                }
            }
            .padding(.bottom, 4)
        }
        .groupedCard(cornerRadius: 20)
    }

    @ViewBuilder
    private func highlightDestination(for item: Highlight) -> some View {
        switch item.kind {
        case .scanner:
            NavigationLink(destination: ScanView().hidesTabBarOnPush()) { highlightRow(item) }
                .buttonStyle(.plain)
        case .reports:
            NavigationLink(destination: ReportsView().hidesTabBarOnPush()) { highlightRow(item) }
                .buttonStyle(.plain)
        case .budgets:
            NavigationLink(destination: BudgetGoalsView().hidesTabBarOnPush()) { highlightRow(item) }
                .buttonStyle(.plain)
        case .cloudSync:
            NavigationLink(destination: CloudSyncView().hidesTabBarOnPush()) { highlightRow(item) }
                .buttonStyle(.plain)
        }
    }

    private func highlightRow(_ item: Highlight) -> some View {
        HStack(spacing: 14) {
            TintedIconCircle(color: item.tint, size: 42, cornerRadius: 13) {
                Image(systemName: item.icon)
                    .font(.system(size: 17, weight: .semibold))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 14.5, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text(item.subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    // MARK: - Built with love

    private var builtWithLoveCard: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Text("Built with")
                    Text("❤️")
                    Text("for better financial habits")
                }
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

                Text("We're on a mission to make personal finance simple, clear and empowering for everyone.")
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            growthIllustration
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .groupedCard(cornerRadius: 20)
    }

    private var growthIllustration: some View {
        ZStack(alignment: .bottomTrailing) {
            HStack(alignment: .bottom, spacing: 5) {
                growthBar(height: 20, color: Color.appGreen.opacity(0.35))
                growthBar(height: 32, color: Color.appGreen.opacity(0.6))
                growthBar(height: 46, color: Color.appGreen)
            }

            Image(systemName: "arrow.up.right")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.appGreenDeep)
                .padding(5)
                .background(Circle().fill(Color.appSurface))
                .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 2)
                .offset(x: 8, y: -40)
        }
        .frame(width: 64, height: 54, alignment: .bottom)
    }

    private func growthBar(height: CGFloat, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(color)
            .frame(width: 13, height: height)
    }

    // MARK: - Links

    private var aboutLinksSection: some View {
        VStack(spacing: 10) {
            linkRow(icon: "gift.fill", tint: .appIndigo, title: "What's New") {
                Haptics.light()
                showWhatsNew = true
            }
            linkRow(icon: "star.fill", tint: .appWarningAmber, title: "Rate PiggyFlow") {
                requestReview()
            }
            linkRow(icon: "checkmark.shield.fill", tint: .appGreen, title: "Privacy Policy") {
                Haptics.light()
                showPrivacyPolicy = true
            }
            linkRow(icon: "doc.text.fill", tint: .blue, title: "Terms of Service") {
                Haptics.light()
                showTermsOfService = true
            }
        }
    }

    private func linkRow(icon: String, tint: Color, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                TintedIconCircle(color: tint, size: 38, cornerRadius: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 14.5, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(14)
            .groupedCard(cornerRadius: 16)
        }
        .buttonStyle(.plain)
    }

    private func requestReview() {
        Haptics.light()
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else { return }
        AppStore.requestReview(in: scene)
    }

    // MARK: - Footer

    private var footerText: some View {
        VStack(spacing: 2) {
            Text("© \(copyrightYear) PiggyFlow")
            Text("All rights reserved.")
        }
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundColor(.secondary)
        .padding(.top, 6)
    }
}

// MARK: - What's New

private struct WhatsNewSheet: View {
    @Environment(\.dismiss) private var dismiss

    private struct Entry: Identifiable {
        let id = UUID()
        let version: String
        let title: String
        let notes: [String]
    }

    private let entries: [Entry] = [
        Entry(version: "2.0.0", title: "Whole App Redesign", notes: [
            "A refreshed look across every screen, built on one consistent design system.",
            "Real spending insights on transaction details, computed from your own data.",
            "Bill scanning now keeps the receipt image, viewable from the transaction later."
        ]),
        Entry(version: "1.x", title: "Major Update", notes: [
            "Cloud sync, budgets & goals, and recurring payment tracking."
        ])
    ]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(entries) { entry in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Text("Version \(entry.version)")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(.appGreenDeep)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.appGreen.opacity(0.12))
                                    .clipShape(Capsule())
                                Text(entry.title)
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                            }

                            ForEach(entry.notes, id: \.self) { note in
                                HStack(alignment: .top, spacing: 8) {
                                    Circle()
                                        .fill(Color.appGreen)
                                        .frame(width: 5, height: 5)
                                        .padding(.top, 6)
                                    Text(note)
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .groupedCard(cornerRadius: 18)
                    }
                }
                .padding(16)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("What's New")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.appGreen)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Legal placeholder

/// Privacy Policy / Terms of Service have no real published document yet — this says so
/// plainly instead of a broken link or invented legal text.
private struct LegalPlaceholderSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let icon: String

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                Spacer()
                TintedIconCircle(color: .appGreen, size: 64, cornerRadius: 20) {
                    Image(systemName: icon)
                        .font(.system(size: 26, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text("This document isn't published yet. Check back in a future update.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Spacer()
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.appGreen)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}

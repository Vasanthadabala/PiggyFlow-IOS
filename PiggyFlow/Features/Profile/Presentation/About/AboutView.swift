import SwiftUI

struct AboutView: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private let highlights: [(icon: String, title: String, subtitle: String)] = [
        ("arrow.triangle.2.circlepath", "Realtime Sync", "Syncs expense, income, and tracker data with Firebase."),
        ("chart.xyaxis.line", "Insightful Stats", "Track spending and income trends with clean visual insights."),
        ("bell.badge", "Smart Reminders", "Stay on top of recurring payments and due dates.")
    ]

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    heroSection
                    infoSection
                    highlightsSection
                    footerSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Image("onboarding_image")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Spacer()

                Text("v\(appVersion)")
                    .tintedPillOnHero()
            }

            Text("PiggyFlow")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("Track. Plan. Grow.")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.9))

            Text("A clean finance companion to manage daily expenses, income, and subscriptions with confidence.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .gradientHero([.appGreen, .appGreenDeep])
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("APP INFO")
                .sectionEyebrow()

            infoRow(label: "Developer", value: "Vasanth Adabala")
            infoRow(label: "Platform", value: "iOS")
            infoRow(label: "Version", value: "\(appVersion)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .groupedCard()
    }

    private var highlightsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("WHAT YOU GET")
                .sectionEyebrow()

            ForEach(highlights, id: \.title) { item in
                HStack(alignment: .top, spacing: 12) {
                    TintedIconCircle(color: .appGreen, size: 36) {
                        Image(systemName: item.icon)
                            .font(.system(size: 14, weight: .bold))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Text(item.subtitle)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()
                }
                .padding(.vertical, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .groupedCard()
    }

    private var footerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SUPPORT")
                .sectionEyebrow()
            Text("Thanks for using PiggyFlow. Keep tracking consistently, small habits create big financial results.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Copyright © 2026 Vasanth")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .groupedCard()
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
                .frame(width: 90, alignment: .leading)

            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}

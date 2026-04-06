import SwiftUI

struct AboutView: View {
    @Environment(\.colorScheme) private var colorScheme
    
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
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                heroCard
                infoCard
                highlightsCard
                footerCard
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Image("onboarding_image")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Spacer()

                Text("v\(appVersion)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.white.opacity(0.18)))
            }

            Text("PiggyFlow")
                .font(.system(size: 42, weight: .bold))
                .foregroundColor(.white)

            Text("Track. Plan. Grow.")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white.opacity(0.86))

            Text("A clean finance companion to manage daily expenses, income, and subscriptions with confidence.")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: colorScheme == .dark
                        ? [Color.gray.opacity(0.15), Color.gray.opacity(0.1)]
                        : [Color.black, Color.black.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("App Info")
                .font(.system(size: 24, weight: .semibold))

            infoRow(label: "Developer", value: "Vasanth Adabala")
            infoRow(label: "Platform", value: "iOS")
            infoRow(label: "Version", value: "\(appVersion)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.gray.opacity(0.12))
        )
    }

    private var highlightsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What You Get")
                .font(.system(size: 24, weight: .semibold))

            ForEach(highlights, id: \.title) { item in
                HStack(alignment: .top, spacing: 12) {
                    Circle()
                        .fill(Color.green.opacity(0.16))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: item.icon)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.green)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.system(size: 18, weight: .bold))
                        Text(item.subtitle)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()
                }
                .padding(.vertical, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.gray.opacity(0.1))
        )
    }

    private var footerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Support")
                .font(.system(size: 24, weight: .bold))
            Text("Thanks for using PiggyFlow. Keep tracking consistently, small habits create big financial results.")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
                .fixedSize(horizontal: false, vertical: true)

            Divider()
                .padding(.vertical, 2)

            Text("Copyright © 2026 Vasanth")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.gray.opacity(0.1))
        )
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.gray)
                .frame(width: 90, alignment: .leading)

            Text(value)
                .font(.system(size: 16, weight: .bold))
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

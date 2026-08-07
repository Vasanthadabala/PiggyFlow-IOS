import SwiftUI

/// The header that full-screen forms and detail screens wear: a circular back button, a
/// title/subtitle stack, and an optional tinted action at the trailing edge.
///
/// Defined once because the screens had drifted apart — back arrows in two colours and two
/// sizes, subtitles that truncated on one screen and wrapped to two lines on the next, and
/// action labels a point or two off on each. Callers supply copy and an action, nothing else.
struct ScreenHeader<Trailing: View>: View {
    var title: String
    var subtitle: String
    var onBack: () -> Void
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            BackButton(action: onBack)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                // One line everywhere, so every screen's header is the same height and the
                // content below it starts at the same place as you move between them.
                Text(subtitle)
                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            Spacer(minLength: 8)

            trailing
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 12)
        .background(Color.appBackground)
    }
}

/// The circular back button used at the leading edge of every screen: a white circle,
/// `appGreenDeep` chevron, soft neutral shadow. Defined once so it can't drift — screens had
/// accumulated it in several sizes (36–42pt) and colours (`.primary`, `.appGreenDeep`), plus
/// one holdover using `arrow.left` instead of `chevron.left`.
struct BackButton: View {
    var action: () -> Void

    var body: some View {
        Button {
            Haptics.light()
            action()
        } label: {
            Image(systemName: AppIcon.Nav.back)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.appGreenDeep)
                .frame(width: 40, height: 40)
                .background(Color.appSurface)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

extension ScreenHeader where Trailing == EmptyView {
    init(title: String, subtitle: String, onBack: @escaping () -> Void) {
        self.init(title: title, subtitle: subtitle, onBack: onBack) { EmptyView() }
    }
}

/// The icon-and-text action that sits at a `ScreenHeader`'s trailing edge.
struct ScreenHeaderAction: View {
    var icon: String
    var title: String
    var tint: Color = .appGreen
    var action: () -> Void

    var body: some View {
        Button {
            Haptics.light()
            action()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))

                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .fixedSize()
            }
            .foregroundColor(tint)
        }
        .buttonStyle(.plain)
    }
}

import SwiftUI

/// Elevation scale. Depth comes from soft neutral shadows only — never coloured glows,
/// never hairline borders. A tinted shadow reads as a light source the rest of the UI
/// doesn't have, which is what makes an interface look "shiny" rather than considered.
enum Elevation {
    /// Controls resting just off the canvas — search fields, filter chips.
    static let low = (color: Color.black.opacity(0.05), radius: 8.0, y: 3.0)
    /// Cards and grouped containers.
    static let medium = (color: Color.black.opacity(0.07), radius: 14.0, y: 6.0)
    /// The hero surface and floating elements (FAB, tab bar).
    static let high = (color: Color.black.opacity(0.10), radius: 20.0, y: 10.0)
}

extension View {
    fileprivate func elevation(_ level: (color: Color, radius: Double, y: Double)) -> some View {
        shadow(color: level.color, radius: level.radius, x: 0, y: level.y)
    }
}

/// Bold gradient surface reserved for the one "hero" number per screen (balance, estimate, summary).
struct GradientHeroStyle: ViewModifier {
    var colors: [Color]
    var cornerRadius: CGFloat = 28

    func body(content: Content) -> some View {
        content
            .background(
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .elevation(Elevation.high)
    }
}

/// Elevated surface card — the default container for grouped content and lists.
struct GroupedCardStyle: ViewModifier {
    var cornerRadius: CGFloat = 22

    func body(content: Content) -> some View {
        content
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .elevation(Elevation.medium)
    }
}

// MARK: - Surface modifiers

extension View {
    /// The one bold, saturated surface per screen. Reserve it for the primary figure.
    func gradientHero(_ colors: [Color], cornerRadius: CGFloat = 28) -> some View {
        modifier(GradientHeroStyle(colors: colors, cornerRadius: cornerRadius))
    }

    /// Elevated card container for a group of rows or a distinct module.
    func groupedCard(cornerRadius: CGFloat = 22) -> some View {
        modifier(GroupedCardStyle(cornerRadius: cornerRadius))
    }

    /// Flat row content inside a `groupedCard`: no fill/border/shadow of its own —
    /// separation comes from `RowDivider`.
    func flatRow(vertical: CGFloat = 14, horizontal: CGFloat = 16) -> some View {
        padding(.vertical, vertical).padding(.horizontal, horizontal)
    }

    /// Surface with a soft shadow and no fill tint — for controls that sit outside a card
    /// (search fields, filter chips).
    func liftedControl(cornerRadius: CGFloat = 16) -> some View {
        background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .elevation(Elevation.low)
    }

    /// Solid, full-width primary action. One per screen.
    ///
    /// `tint` carries meaning — green to proceed, red to destroy. The shadow stays neutral
    /// regardless, so the button reads as raised rather than glowing.
    func primaryButton(tint: Color = .appGreen, enabled: Bool = true, cornerRadius: CGFloat = 16) -> some View {
        frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .foregroundColor(.white)
            .background(enabled ? tint : Color.primary.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .elevation(enabled ? Elevation.low : (color: .clear, radius: 0, y: 0))
    }

    /// Quiet secondary action — pairs with `primaryButton` without competing with it.
    func secondaryButton(tint: Color = .primary, cornerRadius: CGFloat = 16) -> some View {
        frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .foregroundColor(tint)
            .background(tint.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    /// Circular floating action button.
    func floatingActionButton(tint: Color = .appGreen) -> some View {
        foregroundColor(.white)
            .padding(19)
            .background(tint)
            .clipShape(Circle())
            .elevation(Elevation.high)
    }
}

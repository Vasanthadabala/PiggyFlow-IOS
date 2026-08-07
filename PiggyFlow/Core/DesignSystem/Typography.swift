import SwiftUI

/// Typographic roles. The app uses `.rounded` throughout — these keep weight,
/// size and tracking consistent so screens don't drift apart over time.
extension View {
    /// Small tracked, bold, uppercase label above hero numbers and section groups
    /// ("OVERVIEW", "ACCOUNT", "MONTHLY SUMMARY").
    func sectionEyebrow(color: Color = .secondary) -> some View {
        font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundColor(color)
            .tracking(1.0)
    }

    /// Page/section title — sits above a grouped card.
    func sectionHeader() -> some View {
        font(.system(size: 20, weight: .bold, design: .rounded))
            .foregroundColor(.primary)
    }

    /// Tinted capsule badge — accent-coloured text on a low-opacity accent fill.
    func tintedPill(color: Color) -> some View {
        font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(color.opacity(0.12)))
    }

    /// Capsule badge for use *on* a gradient hero — white text on translucent white.
    func tintedPillOnHero() -> some View {
        font(.system(size: 11.5, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.white.opacity(0.18)))
    }
}

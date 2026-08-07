import SwiftUI

/// Tinted icon tile — accent-coloured content on a low-opacity accent fill.
///
/// A `nil` `cornerRadius` renders a circle (used for avatars); a finite value renders a
/// rounded square (used for list-row and stat icons).
struct TintedIconCircle<Content: View>: View {
    var color: Color
    var size: CGFloat = 44
    var cornerRadius: CGFloat? = nil
    @ViewBuilder var content: Content

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius ?? size / 2, style: .continuous)
            .fill(color.opacity(0.12))
            .frame(width: size, height: size)
            .overlay(content.foregroundColor(color))
    }
}

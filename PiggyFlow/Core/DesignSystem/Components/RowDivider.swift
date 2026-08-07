import SwiftUI

/// Hairline separator between flat rows inside a `groupedCard`.
struct RowDivider: View {
    var leadingInset: CGFloat = 0

    var body: some View {
        Divider()
            .overlay(Color.primary.opacity(0.08))
            .padding(.leading, leadingInset)
    }
}

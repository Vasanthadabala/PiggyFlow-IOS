import SwiftUI

/// The rounded-square icon tile shown for a bill/subscription/EMI tracker — a handful of
/// well-known names get a recognisable brand-style tile, everything else falls back to a
/// plain initial. Shared by the Upcoming Payments list and its detail screen so a tracker
/// looks the same wherever it appears.
struct TrackerAvatar: View {
    let record: TrackerRecord
    var size: CGFloat = 46

    var body: some View {
        let nameLower = record.name.lowercased()

        Group {
            if nameLower.contains("netflix") {
                tile(bg: .black) {
                    Text("N")
                        .font(.system(size: size * 0.43, weight: .black, design: .rounded))
                        .foregroundColor(.red)
                }
            } else if nameLower.contains("spotify") {
                tile(bg: .black) {
                    Image(systemName: "waveform")
                        .font(.system(size: size * 0.43, weight: .bold))
                        .foregroundColor(Color(red: 30/255, green: 215/255, blue: 96/255))
                }
            } else if nameLower.contains("amazon") {
                tile(bg: Color(red: 255/255, green: 153/255, blue: 0/255)) {
                    Text("prime")
                        .font(.system(size: size * 0.22, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                }
            } else if nameLower.contains("mobile") || nameLower.contains("phone") {
                tile(bg: Color(red: 30/255, green: 64/255, blue: 175/255)) {
                    Image(systemName: "phone.fill")
                        .font(.system(size: size * 0.43, weight: .bold))
                        .foregroundColor(.white)
                }
            } else if nameLower.contains("electricity") {
                tile(bg: Color(red: 217/255, green: 119/255, blue: 6/255)) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: size * 0.43, weight: .bold))
                        .foregroundColor(.white)
                }
            } else if nameLower.contains("loan") || nameLower.contains("emi") || record.type.lowercased() == "emi" {
                tile(bg: Color.appGreen.opacity(0.15)) {
                    Image(systemName: "building.columns.fill")
                        .font(.system(size: size * 0.43, weight: .bold))
                        .foregroundColor(Color.appGreen)
                }
            } else if nameLower.contains("gas") {
                tile(bg: Color.orange.opacity(0.15)) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: size * 0.43, weight: .bold))
                        .foregroundColor(.orange)
                }
            } else if nameLower.contains("internet") {
                tile(bg: Color.blue.opacity(0.15)) {
                    Image(systemName: "wifi")
                        .font(.system(size: size * 0.43, weight: .bold))
                        .foregroundColor(.blue)
                }
            } else if nameLower.contains("swiggy") {
                tile(bg: .orange) {
                    Image(systemName: "bag.fill")
                        .font(.system(size: size * 0.43, weight: .bold))
                        .foregroundColor(.white)
                }
            } else {
                tile(bg: Color.appGreen.opacity(0.12)) {
                    Text(String(record.name.prefix(1)).uppercased())
                        .font(.system(size: size * 0.39, weight: .bold, design: .rounded))
                        .foregroundColor(Color.appGreen)
                }
            }
        }
    }

    @ViewBuilder
    private func tile<Content: View>(bg: Color, @ViewBuilder content: () -> Content) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous).fill(bg)
            content()
        }
        .frame(width: size, height: size)
    }
}

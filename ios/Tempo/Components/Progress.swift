import SwiftUI

/// Thin progress bar — 6px tall pill with a colored fill.
struct ProgressStrip: View {
    var value: Double             // 0...1
    var color: Color = Theme.Color.fg
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.Color.bgElev2)
                Capsule()
                    .fill(color)
                    .frame(width: max(0, min(1, value)) * geo.size.width)
                    .animation(.easeOut(duration: 0.3), value: value)
            }
        }
        .frame(height: height)
        .clipShape(Capsule())
    }
}

/// Dual progress strip rows (You + partner) shown at top of Active Session and in Today state B.
struct DualProgress: View {
    var youPct: Double          // 0...100
    var partnerPct: Double
    /// Caller-provided name for the "you" side. Falls back to "You".
    var youName: String = "You"
    /// Caller-provided name for the partner side. Falls back to a generic
    /// "Partner" label so the component never accidentally hard-codes a real name.
    var partnerName: String = "Partner"
    var youMeta: String? = nil
    var partnerMeta: String? = nil

    var body: some View {
        VStack(spacing: 14) {
            row(name: youName,
                pct: youPct,
                color: Theme.Color.you,
                meta: youMeta ?? "\(Int(youPct))%")

            row(name: partnerName,
                pct: partnerPct,
                color: Theme.Color.partner,
                meta: partnerMeta ?? "\(Int(partnerPct))%")
        }
    }

    private func row(name: String, pct: Double, color: Color, meta: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(name).labelStyle(color: color)
                Spacer()
                Text(meta).monoNumeric(11).foregroundColor(Theme.Color.fgSoft)
            }
            ProgressStrip(value: pct / 100, color: color)
        }
    }
}

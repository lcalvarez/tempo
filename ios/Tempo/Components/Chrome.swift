import SwiftUI

/// Tempo wordmark: two overlapping rings (you/partner) + the word "Tempo".
/// Used in onboarding hero and as a small persistent mark above the tab bar.
struct BrandMark: View {
    enum Size { case compact, medium, large }
    var size: Size = .medium
    /// When false, just the rings render (useful for icon-only contexts).
    var showWord: Bool = true

    var body: some View {
        HStack(spacing: spacing) {
            ZStack {
                Circle().strokeBorder(Theme.Color.you,     lineWidth: ringWidth)
                    .frame(width: ringSize, height: ringSize).offset(x: -ringSize * 0.22)
                Circle().strokeBorder(Theme.Color.partner, lineWidth: ringWidth)
                    .frame(width: ringSize, height: ringSize).offset(x:  ringSize * 0.22)
            }
            .frame(width: ringSize * 1.5, height: ringSize * 1.2)

            if showWord {
                Text("Tempo")
                    .font(.system(size: wordSize, weight: .semibold))
                    .foregroundColor(Theme.Color.fg)
                    .kerning(-0.2)
            }
        }
        .accessibilityLabel("Tempo")
    }

    private var ringSize: CGFloat {
        switch size { case .compact: return 12; case .medium: return 18; case .large: return 24 }
    }
    private var ringWidth: CGFloat {
        switch size { case .compact: return 1.6; case .medium: return 2.2; case .large: return 2.6 }
    }
    private var wordSize: CGFloat {
        switch size { case .compact: return 12; case .medium: return 17; case .large: return 22 }
    }
    private var spacing: CGFloat {
        switch size { case .compact: return 6; case .medium: return 10; case .large: return 12 }
    }
}

/// Standard top bar: page-overline left, partner pip right.
struct TopBar: View {
    var title: String
    var dateLine: String? = "Tue · May 14"
    var trailing: AnyView? = nil

    var body: some View {
        HStack(spacing: 8) {
            Text(title.uppercased())
                .font(Theme.Font.mono(11, .medium))
                .tracking(0.9)
                .foregroundColor(Theme.Color.fg)

            if let dateLine {
                Text("·").overlineStyle(color: Theme.Color.fgFaint)
                Text(dateLine.uppercased())
                    .font(Theme.Font.mono(11, .medium))
                    .tracking(0.9)
                    .foregroundColor(Theme.Color.fgSoft)
                    .monospacedDigit()
            }

            Spacer()

            if let trailing { trailing }
        }
        .padding(.horizontal, 20)
        .frame(height: 36)
    }
}

/// Section header — "Top lifts · Tap for chart" style row.
struct SectionHead: View {
    var title: String
    var meta: String? = nil
    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(Theme.Font.mono(11, .medium))
                .tracking(0.9)
                .foregroundColor(Theme.Color.fg)
            Spacer()
            if let meta {
                Text(meta)
                    .font(Theme.Font.mono(10.5, .medium))
                    .foregroundColor(Theme.Color.fgSoft)
            }
        }
    }
}

/// Global toast overlay — reads `SessionStore.toast` and renders a transient
/// pill near the top. Hit-testing is disabled at the call site so taps fall
/// through to whatever's underneath.
struct ToastOverlay: View {
    @EnvironmentObject var store: SessionStore

    var body: some View {
        VStack {
            if let t = store.toast {
                HStack(spacing: 10) {
                    Image(systemName: t.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.Color.accent)
                    Text(t.message)
                        .font(Theme.Font.sans(13, .medium))
                        .foregroundColor(Theme.Color.fg)
                        .lineLimit(2)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Theme.Color.bgElev2)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Theme.Color.hairline, lineWidth: 1))
                .shadow(color: .black.opacity(0.3), radius: 16, y: 8)
                .padding(.top, 60)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: store.toast)
    }
}

/// KPI block: big numeric value + uppercase unit label.
struct KPI: View {
    var value: String
    var unit: String
    var valueSize: CGFloat = 28
    /// Horizontal alignment of the value/unit stack within its container.
    /// Defaults to `.leading` to preserve existing call sites; pass
    /// `.center` when used inside `KPIRow` so each cell balances visually.
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: alignment, spacing: 6) {
            Text(value)
                .font(.system(size: valueSize, weight: .semibold).monospacedDigit())
                .kerning(-0.7)
                .foregroundColor(Theme.Color.fg)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(unit.uppercased())
                .font(Theme.Font.mono(10.5, .medium))
                .tracking(1.05)
                .foregroundColor(Theme.Color.fgSoft)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: textAlignment)
    }

    /// Map the stack alignment to the corresponding frame alignment so the
    /// containing `maxWidth: .infinity` block knows where to anchor the
    /// stack inside its allotted column.
    private var textAlignment: Alignment {
        switch alignment {
        case .leading:  return .leading
        case .trailing: return .trailing
        default:        return .center
        }
    }
}

/// Equal-width KPI row with hairline separators between cells. Matches the
/// visual language used in the History tab's all-time strip and balances
/// the values across the card regardless of how wide each KPI's value text
/// happens to be (e.g. `12h 32m` vs `5`).
struct KPIRow: View {
    var items: [(value: String, unit: String)]
    var valueSize: CGFloat = 28

    init(_ items: [(value: String, unit: String)], valueSize: CGFloat = 28) {
        self.items = items
        self.valueSize = valueSize
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                KPI(value: item.value,
                    unit: item.unit,
                    valueSize: valueSize,
                    alignment: .center)
                if idx < items.count - 1 {
                    Rectangle()
                        .fill(Theme.Color.hairline)
                        .frame(width: 1, height: 30)
                }
            }
        }
    }
}

import SwiftUI

enum AvatarTone {
    case partner
    case you
    case neutral
    case accent
}

struct Avatar: View {
    var initial: String
    var size: CGFloat = 24
    var tone: AvatarTone = .partner
    var showDot: Bool = false
    var online: Bool = true

    private var bg: Color {
        switch tone {
        case .partner: return Theme.Color.partnerDim
        case .you:     return Theme.Color.youDim
        case .neutral: return Theme.Color.bgElev2
        case .accent:  return Theme.Color.accentDim
        }
    }
    private var fg: Color {
        switch tone {
        case .partner: return Theme.Color.partner
        case .you:     return Theme.Color.you
        case .neutral: return Theme.Color.fg
        case .accent:  return Theme.Color.accent
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                Circle().fill(bg)
                Text(initial)
                    .font(.system(size: max(9, size * 0.45), weight: .semibold))
                    .foregroundColor(fg)
            }
            .frame(width: size, height: size)

            if showDot {
                Circle()
                    .fill(online ? Theme.Color.accent : Theme.Color.fgFaint)
                    .frame(width: max(7, size * 0.32), height: max(7, size * 0.32))
                    .overlay(
                        Circle().strokeBorder(Theme.Color.bgElev1, lineWidth: 2)
                    )
                    .offset(x: 1, y: 1)
            }
        }
    }
}

// Partner pip — used in top bars
struct PartnerPip: View {
    var partner: Partner
    var body: some View {
        HStack(spacing: 8) {
            Avatar(initial: partner.initial, size: 24, tone: .partner, showDot: true, online: partner.online)
            Text(partner.name)
                .font(Theme.Font.sans(12, .medium))
                .foregroundColor(Theme.Color.fgMute)
                .padding(.trailing, 10)
        }
        .padding(.leading, 5)
        .padding(.vertical, 5)
        .background(Theme.Color.bgElev1)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Theme.Color.hairline, lineWidth: 1))
    }
}

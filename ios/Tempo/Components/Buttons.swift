import SwiftUI

// MARK: - Primary CTA — the green button
struct PrimaryCTA: View {
    var title: String
    var trailingSystemImage: String?
    var tall: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .font(Theme.Font.sans(17, .semibold))
                    .kerning(-0.17)
                    .foregroundColor(Theme.Color.accentInk)

                if trailingSystemImage != nil {
                    Spacer(minLength: 8)
                    Image(systemName: trailingSystemImage!)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.Color.accentInk)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: tall ? 64 : 58)
            .padding(.horizontal, 22)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.Radius.md)
                        .fill(Theme.Color.accent)
                    RoundedRectangle(cornerRadius: Theme.Radius.md)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        .blendMode(.overlay)
                }
            )
            .shadow(color: Theme.Color.accent.opacity(0.28), radius: 14, y: 8)
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - Secondary CTA
struct SecondaryCTA: View {
    var title: String
    var leadingSystemImage: String?
    var height: CGFloat = 50
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let img = leadingSystemImage {
                    Image(systemName: img).font(.system(size: 14, weight: .medium))
                }
                Text(title).font(Theme.Font.sans(15, .medium))
            }
            .foregroundColor(Theme.Color.fg)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(Theme.Color.bgElev2)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .strokeBorder(Theme.Color.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - Press feedback
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Circular icon button (used in topbars)
struct IconButton: View {
    var systemName: String
    var size: CGFloat = 36
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.Color.fgMute)
                .frame(width: size, height: size)
                .background(Theme.Color.bgElev1)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(Theme.Color.hairline, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - Tertiary inline link
struct LinkButton: View {
    var title: String
    var color: Color = Theme.Color.fgMute
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Font.sans(14, .medium))
                .foregroundColor(color)
        }
    }
}

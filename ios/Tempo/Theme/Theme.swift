import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Design tokens lifted from `source_designs/tokens.css`.
///
/// Every `Color` is dynamic: it resolves to one of two sRGB triples depending
/// on the active `UIUserInterfaceStyle`. The dark values match the original
/// design exactly; the light values were derived to keep the same contrast
/// hierarchy (depth, mute levels, accent saturation) on a near-white surface.
///
/// Callsites stay identical (`Theme.Color.bg`) so the rest of the app didn't
/// need to change when light mode was added.
enum Theme {
    enum Color {
        // MARK: Surfaces

        static let bg       = dyn(dark: (0.078, 0.082, 0.092),
                                  light: (0.969, 0.973, 0.980))
        static let bgElev1  = dyn(dark: (0.114, 0.118, 0.131),
                                  light: (1.000, 1.000, 1.000))
        static let bgElev2  = dyn(dark: (0.162, 0.169, 0.185),
                                  light: (0.933, 0.941, 0.953))
        static let bgElev3  = dyn(dark: (0.213, 0.220, 0.239),
                                  light: (0.890, 0.898, 0.918))
        static let border   = dyn(dark:  (0.235, 0.243, 0.262, 0.6),
                                  light: (0.000, 0.000, 0.000, 0.10))
        static let hairline = dyn(dark:  (1.000, 1.000, 1.000, 0.06),
                                  light: (0.000, 0.000, 0.000, 0.08))

        // MARK: Text

        static let fg      = dyn(dark: (0.965, 0.965, 0.970),
                                 light: (0.094, 0.098, 0.114))
        static let fgMute  = dyn(dark: (0.690, 0.700, 0.720),
                                 light: (0.318, 0.329, 0.357))
        static let fgSoft  = dyn(dark: (0.475, 0.485, 0.508),
                                 light: (0.471, 0.486, 0.514))
        static let fgFaint = dyn(dark: (0.330, 0.340, 0.365),
                                 light: (0.612, 0.624, 0.651))

        // MARK: Accent (fresh green) — slightly deeper for light mode contrast

        static let accent     = dyn(dark: (0.471, 0.851, 0.494),
                                    light: (0.247, 0.659, 0.298))
        static let accentInk  = dyn(dark: (0.043, 0.200, 0.063),
                                    light: (0.043, 0.200, 0.063))
        static let accentDim  = accent.opacity(0.14)
        static let accentRing = accent.opacity(0.35)

        // MARK: Partner tones (you = blue, partner = amber)

        static let you        = dyn(dark: (0.494, 0.722, 0.920),
                                    light: (0.176, 0.482, 0.749))
        static let youDim     = you.opacity(0.16)
        static let partner    = dyn(dark: (0.940, 0.780, 0.470),
                                    light: (0.741, 0.518, 0.184))
        static let partnerDim = partner.opacity(0.16)

        // MARK: PR / celebratory gold

        static let pr        = dyn(dark: (0.965, 0.810, 0.350),
                                   light: (0.741, 0.561, 0.067))
        static let prDim     = pr.opacity(0.16)

        // MARK: Destructive

        static let danger     = dyn(dark: (0.780, 0.300, 0.220),
                                    light: (0.780, 0.220, 0.180))
        static let dangerSoft = dyn(dark: (0.850, 0.450, 0.400),
                                    light: (0.700, 0.290, 0.230))
    }

    enum Radius {
        static let xs: CGFloat = 6
        static let sm: CGFloat = 10
        static let md: CGFloat = 14
        static let lg: CGFloat = 20
        static let xl: CGFloat = 28
        static let pill: CGFloat = 999
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
    }

    /// Geist isn't bundled — fall back to system fonts that retain the design language.
    /// Numeric type uses `monospacedDigit()` everywhere mono is implied.
    enum Font {
        static func sans(_ size: CGFloat, _ weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
            .system(size: size, weight: weight, design: .default)
        }

        static func mono(_ size: CGFloat, _ weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
            .system(size: size, weight: weight, design: .monospaced)
        }

        static func display(_ size: CGFloat, _ weight: SwiftUI.Font.Weight = .semibold) -> SwiftUI.Font {
            .system(size: size, weight: weight, design: .default)
        }
    }
}

// MARK: - Dynamic color helpers

/// Triple-component shorthand for `dyn(...)` callsites.
private typealias RGB = (r: Double, g: Double, b: Double)
private typealias RGBA = (r: Double, g: Double, b: Double, a: Double)

/// Build a `SwiftUI.Color` that picks a different sRGB value depending on
/// the active `UIUserInterfaceStyle`. Falls back to the dark palette on
/// platforms without UIKit.
private func dyn(dark: RGB, light: RGB) -> SwiftUI.Color {
    dyn(dark: (dark.r, dark.g, dark.b, 1.0), light: (light.r, light.g, light.b, 1.0))
}

private func dyn(dark: RGBA, light: RGBA) -> SwiftUI.Color {
    #if canImport(UIKit)
    let ui = UIColor { trait in
        let isDark = trait.userInterfaceStyle == .dark
        let v = isDark ? dark : light
        return UIColor(red: v.r, green: v.g, blue: v.b, alpha: v.a)
    }
    return SwiftUI.Color(ui)
    #else
    return SwiftUI.Color(red: dark.r, green: dark.g, blue: dark.b, opacity: dark.a)
    #endif
}

// MARK: - Reusable text styles

extension View {
    /// Mono uppercase label with letter-spacing. Used in section heads, KPI units, "OVERLINE" copy.
    func overlineStyle(color: Color = Theme.Color.fgSoft) -> some View {
        self.font(Theme.Font.mono(11, .medium))
            .tracking(0.9)           // ~ 0.08em at 11px
            .textCase(.uppercase)
            .foregroundColor(color)
    }

    func labelStyle(color: Color = Theme.Color.fgSoft) -> some View {
        self.font(Theme.Font.mono(10.5, .medium))
            .tracking(1.05)
            .textCase(.uppercase)
            .foregroundColor(color)
    }

    func monoNumeric(_ size: CGFloat, _ weight: SwiftUI.Font.Weight = .regular) -> some View {
        self.font(.system(size: size, weight: weight, design: .monospaced).monospacedDigit())
    }
}

// MARK: - Hairline / Card helpers

struct CardStyle: ViewModifier {
    var tight: Bool = false
    var padding: CGFloat?

    func body(content: Content) -> some View {
        content
            .padding(padding ?? (tight ? 16 : 20))
            .background(Theme.Color.bgElev1)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg)
                    .strokeBorder(Theme.Color.hairline, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
    }
}

extension View {
    func card(tight: Bool = false, padding: CGFloat? = nil) -> some View {
        modifier(CardStyle(tight: tight, padding: padding))
    }
}

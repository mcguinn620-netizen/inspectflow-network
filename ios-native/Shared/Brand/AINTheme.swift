import SwiftUI

/// Design tokens for Auto Inspector Network.
/// Mirrors the web Linear/Stripe theme: Deep Navy, Electric Blue, Emerald/Amber/Rose,
/// Inter for body, Roboto Mono for VIN/IDs.
enum AINTheme {

    // MARK: - Colors (semantic)

    enum Color {
        // Brand
        static let primary       = SwiftUI.Color(hex: 0x0F1A33)   // Deep Navy
        static let primaryHover  = SwiftUI.Color(hex: 0x172447)
        static let accent        = SwiftUI.Color(hex: 0x2E82F2)   // Electric Blue
        static let accentHover   = SwiftUI.Color(hex: 0x1E6FDB)

        // Status
        static let pass    = SwiftUI.Color(hex: 0x22B377)   // Emerald
        static let warn    = SwiftUI.Color(hex: 0xF5A82E)   // Amber
        static let fail    = SwiftUI.Color(hex: 0xF25266)   // Rose
        static let neutral = SwiftUI.Color(hex: 0x6B7280)

        // Surfaces (light/dark adaptive)
        static let background     = SwiftUI.Color(light: 0xF7F8FA, dark: 0x0B1020)
        static let surface        = SwiftUI.Color(light: 0xFFFFFF, dark: 0x141A2E)
        static let surfaceElevated = SwiftUI.Color(light: 0xFFFFFF, dark: 0x1B2238)
        static let surfaceMuted   = SwiftUI.Color(light: 0xF1F3F7, dark: 0x1A2138)
        static let border         = SwiftUI.Color(light: 0xE3E6EC, dark: 0x232B45)
        static let divider        = SwiftUI.Color(light: 0xEEF0F4, dark: 0x1F2740)

        // Text
        static let textPrimary    = SwiftUI.Color(light: 0x0B1020, dark: 0xF5F7FB)
        static let textSecondary  = SwiftUI.Color(light: 0x4B5366, dark: 0xA7AEC2)
        static let textTertiary   = SwiftUI.Color(light: 0x8993A6, dark: 0x6B7390)
        static let textOnAccent   = SwiftUI.Color.white
    }

    // MARK: - Spacing (4pt grid)

    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs:  CGFloat = 4
        static let sm:  CGFloat = 8
        static let md:  CGFloat = 12
        static let lg:  CGFloat = 16
        static let xl:  CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // MARK: - Radius

    enum Radius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 10
        static let lg: CGFloat = 14
        static let xl: CGFloat = 20
        static let pill: CGFloat = 999
    }

    // MARK: - Typography

    enum Font {
        static func display(_ size: CGFloat = 28) -> SwiftUI.Font { .system(size: size, weight: .bold, design: .default) }
        static func title(_ size: CGFloat = 22)   -> SwiftUI.Font { .system(size: size, weight: .semibold, design: .default) }
        static func headline(_ size: CGFloat = 17) -> SwiftUI.Font { .system(size: size, weight: .semibold, design: .default) }
        static func body(_ size: CGFloat = 15)    -> SwiftUI.Font { .system(size: size, weight: .regular, design: .default) }
        static func bodyEmphasized(_ size: CGFloat = 15) -> SwiftUI.Font { .system(size: size, weight: .medium, design: .default) }
        static func caption(_ size: CGFloat = 12) -> SwiftUI.Font { .system(size: size, weight: .regular, design: .default) }
        /// Roboto Mono falls back to the system monospaced design.
        static func mono(_ size: CGFloat = 14)    -> SwiftUI.Font { .system(size: size, weight: .medium, design: .monospaced) }
    }

    // MARK: - Shadow

    enum Shadow {
        static let card = ShadowStyle(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
        static let popover = ShadowStyle(color: .black.opacity(0.14), radius: 24, x: 0, y: 12)
    }

    struct ShadowStyle {
        let color: SwiftUI.Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
}

// MARK: - Color helpers

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }

    /// Adaptive color from two hex values (light/dark).
    init(light: UInt32, dark: UInt32) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            let r = CGFloat((hex >> 16) & 0xFF) / 255.0
            let g = CGFloat((hex >> 8) & 0xFF) / 255.0
            let b = CGFloat(hex & 0xFF) / 255.0
            return UIColor(red: r, green: g, blue: b, alpha: 1)
        })
        #else
        self.init(hex: light)
        #endif
    }
}

// MARK: - View modifiers

extension View {
    func ainShadow(_ s: AINTheme.ShadowStyle = AINTheme.Shadow.card) -> some View {
        self.shadow(color: s.color, radius: s.radius, x: s.x, y: s.y)
    }
}

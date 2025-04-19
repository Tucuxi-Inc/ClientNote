import SwiftUI

extension Color {
    // Dynamic primary accents
    static var euniPrimary: Color {
        Color(light: "#A3BFA8", dark: "#88A28C") // Softer green in dark mode
    }

    static var euniSecondary: Color {
        Color(light: "#6C8BA3", dark: "#5A7691") // Muted blue
    }

    // Backgrounds & Fields
    static var euniBackground: Color {
        Color(light: "#FAF8F5", dark: "#1E1E1E") // Soft cream → deep gray
    }

    static var euniFieldBackground: Color {
        Color(light: "#F1F1F0", dark: "#2B2B2B") // Mist gray → graphite
    }

    static var euniBorder: Color {
        Color(light: "#D6CFC7", dark: "#444444") // Taupe → dark divider
    }

    // Text & Status
    static var euniText: Color {
        Color(light: "#2D2D2D", dark: "#F0F0F0") // Charcoal → light gray
    }

    static var euniSuccess: Color {
        Color(light: "#86A68C", dark: "#A5CBB3") // Light green to mint
    }

    static var euniError: Color {
        Color(light: "#C67C7C", dark: "#D88B8B") // Burnt rose → softer red
    }
}

// MARK: - Helper for Light/Dark Adaptive Colors
extension Color {
    init(light: String, dark: String) {
        self = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.name == .darkAqua
                ? NSColor(hex: dark)
                : NSColor(hex: light)
        }))
    }
}

// MARK: - NSColor Hex Conversion Helper
extension NSColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r, g, b: UInt64
        switch hex.count {
        case 6: // RRGGBB
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }

        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: 1
        )
    }
}

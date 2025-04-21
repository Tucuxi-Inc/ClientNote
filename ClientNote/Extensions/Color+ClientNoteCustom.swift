import SwiftUI

extension Color {
    // Dynamic primary accents
    static var euniPrimary: Color {
        Color(hex: "#A3BFA8") // Always use light mode color
    }

    static var euniSecondary: Color {
        Color(hex: "#6C8BA3") // Always use light mode color
    }

    // Backgrounds & Fields
    static var euniBackground: Color {
        Color(hex: "#FAF8F5") // Always use light mode color
    }

    static var euniFieldBackground: Color {
        Color(hex: "#F1F1F0") // Always use light mode color
    }

    static var euniBorder: Color {
        Color(hex: "#D6CFC7") // Always use light mode color
    }

    // Text & Status
    static var euniText: Color {
        Color(hex: "#2D2D2D") // Always use light mode color
    }

    static var euniSuccess: Color {
        Color(hex: "#86A68C") // Always use light mode color
    }

    static var euniError: Color {
        Color(hex: "#C67C7C") // Always use light mode color
    }
}

// MARK: - Helper for Light/Dark Adaptive Colors - No longer used, but kept for reference
extension Color {
    init(light: String, dark: String) {
        // Always use light mode color regardless of system appearance
        self = Color(hex: light)
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

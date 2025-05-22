import SwiftUI

/// Extension providing Euni's custom color scheme
extension Color {
    // MARK: - Brand Colors
    
    /// Primary brand color - Sage Green
    /// - Light: #A3BFA8 (Soft sage)
    /// - Dark: #8AA891 (Deeper sage)
    static var euniPrimary: Color {
        Color(light: "#A3BFA8", dark: "#8AA891")
    }

    /// Secondary brand color - Muted Blue
    /// - Light: #6C8BA3 (Soft blue)
    /// - Dark: #557A94 (Deeper blue)
    static var euniSecondary: Color {
        Color(light: "#6C8BA3", dark: "#557A94")
    }

    // MARK: - Background Colors
    
    /// Main background color
    /// - Light: #FAF8F5 (Off-white)
    /// - Dark: #1F1F1F (Dark gray)
    static var euniBackground: Color {
        Color(light: "#FAF8F5", dark: "#1F1F1F")
    }

    /// Field and control background color
    /// - Light: #F1F1F0 (Light gray)
    /// - Dark: #2D2D2D (Medium dark gray)
    static var euniFieldBackground: Color {
        Color(light: "#F1F1F0", dark: "#2D2D2D")
    }

    /// Border color for UI elements
    /// - Light: #D6CFC7 (Light beige/gray)
    /// - Dark: #3D3D3D (Dark gray)
    static var euniBorder: Color {
        Color(light: "#D6CFC7", dark: "#3D3D3D")
    }

    // MARK: - Text & Status Colors
    
    /// Primary text color
    /// - Light: #2D2D2D (Dark gray)
    /// - Dark: #E5E5E5 (Light gray)
    static var euniText: Color {
        Color(light: "#2D2D2D", dark: "#E5E5E5")
    }

    /// Success state color
    /// - Light: #86A68C (Muted green)
    /// - Dark: #6D8C73 (Darker green)
    static var euniSuccess: Color {
        Color(light: "#86A68C", dark: "#6D8C73")
    }

    /// Error state color
    /// - Light: #C67C7C (Soft red)
    /// - Dark: #A65D5D (Darker red)
    static var euniError: Color {
        Color(light: "#C67C7C", dark: "#A65D5D")
    }
}

// MARK: - Color Scheme Helpers

extension Color {
    /// Initialize a color with separate light and dark mode values
    /// - Parameters:
    ///   - light: Hex color string for light mode
    ///   - dark: Hex color string for dark mode
    init(light: String, dark: String) {
        self.init(hex: NSAppearance.current.isDarkMode ? dark : light)
    }
}

// MARK: - NSAppearance Helper

extension NSAppearance {
    /// Check if the current appearance is dark mode
    var isDarkMode: Bool {
        if self.name == .darkAqua {
            return true
        }
        return false
    }
    
    /// Get the current appearance, defaulting to light if not available
    static var current: NSAppearance {
        NSApp.effectiveAppearance
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

//
//  Spacing+Constants.swift
//  ClientNote
//
//  Created by AI Assistant
//  Centralized spacing and sizing constants for consistent UI layout
//

import SwiftUI

// MARK: - Spacing Constants

extension CGFloat {
    // MARK: Spacing

    /// Extra small spacing (4pt) - Minimal gaps between tightly related elements
    static let spacingXS: CGFloat = 4

    /// Small spacing (8pt) - Compact vertical/horizontal spacing
    static let spacingS: CGFloat = 8

    /// Medium spacing (12pt) - Standard element spacing
    static let spacingM: CGFloat = 12

    /// Large spacing (16pt) - Section spacing, comfortable padding
    static let spacingL: CGFloat = 16

    /// Extra large spacing (20pt) - Major section breaks
    static let spacingXL: CGFloat = 20

    /// Double extra large spacing (24pt) - Page-level spacing
    static let spacingXXL: CGFloat = 24

    /// Triple extra large spacing (32pt) - Major layout divisions
    static let spacingXXXL: CGFloat = 32

    // MARK: Corner Radius

    /// Small corner radius (6pt) - Subtle rounding for small elements
    static let cornerRadiusS: CGFloat = 6

    /// Medium corner radius (8pt) - Standard UI element rounding
    static let cornerRadiusM: CGFloat = 8

    /// Large corner radius (12pt) - Prominent cards and containers
    static let cornerRadiusL: CGFloat = 12

    /// Extra large corner radius (16pt) - Hero elements
    static let cornerRadiusXL: CGFloat = 16

    // MARK: Border Width

    /// Thin border (0.5pt) - Subtle dividers
    static let borderThin: CGFloat = 0.5

    /// Standard border (1pt) - Default border width
    static let borderStandard: CGFloat = 1

    /// Thick border (2pt) - Emphasized borders
    static let borderThick: CGFloat = 2

    // MARK: Icon Sizes

    /// Small icon size (12pt)
    static let iconS: CGFloat = 12

    /// Medium icon size (16pt)
    static let iconM: CGFloat = 16

    /// Large icon size (20pt)
    static let iconL: CGFloat = 20

    /// Extra large icon size (24pt)
    static let iconXL: CGFloat = 24

    // MARK: Layout Dimensions

    /// Minimum sidebar width
    static let sidebarMinWidth: CGFloat = 256

    /// Ideal sidebar width
    static let sidebarIdealWidth: CGFloat = 256

    /// Maximum sidebar width
    static let sidebarMaxWidth: CGFloat = 400

    /// Minimum content width
    static let contentMinWidth: CGFloat = 400
}

// MARK: - Convenience View Modifiers

extension View {
    /// Apply standard padding using spacing constants
    func paddingStandard() -> some View {
        self.padding(.spacingL)
    }

    /// Apply compact padding using spacing constants
    func paddingCompact() -> some View {
        self.padding(.spacingM)
    }

    /// Apply generous padding using spacing constants
    func paddingGenerous() -> some View {
        self.padding(.spacingXXL)
    }

    /// Apply standard corner radius
    func cornerRadiusStandard() -> some View {
        self.cornerRadius(.cornerRadiusM)
    }

    /// Apply large corner radius
    func cornerRadiusLarge() -> some View {
        self.cornerRadius(.cornerRadiusL)
    }
}

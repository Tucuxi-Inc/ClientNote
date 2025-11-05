//
//  ButtonStyles.swift
//  ClientNote
//
//  Created by AI Assistant
//  Standardized button styles for consistent UI
//

import SwiftUI

// MARK: - Euni Primary Button Style

struct EuniPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .foregroundColor(.white)
            .padding(.horizontal, .spacingL)
            .padding(.vertical, .spacingM)
            .background(
                RoundedRectangle(cornerRadius: .cornerRadiusM)
                    .fill(isEnabled ? Color.euniPrimary : Color.euniPrimary.opacity(0.5))
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Euni Secondary Button Style

struct EuniSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .foregroundColor(isEnabled ? Color.euniPrimary : Color.euniPrimary.opacity(0.5))
            .padding(.horizontal, .spacingL)
            .padding(.vertical, .spacingM)
            .background(
                RoundedRectangle(cornerRadius: .cornerRadiusM)
                    .stroke(isEnabled ? Color.euniPrimary : Color.euniPrimary.opacity(0.5), lineWidth: .borderStandard)
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Euni Destructive Button Style

struct EuniDestructiveButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .foregroundColor(.white)
            .padding(.horizontal, .spacingL)
            .padding(.vertical, .spacingM)
            .background(
                RoundedRectangle(cornerRadius: .cornerRadiusM)
                    .fill(isEnabled ? Color.euniError : Color.euniError.opacity(0.5))
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Euni Borderless Button Style

struct EuniBorderlessButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .foregroundColor(isEnabled ? Color.euniPrimary : Color.euniPrimary.opacity(0.5))
            .padding(.horizontal, .spacingS)
            .padding(.vertical, .spacingXS)
            .opacity(configuration.isPressed ? 0.6 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Euni Icon Button Style

struct EuniIconButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .foregroundColor(isEnabled ? Color.euniSecondary : Color.euniSecondary.opacity(0.5))
            .padding(.spacingS)
            .background(
                Circle()
                    .fill(Color.euniFieldBackground)
                    .opacity(configuration.isPressed ? 0.5 : 0.0)
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Button Style Extension

extension ButtonStyle where Self == EuniPrimaryButtonStyle {
    static var euniPrimary: EuniPrimaryButtonStyle {
        EuniPrimaryButtonStyle()
    }
}

extension ButtonStyle where Self == EuniSecondaryButtonStyle {
    static var euniSecondary: EuniSecondaryButtonStyle {
        EuniSecondaryButtonStyle()
    }
}

extension ButtonStyle where Self == EuniDestructiveButtonStyle {
    static var euniDestructive: EuniDestructiveButtonStyle {
        EuniDestructiveButtonStyle()
    }
}

extension ButtonStyle where Self == EuniBorderlessButtonStyle {
    static var euniBorderless: EuniBorderlessButtonStyle {
        EuniBorderlessButtonStyle()
    }
}

extension ButtonStyle where Self == EuniIconButtonStyle {
    static var euniIcon: EuniIconButtonStyle {
        EuniIconButtonStyle()
    }
}

import SwiftUI

public struct CircleButton: View {
    private let systemImage: String
    private let accessibilityLabel: String?
    private let accessibilityHint: String?
    private let action: () -> Void

    public init(
        systemImage: String,
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .foregroundColor(Color.euniText)
                .fontWeight(.bold)
                .padding(.spacingS)
        }
        .background(Color.euniFieldBackground)
        .buttonStyle(.borderless)
        .clipShape(.circle)
        .overlay(
            Circle()
                .stroke(Color.euniBorder, lineWidth: .borderStandard)
        )
        .accessibilityLabel(accessibilityLabel ?? systemImage)
        .accessibilityHint(accessibilityHint ?? "")
        .accessibilityAddTraits(.isButton)
    }
}

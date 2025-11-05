import SwiftUI

struct MessageButton: View {
    private let title: String
    private let systemImage: String
    private let accessibilityHint: String?
    private let action: () -> Void

    init(
        _ title: String,
        systemImage: String,
        accessibilityHint: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.accessibilityHint = accessibilityHint
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundColor(Color.euniSecondary)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .tint(Color.euniPrimary)
        .accessibilityLabel(title)
        .accessibilityHint(accessibilityHint ?? "")
        .accessibilityAddTraits(.isButton)
    }
}

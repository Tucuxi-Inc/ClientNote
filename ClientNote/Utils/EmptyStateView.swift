//
//  EmptyStateView.swift
//  ClientNote
//
//  Created by AI Assistant
//  Reusable empty state view component
//

import SwiftUI

/// A reusable empty state view with icon, title, message, and optional action
struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        systemImage: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: .spacingL) {
            Image(systemName: systemImage)
                .font(.system(size: 48))
                .foregroundColor(Color.euniSecondary.opacity(0.5))

            VStack(spacing: .spacingS) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(Color.euniText)

                Text(message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                }
                .buttonStyle(.euniPrimary)
            }
        }
        .padding(.spacingXXL)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview("Empty Activity List") {
    EmptyStateView(
        systemImage: "doc.text",
        title: "No Activities",
        message: "Start by creating a new session note, treatment plan, or brainstorm session.",
        actionTitle: "Create Activity",
        action: { print("Create activity") }
    )
}

#Preview("Empty Chat") {
    EmptyStateView(
        systemImage: "message",
        title: "No Messages",
        message: "Type a message to start the conversation.",
        actionTitle: nil,
        action: nil
    )
}

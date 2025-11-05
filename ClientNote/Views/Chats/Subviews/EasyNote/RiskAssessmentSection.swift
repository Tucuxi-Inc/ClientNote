//
//  RiskAssessmentSection.swift
//  ClientNote
//
//  Created by AI Assistant
//  Risk assessment section for suicidal ideation tracking
//

import SwiftUI

struct RiskAssessmentSection: View {
    @Binding var hasSuicidalIdeation: Bool
    @Binding var suicidalIdeationPastSession: Bool
    @Binding var suicidalIdeationCurrentSession: Bool
    @Binding var suicidalIdeationBothSessions: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingM) {
            FormSectionHeader(
                "Risk Assessment",
                subtitle: "Document any suicidal ideation or self-harm concerns"
            )

            // Main toggle for suicidal ideation
            FormToggleRow(
                "Suicidal Ideation or Self-Harm Present",
                isOn: $hasSuicidalIdeation,
                description: "Indicate if client expressed or demonstrated suicidal ideation or self-harm thoughts"
            )

            // Detailed assessment if present
            if hasSuicidalIdeation {
                VStack(alignment: .leading, spacing: .spacingM) {
                    FormDivider()

                    Text("Time Frame")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Color.euniText)

                    VStack(alignment: .leading, spacing: .spacingS) {
                        Toggle(isOn: $suicidalIdeationPastSession) {
                            VStack(alignment: .leading, spacing: .spacingXS) {
                                Text("Past Session")
                                    .font(.body)
                                    .foregroundColor(Color.euniText)
                                Text("Ideation occurred between last session and today")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .toggleStyle(.checkbox)

                        Toggle(isOn: $suicidalIdeationCurrentSession) {
                            VStack(alignment: .leading, spacing: .spacingXS) {
                                Text("Current Session")
                                    .font(.body)
                                    .foregroundColor(Color.euniText)
                                Text("Ideation expressed during this session")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .toggleStyle(.checkbox)

                        Toggle(isOn: $suicidalIdeationBothSessions) {
                            VStack(alignment: .leading, spacing: .spacingXS) {
                                Text("Both Time Periods")
                                    .font(.body)
                                    .foregroundColor(Color.euniText)
                                Text("Ideation present in both past and current session")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .toggleStyle(.checkbox)
                    }
                    .padding(.spacingM)
                    .background(Color.euniError.opacity(0.05))
                    .cornerRadius(.cornerRadiusS)
                    .overlay(
                        RoundedRectangle(cornerRadius: .cornerRadiusS)
                            .stroke(Color.euniError.opacity(0.3), lineWidth: .borderStandard)
                    )

                    // Warning message
                    HStack(spacing: .spacingM) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(Color.euniError)
                        Text("Ensure proper safety planning and documentation")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.spacingS)
                    .background(Color.euniError.opacity(0.1))
                    .cornerRadius(.cornerRadiusS)
                }
            }
        }
    }
}

#Preview("No Risk") {
    @Previewable @State var hasRisk = false
    @Previewable @State var past = false
    @Previewable @State var current = false
    @Previewable @State var both = false

    RiskAssessmentSection(
        hasSuicidalIdeation: $hasRisk,
        suicidalIdeationPastSession: $past,
        suicidalIdeationCurrentSession: $current,
        suicidalIdeationBothSessions: $both
    )
    .padding()
}

#Preview("With Risk") {
    @Previewable @State var hasRisk = true
    @Previewable @State var past = true
    @Previewable @State var current = false
    @Previewable @State var both = false

    RiskAssessmentSection(
        hasSuicidalIdeation: $hasRisk,
        suicidalIdeationPastSession: $past,
        suicidalIdeationCurrentSession: $current,
        suicidalIdeationBothSessions: $both
    )
    .padding()
}

//
//  TherapeuticApproachSection.swift
//  ClientNote
//
//  Created by AI Assistant
//  Therapeutic approach and interventions selection for EasyNote
//

import SwiftUI

struct TherapeuticApproachSection: View {
    @Binding var selectedApproach: String
    @Binding var customApproach: String
    @Binding var selectedInterventions: Set<String>

    let approaches = [
        "CBT (Cognitive Behavioral Therapy)",
        "DBT (Dialectical Behavior Therapy)",
        "ACT (Acceptance and Commitment Therapy)",
        "Psychodynamic",
        "Person-Centered",
        "EMDR (Eye Movement Desensitization and Reprocessing)",
        "IFS (Internal Family Systems)",
        "Solution-Focused Brief Therapy (SFBT)",
        "Narrative Therapy",
        "TF-CBT (Trauma-Focused Cognitive Behavioral Therapy)",
        "Behavioral Therapy",
        "Motivational Interviewing (MI)",
        "Play Therapy",
        "Gottman Method Couples Therapy",
        "Integrative Family and Couple Therapy (IFCT)",
        "Other"
    ]

    let interventions: [String: [String]] = [
        "CBT (Cognitive Behavioral Therapy)": [
            "Cognitive restructuring",
            "Socratic questioning",
            "Thought records",
            "Identifying automatic thoughts",
            "Behavioral activation",
            "Schema identification",
            "Cognitive triangle",
            "Thought-challenging techniques",
            "Cognitive distortions labeling"
        ],
        "DBT (Dialectical Behavior Therapy)": [
            "Mindfulness training",
            "Distress tolerance (IMPROVE, self-soothing)",
            "Emotion regulation skills (Check the Facts, Opposite Action)",
            "Interpersonal effectiveness (DEAR MAN, GIVE, FAST)",
            "Diary card review",
            "Chain analysis",
            "Radical acceptance"
        ],
        "ACT (Acceptance and Commitment Therapy)": [
            "Values clarification",
            "Cognitive defusion",
            "Acceptance techniques",
            "Present-moment awareness",
            "Committed action planning",
            "Self-as-context work",
            "Mindful observation",
            "Observer perspective",
            "Breathing/grounding exercises",
            "Values-based goal setting"
        ],
        "Psychodynamic": [
            "Exploring defense mechanisms",
            "Attachment pattern analysis",
            "Transference/Countertransference exploration",
            "Insight development",
            "Free association",
            "Interpretation of unconscious material"
        ],
        "Person-Centered": [
            "Reflective listening",
            "Unconditional positive regard",
            "Empathic responding",
            "Genuineness/congruence",
            "Encouraging self-exploration",
            "Use of silence and presence",
            "Client-led journaling or expressive mediums",
            "Emotional mirroring",
            "Minimal interpretation"
        ]
        // Add more as needed
    ]

    private var availableInterventions: [String] {
        interventions[selectedApproach] ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingM) {
            FormSectionHeader("Therapeutic Approach", subtitle: "Select the primary approach used")

            // Approach Picker
            FormPickerRow(
                "Approach",
                selection: $selectedApproach,
                options: approaches,
                displayName: { $0 }
            )

            // Custom approach field for "Other"
            if selectedApproach == "Other" {
                FormTextField(
                    "Specify Approach",
                    text: $customApproach,
                    placeholder: "Enter custom approach"
                )
            }

            // Interventions section
            if !availableInterventions.isEmpty {
                FormDivider()

                FormSectionHeader("Interventions Used", subtitle: "Select all that apply")

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: .spacingS) {
                        ForEach(availableInterventions, id: \.self) { intervention in
                            Toggle(isOn: Binding(
                                get: { selectedInterventions.contains(intervention) },
                                set: { isSelected in
                                    if isSelected {
                                        selectedInterventions.insert(intervention)
                                    } else {
                                        selectedInterventions.remove(intervention)
                                    }
                                }
                            )) {
                                Text(intervention)
                                    .font(.body)
                                    .foregroundColor(Color.euniText)
                            }
                            .toggleStyle(.checkbox)
                        }
                    }
                    .padding(.spacingS)
                }
                .frame(maxHeight: 200)
                .background(Color.euniFieldBackground)
                .cornerRadius(.cornerRadiusS)
                .overlay(
                    RoundedRectangle(cornerRadius: .cornerRadiusS)
                        .stroke(Color.euniBorder, lineWidth: .borderStandard)
                )
            }

            // Selected interventions summary
            if !selectedInterventions.isEmpty {
                VStack(alignment: .leading, spacing: .spacingXS) {
                    Text("Selected: \(selectedInterventions.count) interventions")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button("Clear All") {
                        selectedInterventions.removeAll()
                    }
                    .buttonStyle(.euniBorderless)
                    .controlSize(.small)
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var approach = "CBT (Cognitive Behavioral Therapy)"
    @Previewable @State var customApproach = ""
    @Previewable @State var interventions: Set<String> = []

    ScrollView {
        TherapeuticApproachSection(
            selectedApproach: $approach,
            customApproach: $customApproach,
            selectedInterventions: $interventions
        )
        .padding()
    }
}

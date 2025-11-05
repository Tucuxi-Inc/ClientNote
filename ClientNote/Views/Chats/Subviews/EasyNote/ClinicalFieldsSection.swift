//
//  ClinicalFieldsSection.swift
//  ClientNote
//
//  Created by AI Assistant
//  Core clinical fields for session notes
//

import SwiftUI

struct ClinicalFieldsSection: View {
    @Binding var presentingIssue: String
    @Binding var customPresentingIssue: String
    @Binding var clientResponse: String
    @Binding var customClientResponse: String
    @Binding var clinicalFocus: String
    @Binding var customClinicalFocus: String
    @Binding var treatmentGoals: String
    @Binding var customTreatmentGoals: String

    let presentingIssues = [
        "Anxiety",
        "Depression",
        "Trauma",
        "Relationship conflict",
        "Emotional dysregulation",
        "Grief",
        "Identity exploration",
        "Other"
    ]

    let clientResponses = [
        "Engaged and cooperative",
        "Resistant but participated",
        "Emotionally activated",
        "Demonstrated insight",
        "Avoidant or withdrawn",
        "Expressed ambivalence",
        "Other"
    ]

    let clinicalFocuses = [
        "Cognitive distortions",
        "Maladaptive schemas",
        "Emotional regulation",
        "Attachment patterns",
        "Trauma processing",
        "Behavioral change",
        "Other"
    ]

    let treatmentGoalsList = [
        "Reduce anxiety symptoms",
        "Increase emotional resilience",
        "Improve interpersonal functioning",
        "Develop insight into patterns",
        "Increase acceptance and psychological flexibility",
        "Other"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingL) {
            FormSectionHeader(
                "Clinical Information",
                subtitle: "Session details and client presentation"
            )

            // Presenting Issue
            VStack(alignment: .leading, spacing: .spacingM) {
                FormPickerRow(
                    "Presenting Issue",
                    selection: $presentingIssue,
                    options: presentingIssues,
                    displayName: { $0 }
                )

                if presentingIssue == "Other" {
                    FormTextField(
                        "Specify Presenting Issue",
                        text: $customPresentingIssue,
                        placeholder: "Enter specific presenting issue"
                    )
                }
            }

            FormDivider()

            // Client Response
            VStack(alignment: .leading, spacing: .spacingM) {
                FormPickerRow(
                    "Client Response & Engagement",
                    selection: $clientResponse,
                    options: clientResponses,
                    displayName: { $0 }
                )

                if clientResponse == "Other" {
                    FormTextField(
                        "Specify Client Response",
                        text: $customClientResponse,
                        placeholder: "Describe client's response and engagement"
                    )
                }
            }

            FormDivider()

            // Clinical Focus
            VStack(alignment: .leading, spacing: .spacingM) {
                FormPickerRow(
                    "Clinical Focus",
                    selection: $clinicalFocus,
                    options: clinicalFocuses,
                    displayName: { $0 }
                )

                if clinicalFocus == "Other" {
                    FormTextField(
                        "Specify Clinical Focus",
                        text: $customClinicalFocus,
                        placeholder: "Enter the primary clinical focus area"
                    )
                }
            }

            FormDivider()

            // Treatment Goals
            VStack(alignment: .leading, spacing: .spacingM) {
                FormPickerRow(
                    "Treatment Goals",
                    selection: $treatmentGoals,
                    options: treatmentGoalsList,
                    displayName: { $0 }
                )

                if treatmentGoals == "Other" {
                    FormTextField(
                        "Specify Treatment Goals",
                        text: $customTreatmentGoals,
                        placeholder: "Describe treatment goals for this session",
                        multiline: true
                    )
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Standard Values") {
    @Previewable @State var presentingIssue = "Anxiety"
    @Previewable @State var customPresenting = ""
    @Previewable @State var clientResponse = "Engaged and cooperative"
    @Previewable @State var customResponse = ""
    @Previewable @State var clinicalFocus = "Cognitive distortions"
    @Previewable @State var customFocus = ""
    @Previewable @State var treatmentGoals = "Reduce anxiety symptoms"
    @Previewable @State var customGoals = ""

    ScrollView {
        ClinicalFieldsSection(
            presentingIssue: $presentingIssue,
            customPresentingIssue: $customPresenting,
            clientResponse: $clientResponse,
            customClientResponse: $customResponse,
            clinicalFocus: $clinicalFocus,
            customClinicalFocus: $customFocus,
            treatmentGoals: $treatmentGoals,
            customTreatmentGoals: $customGoals
        )
        .padding()
    }
}

#Preview("Custom Values") {
    @Previewable @State var presentingIssue = "Other"
    @Previewable @State var customPresenting = "Complex family dynamics"
    @Previewable @State var clientResponse = "Other"
    @Previewable @State var customResponse = "Tearful but engaged"
    @Previewable @State var clinicalFocus = "Other"
    @Previewable @State var customFocus = "Processing childhood trauma"
    @Previewable @State var treatmentGoals = "Other"
    @Previewable @State var customGoals = "Develop healthier coping mechanisms"

    ScrollView {
        ClinicalFieldsSection(
            presentingIssue: $presentingIssue,
            customPresentingIssue: $customPresenting,
            clientResponse: $clientResponse,
            customClientResponse: $customResponse,
            clinicalFocus: $clinicalFocus,
            customClinicalFocus: $customFocus,
            treatmentGoals: $treatmentGoals,
            customTreatmentGoals: $customGoals
        )
        .padding()
    }
}

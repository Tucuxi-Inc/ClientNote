//
//  AdditionalNotesSection.swift
//  ClientNote
//
//  Created by AI Assistant
//  Additional notes with voice recording support
//

import SwiftUI
import Speech
import AVFoundation

struct AdditionalNotesSection: View {
    @Binding var additionalNotes: String
    @Binding var isRecording: Bool

    let onStartRecording: () -> Void
    let onStopRecording: () -> Void
    let recordingPermissionGranted: Bool

    @State private var showPermissionAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingM) {
            FormSectionHeader(
                "Additional Notes",
                subtitle: "Add any supplementary information"
            )

            // Voice recording controls
            HStack(spacing: .spacingM) {
                if isRecording {
                    // Recording indicator
                    HStack(spacing: .spacingS) {
                        Circle()
                            .fill(Color.euniError)
                            .frame(width: 8, height: 8)
                            .opacity(0.8)
                            .scaleEffect(1.2)
                            .animation(
                                .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                                value: isRecording
                            )

                        Text("Recording...")
                            .font(.body.weight(.medium))
                            .foregroundColor(Color.euniError)
                    }

                    Spacer()

                    Button(action: onStopRecording) {
                        Label("Stop Recording", systemImage: "stop.circle.fill")
                    }
                    .buttonStyle(.euniDestructive)
                    .controlSize(.small)
                } else {
                    Button(action: {
                        if recordingPermissionGranted {
                            onStartRecording()
                        } else {
                            showPermissionAlert = true
                        }
                    }) {
                        Label("Record Voice Note", systemImage: "mic.circle.fill")
                    }
                    .buttonStyle(.euniSecondary)
                    .controlSize(.small)

                    Spacer()

                    if !additionalNotes.isEmpty {
                        Text("\(additionalNotes.count) characters")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.spacingS)
            .background(Color.euniFieldBackground.opacity(0.5))
            .cornerRadius(.cornerRadiusS)

            // Text editor
            VStack(alignment: .leading, spacing: .spacingXS) {
                Text("Notes")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(Color.euniText)

                ZStack(alignment: .topLeading) {
                    if additionalNotes.isEmpty {
                        Text("Type or record additional observations, client statements, or session details...")
                            .font(.body)
                            .foregroundColor(.secondary.opacity(0.5))
                            .padding(.spacingS)
                            .allowsHitTesting(false)
                    }

                    TextEditor(text: $additionalNotes)
                        .font(.body)
                        .frame(minHeight: 120)
                        .padding(.spacingXS)
                        .scrollContentBackground(.hidden)
                }
                .background(Color.euniFieldBackground)
                .cornerRadius(.cornerRadiusS)
                .overlay(
                    RoundedRectangle(cornerRadius: .cornerRadiusS)
                        .stroke(Color.euniBorder, lineWidth: .borderStandard)
                )
            }

            // Tips
            if !isRecording && additionalNotes.isEmpty {
                HStack(spacing: .spacingS) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(Color.euniSecondary)
                        .font(.caption)

                    Text("Tip: Include specific client quotes, behavioral observations, or homework assignments")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.spacingS)
                .background(Color.euniSecondary.opacity(0.05))
                .cornerRadius(.cornerRadiusS)
            }
        }
        .alert("Microphone Permission Required", isPresented: $showPermissionAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Open Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                    NSWorkspace.shared.open(url)
                }
            }
        } message: {
            Text("Please grant microphone access in System Preferences to use voice recording.")
        }
    }
}

// MARK: - Preview

#Preview("Empty") {
    @Previewable @State var notes = ""
    @Previewable @State var recording = false

    AdditionalNotesSection(
        additionalNotes: $notes,
        isRecording: $recording,
        onStartRecording: { recording = true },
        onStopRecording: { recording = false },
        recordingPermissionGranted: true
    )
    .padding()
}

#Preview("With Content") {
    @Previewable @State var notes = "Client expressed concern about recent work stress. Mentioned difficulty sleeping and increased irritability. Agreed to practice relaxation techniques discussed in session."
    @Previewable @State var recording = false

    AdditionalNotesSection(
        additionalNotes: $notes,
        isRecording: $recording,
        onStartRecording: { recording = true },
        onStopRecording: { recording = false },
        recordingPermissionGranted: true
    )
    .padding()
}

#Preview("Recording") {
    @Previewable @State var notes = ""
    @Previewable @State var recording = true

    AdditionalNotesSection(
        additionalNotes: $notes,
        isRecording: $recording,
        onStartRecording: { recording = true },
        onStopRecording: { recording = false },
        recordingPermissionGranted: true
    )
    .padding()
}

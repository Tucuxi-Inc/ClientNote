//
//  TranscriptView.swift
//  ClientNote
//
//  Extracted from ChatView.swift
//  Displays real-time transcript with speaker identification
//

import SwiftUI

/// View for displaying transcription segments with speaker identification
struct TranscriptView: View {
    @ObservedObject var manager: TranscriptManager

    // MARK: - Helper Methods

    /// Get color for speaker label based on speaker ID
    private func speakerColor(for speaker: String) -> Color {
        switch speaker {
        case "Speaker 1":
            return Color.euniPrimary
        case "Speaker 2":
            return Color.euniSecondary
        case "Speaker 3":
            return Color.orange
        case "Speaker 4":
            return Color.purple
        default:
            return Color.gray
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .spacingS) {
                if manager.transcriptSegments.isEmpty {
                    // Empty state
                    Text("Transcript will appear here as you speak...")
                        .foregroundColor(.secondary)
                        .italic()
                        .padding(.spacingL)
                } else {
                    // Show individual segments with speaker identification
                    ForEach(manager.transcriptSegments.sorted(by: { $0.index < $1.index })) { segment in
                        VStack(alignment: .leading, spacing: .spacingXS) {
                            HStack {
                                Text("Segment \(segment.index + 1)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Spacer()

                                Text(manager.speakerIdentifier.getSpeakerLabel(segment.speaker))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, .spacingS)
                                    .padding(.vertical, 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: .cornerRadiusS)
                                            .fill(speakerColor(for: segment.speaker))
                                    )
                                    .foregroundColor(.white)
                            }

                            Text(segment.text)
                                .font(.body)
                                .foregroundColor(Color.euniText)
                        }
                        .padding(.vertical, .spacingXS)
                    }
                }
            }
            .padding(.spacingL)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.euniBackground)
    }
}

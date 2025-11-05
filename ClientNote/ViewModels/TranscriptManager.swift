//
//  TranscriptManager.swift
//  ClientNote
//
//  Extracted from ChatView.swift
//  Manages transcript segments during voice recording sessions
//

import Foundation
import AVFoundation
import Combine

/// Manages transcript segments with speaker identification for recording sessions
class TranscriptManager: ObservableObject {
    // MARK: - Transcript Segment

    struct TranscriptSegment: Identifiable {
        let id = UUID()
        let index: Int
        let text: String
        let speaker: String
        let timestamp: Date
    }

    // MARK: - Properties

    @Published private(set) var transcriptSegments: [TranscriptSegment] = []
    let speakerIdentifier = SpeakerIdentifier()

    // MARK: - Computed Properties

    /// Get the full formatted transcript with speaker labels
    var fullTranscript: String {
        transcriptSegments
            .sorted(by: { $0.index < $1.index })
            .map { segment in
                let speaker = speakerIdentifier.getSpeakerLabel(segment.speaker)
                return "\(speaker): \(segment.text)"
            }
            .joined(separator: "\n\n")
    }

    // MARK: - Initialization

    init() {}

    // MARK: - Public Methods

    /// Append a new transcript segment
    /// - Parameters:
    ///   - index: The segment index
    ///   - text: The transcribed text
    ///   - speaker: The speaker ID (defaults to "Speaker 1")
    func appendTranscript(for index: Int, text: String, speaker: String = "Speaker 1") {
        let segment = TranscriptSegment(
            index: index,
            text: text.trimmingCharacters(in: .whitespacesAndNewlines),
            speaker: speaker,
            timestamp: Date()
        )
        DispatchQueue.main.async {
            self.transcriptSegments.append(segment)
        }
    }

    /// Update an existing transcript segment or create a new one
    /// - Parameters:
    ///   - index: The segment index
    ///   - text: The transcribed text
    ///   - isFinal: Whether this is the final version of the transcription
    ///   - audioBuffer: Optional audio buffer for speaker identification
    func updateTranscript(for index: Int, text: String, isFinal: Bool, audioBuffer: AVAudioPCMBuffer? = nil) {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Identify speaker if we have audio buffer
        var speaker = "Speaker 1"
        if let buffer = audioBuffer {
            speaker = speakerIdentifier.identifySpeaker(audioBuffer: buffer, transcribedText: cleanText)
        }

        DispatchQueue.main.async {
            // Find existing segment for this index
            if let existingIndex = self.transcriptSegments.firstIndex(where: { $0.index == index }) {
                // Update existing segment, preserving speaker if it was already identified
                let existingSpeaker = self.transcriptSegments[existingIndex].speaker
                self.transcriptSegments[existingIndex] = TranscriptSegment(
                    index: index,
                    text: cleanText,
                    speaker: isFinal ? speaker : existingSpeaker, // Only update speaker on final result
                    timestamp: Date()
                )
            } else {
                // Create new segment
                let segment = TranscriptSegment(
                    index: index,
                    text: cleanText,
                    speaker: speaker,
                    timestamp: Date()
                )
                self.transcriptSegments.append(segment)
            }
        }
    }

    /// Clear all transcript segments and reset speaker identification
    func clearTranscript() {
        transcriptSegments.removeAll()
        speakerIdentifier.reset()
    }
}

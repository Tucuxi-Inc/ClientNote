//
//  SpeakerIdentifier.swift
//  ClientNote
//
//  Extracted from ChatView.swift
//  Handles speaker identification during voice recording sessions
//

import Foundation
import AVFoundation
import Combine

/// Identifies different speakers in a multi-person conversation based on voice characteristics
class SpeakerIdentifier: ObservableObject {
    // MARK: - Properties

    private var voiceProfiles: [String: VoiceProfile] = [:]
    private var currentSpeaker: String = "Speaker 1"
    private var lastSpeechTime: Date = Date()
    private let silenceThreshold: TimeInterval = 2.0 // 2 seconds of silence indicates speaker change

    // MARK: - Voice Profile

    struct VoiceProfile {
        let id: String
        var averagePitch: Float
        var speechRate: Float
        var energyLevel: Float
        var sampleCount: Int

        mutating func updateProfile(pitch: Float, rate: Float, energy: Float) {
            let newCount = sampleCount + 1
            averagePitch = (averagePitch * Float(sampleCount) + pitch) / Float(newCount)
            speechRate = (speechRate * Float(sampleCount) + rate) / Float(newCount)
            energyLevel = (energyLevel * Float(sampleCount) + energy) / Float(newCount)
            sampleCount = newCount
        }
    }

    // MARK: - Public Methods

    /// Identify the speaker based on audio characteristics and timing
    /// - Parameters:
    ///   - audioBuffer: The audio buffer containing voice data
    ///   - transcribedText: The transcribed text from the audio
    /// - Returns: The identified speaker ID
    func identifySpeaker(audioBuffer: AVAudioPCMBuffer, transcribedText: String) -> String {
        let now = Date()
        let timeSinceLastSpeech = now.timeIntervalSince(lastSpeechTime)

        // Simple heuristics for speaker identification
        let textLength = transcribedText.count
        let estimatedSpeechRate = Float(textLength) / Float(max(1, timeSinceLastSpeech))

        // Basic audio analysis (simplified)
        let frameLength = Int(audioBuffer.frameLength)
        let channelData = audioBuffer.floatChannelData?[0]

        var averageEnergy: Float = 0
        var averagePitch: Float = 0

        if let data = channelData, frameLength > 0 {
            // Calculate average energy
            for i in 0..<frameLength {
                averageEnergy += abs(data[i])
            }
            averageEnergy /= Float(frameLength)

            // Simplified pitch estimation (zero-crossing rate)
            var zeroCrossings = 0
            for i in 1..<frameLength {
                if (data[i] >= 0) != (data[i-1] >= 0) {
                    zeroCrossings += 1
                }
            }
            averagePitch = Float(zeroCrossings) / Float(frameLength) * 1000 // Rough pitch estimate
        }

        // Determine speaker based on silence gaps and voice characteristics
        if timeSinceLastSpeech > silenceThreshold {
            // Potential speaker change - analyze voice characteristics
            let speakerID = findBestMatchingSpeaker(pitch: averagePitch, rate: estimatedSpeechRate, energy: averageEnergy)
            currentSpeaker = speakerID
        }

        // Update voice profile
        updateVoiceProfile(speakerID: currentSpeaker, pitch: averagePitch, rate: estimatedSpeechRate, energy: averageEnergy)

        lastSpeechTime = now
        return currentSpeaker
    }

    /// Get a human-readable label for a speaker ID
    /// - Parameter speakerID: The speaker ID to get a label for
    /// - Returns: A user-friendly speaker label
    func getSpeakerLabel(_ speakerID: String) -> String {
        // For now, use generic labels. Could be enhanced to allow custom naming
        switch speakerID {
        case "Speaker 1":
            return "Clinician" // Assume first speaker is clinician
        case "Speaker 2":
            return "Client"
        case "Speaker 3":
            return "Client 2"
        case "Speaker 4":
            return "Client 3"
        default:
            return speakerID
        }
    }

    /// Reset the speaker identifier state
    func reset() {
        voiceProfiles.removeAll()
        currentSpeaker = "Speaker 1"
        lastSpeechTime = Date()
    }

    // MARK: - Private Methods

    /// Find the best matching speaker based on voice characteristics
    private func findBestMatchingSpeaker(pitch: Float, rate: Float, energy: Float) -> String {
        var bestMatch = "Speaker 1"
        var bestScore = Float.infinity

        for (speakerID, profile) in voiceProfiles {
            let pitchDiff = abs(profile.averagePitch - pitch)
            let rateDiff = abs(profile.speechRate - rate)
            let energyDiff = abs(profile.energyLevel - energy)

            let score = pitchDiff + rateDiff * 10 + energyDiff * 100 // Weighted scoring

            if score < bestScore {
                bestScore = score
                bestMatch = speakerID
            }
        }

        // If no good match found and we have fewer than 4 speakers, create new speaker
        if bestScore > 50 && voiceProfiles.count < 4 {
            let newSpeakerID = "Speaker \(voiceProfiles.count + 1)"
            return newSpeakerID
        }

        return bestMatch
    }

    /// Update or create a voice profile for a speaker
    private func updateVoiceProfile(speakerID: String, pitch: Float, rate: Float, energy: Float) {
        if var profile = voiceProfiles[speakerID] {
            profile.updateProfile(pitch: pitch, rate: rate, energy: energy)
            voiceProfiles[speakerID] = profile
        } else {
            voiceProfiles[speakerID] = VoiceProfile(
                id: speakerID,
                averagePitch: pitch,
                speechRate: rate,
                energyLevel: energy,
                sampleCount: 1
            )
        }
    }
}

//
//  ChatView.swift
//  ClientNote
//
//  Created by Kevin Hermawan on 8/2/24.
//

import Defaults
import ChatField
import OllamaKit
import SwiftUI
import ViewCondition
import Speech
import AVFoundation
import SwiftData
import Foundation
import Combine

// MARK: - Recording Support Classes

// MARK: - Speaker Identification
class SpeakerIdentifier: ObservableObject {
    private var voiceProfiles: [String: VoiceProfile] = [:]
    private var currentSpeaker: String = "Speaker 1"
    private var lastSpeechTime: Date = Date()
    private let silenceThreshold: TimeInterval = 2.0 // 2 seconds of silence indicates speaker change
    
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
    
    func reset() {
        voiceProfiles.removeAll()
        currentSpeaker = "Speaker 1"
        lastSpeechTime = Date()
    }
}

// MARK: - Transcript Management
class TranscriptManager: ObservableObject {
    struct TranscriptSegment: Identifiable {
        let id = UUID()
        let index: Int
        let text: String
        let speaker: String
        let timestamp: Date
    }

    @Published private(set) var transcriptSegments: [TranscriptSegment] = []
    let speakerIdentifier = SpeakerIdentifier()

    var fullTranscript: String {
        transcriptSegments
            .sorted(by: { $0.index < $1.index })
            .map { segment in
                let speaker = speakerIdentifier.getSpeakerLabel(segment.speaker)
                return "\(speaker): \(segment.text)"
            }
            .joined(separator: "\n\n")
    }

    init() {}

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

    func clearTranscript() {
        transcriptSegments.removeAll()
        speakerIdentifier.reset()
    }
}

// MARK: - Live Recorder
class LiveRecorder: NSObject {
    private let audioEngine = AVAudioEngine()
    private var file: AVAudioFile?
    private var segmentIndex = 0
    private var timer: Timer?
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    private var transcriptManager: TranscriptManager
    private let chunkDuration: TimeInterval = 30
    private let directory: URL
    private var currentAudioBuffer: AVAudioPCMBuffer?

    init(transcriptManager: TranscriptManager) {
        self.transcriptManager = transcriptManager
        self.directory = FileManager.default.temporaryDirectory.appendingPathComponent("TherapyChunks", isDirectory: true)
        super.init()
        
        // Create directory for audio chunks
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        print("DEBUG: Created audio chunks directory at: \(directory.path)")
        
        // Setup speech recognizer
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        print("DEBUG: Speech recognizer initialized - available: \(speechRecognizer?.isAvailable ?? false)")
        
        if let recognizer = speechRecognizer {
            print("DEBUG: Speech recognizer locale: \(recognizer.locale.identifier)")
            print("DEBUG: Speech recognizer supports on-device: \(recognizer.supportsOnDeviceRecognition)")
        } else {
            print("DEBUG: Failed to create speech recognizer")
        }
    }

    func startRecording() throws {
        // Request permissions first
        guard speechRecognizer?.isAvailable == true else {
            throw RecordingError.speechRecognitionUnavailable
        }
        
        // Stop any existing recording
        stopRecording()
        
        let inputNode = audioEngine.inputNode
        // Use the input node's native format instead of forcing a specific sample rate
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        print("DEBUG: Input format: \(inputFormat)")
        
        // Remove any existing tap
        inputNode.removeTap(onBus: 0)
        
        // Install tap for audio processing using the native format
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, time in
            // Write to current segment file
            try? self?.file?.write(from: buffer)
            
            // Store current audio buffer for speaker identification
            self?.currentAudioBuffer = buffer
            
            // Also send to speech recognition for real-time transcription
            if let recognitionRequest = self?.recognitionRequest {
                recognitionRequest.append(buffer)
                // Debug: Log audio buffer info occasionally
                if Int(time.sampleTime) % 48000 == 0 { // Log every second (assuming 48kHz)
                    print("DEBUG: Audio buffer sent to speech recognition - samples: \(buffer.frameLength), time: \(time.sampleTime)")
                }
            } else {
                print("DEBUG: No recognition request available for audio buffer")
            }
        }

        audioEngine.prepare()
        try audioEngine.start()
        
        // Start the first segment
        startNewSegment()
    }

    func stopRecording() {
        timer?.invalidate()
        timer = nil
        
        // Stop speech recognition
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        // Stop audio engine
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        file = nil
    }

    private func startNewSegment() {
        // Close previous file
        file = nil
        
        // Create new segment file
        let segmentURL = directory.appendingPathComponent("segment_\(segmentIndex).wav")
        
        // Use the input node's native format for file writing
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        do {
            file = try AVAudioFile(forWriting: segmentURL, settings: inputFormat.settings)
        } catch {
            print("Error creating audio file: \(error)")
        }
        
        // Setup speech recognition for this segment
        setupSpeechRecognitionForSegment()

        // Schedule timer for next segment
        timer = Timer.scheduledTimer(withTimeInterval: chunkDuration, repeats: false) { [weak self] _ in
            self?.finishCurrentSegment()
            self?.segmentIndex += 1
            self?.startNewSegment()
        }
    }
    
    private func setupSpeechRecognitionForSegment() {
        // Cancel previous recognition
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Create new recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { 
            print("DEBUG: Failed to create recognition request")
            return 
        }
        
        recognitionRequest.shouldReportPartialResults = true // Enable partial results for real-time feedback
        recognitionRequest.requiresOnDeviceRecognition = false // Allow cloud recognition for better accuracy
        
        print("DEBUG: Starting speech recognition for segment \(segmentIndex)")
        
        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("DEBUG: Speech recognition error: \(error.localizedDescription)")
                    // Don't return immediately on error - some errors are recoverable
                }
                
                if let result = result {
                    let transcribedText = result.bestTranscription.formattedString
                    print("DEBUG: Transcribed text (isFinal: \(result.isFinal)): '\(transcribedText)'")
                    
                    if !transcribedText.isEmpty {
                        // Always add the latest transcription (both partial and final)
                        // This ensures the UI updates in real-time
                        self?.transcriptManager.updateTranscript(
                            for: self?.segmentIndex ?? 0, 
                            text: transcribedText, 
                            isFinal: result.isFinal,
                            audioBuffer: self?.currentAudioBuffer
                        )
                        
                        if result.isFinal {
                            print("DEBUG: Added final transcript for segment \(self?.segmentIndex ?? 0)")
                        } else {
                            print("DEBUG: Updated partial result for segment \(self?.segmentIndex ?? 0)")
                        }
                    }
                } else {
                    print("DEBUG: No result from speech recognition")
                }
            }
        }
        
        if recognitionTask == nil {
            print("DEBUG: Failed to create recognition task")
        }
    }
    
    private func finishCurrentSegment() {
        // End the current speech recognition request
        recognitionRequest?.endAudio()
    }
}

// MARK: - Recording Errors
enum RecordingError: Error {
    case speechRecognitionUnavailable
    case audioEngineFailure
    case permissionDenied
    
    var localizedDescription: String {
        switch self {
        case .speechRecognitionUnavailable:
            return "Speech recognition is not available on this device"
        case .audioEngineFailure:
            return "Failed to start audio engine"
        case .permissionDenied:
            return "Microphone permission denied"
        }
    }
}

// MARK: - Transcript View
struct TranscriptView: View {
    @ObservedObject var manager: TranscriptManager
    
    private func speakerColor(for speaker: String) -> Color {
        switch speaker {
        case "Speaker 1":
            return .blue
        case "Speaker 2":
            return .green
        case "Speaker 3":
            return .orange
        case "Speaker 4":
            return .purple
        default:
            return .gray
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if manager.transcriptSegments.isEmpty {
                    Text("Transcript will appear here as you speak...")
                        .foregroundColor(.secondary)
                        .italic()
                        .padding()
                } else {
                    // Show individual segments with speaker identification
                    ForEach(manager.transcriptSegments.sorted(by: { $0.index < $1.index })) { segment in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Segment \(segment.index + 1)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text(manager.speakerIdentifier.getSpeakerLabel(segment.speaker))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(speakerColor(for: segment.speaker))
                                    )
                                    .foregroundColor(.white)
                            }
                            
                            Text(segment.text)
                                .font(.body)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

@Observable
class SpeechRecognitionViewModel {
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    
    var isRecording = false
    var showingPermissionAlert = false
    var showingErrorAlert = false
    var errorMessage = ""
    
    init() {
        requestSpeechRecognitionPermission()
    }
    
    private func requestSpeechRecognitionPermission() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
                case .denied, .restricted, .notDetermined:
                    self.showingPermissionAlert = true
                @unknown default:
                    self.showingPermissionAlert = true
                }
            }
        }
    }
    
    func startRecording(completion: @escaping (String) -> Void) {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            errorMessage = "Speech recognition is not available on this device."
            showingErrorAlert = true
            return
        }
        
        do {
            if audioEngine.isRunning {
                audioEngine.stop()
                recognitionRequest?.endAudio()
                isRecording = false
                return
            }
            
            recognitionTask?.cancel()
            recognitionTask = nil
            
            let inputNode = audioEngine.inputNode
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else {
                errorMessage = "Unable to create recognition request. Please try again."
                showingErrorAlert = true
                return
            }
            
            recognitionRequest.shouldReportPartialResults = true
            
            recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { result, error in
                if let error = error {
                    if let error = error as NSError? {
                        switch (error.domain, error.code) {
                        case ("kLSRErrorDomain", 301):
                            return
                        case ("kAFAssistantErrorDomain", 1101):
                            return
                        case (_, 1110):
                            if self.isRecording {
                                self.errorMessage = "No speech detected. Please try speaking again."
                                self.showingErrorAlert = true
                            }
                        default:
                            if !self.isRecording { return }
                            self.errorMessage = "Speech recognition error: \(error.localizedDescription)"
                            self.showingErrorAlert = true
                        }
                    }
                    self.stopRecording()
                    return
                }
                
                guard let result = result else { return }
                
                DispatchQueue.main.async {
                    if !result.bestTranscription.formattedString.isEmpty {
                        completion(result.bestTranscription.formattedString)
                    }
                }
            }
            
            guard recognitionTask != nil else {
                errorMessage = "Failed to create recognition task. Please try again."
                showingErrorAlert = true
                return
            }
            
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                self.recognitionRequest?.append(buffer)
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true
        } catch {
            errorMessage = "Error starting recording: \(error.localizedDescription)"
            showingErrorAlert = true
            stopRecording()
        }
    }
    
    func stopRecording() {
        recognitionTask?.cancel()
        recognitionTask = nil
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        isRecording = false
    }
    
    func cleanup() {
        stopRecording()
        speechRecognizer = nil
    }
}

// MARK: - Recording View
struct RecordingView: View {
    @Environment(ChatViewModel.self) private var chatViewModel
    @Environment(MessageViewModel.self) private var messageViewModel
    @Environment(\.modelContext) private var modelContext
    
    @StateObject private var transcriptManager = TranscriptManager()
    @State private var recorder: LiveRecorder?
    @State private var isRecording = false
    @State private var showingPermissionAlert = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var recordingDuration: TimeInterval = 0
    @State private var recordingTimer: Timer?
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Text("Therapy Session Recording")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Color.euniText)
                
                Text("Records in 30-second segments with real-time transcription")
                    .font(.subheadline)
                    .foregroundColor(Color.euniSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 20)
            
            // Recording Controls
            VStack(spacing: 16) {
                // Record Button
                Button(action: toggleRecording) {
                    HStack(spacing: 12) {
                        Image(systemName: isRecording ? "stop.circle.fill" : "record.circle")
                            .font(.title)
                            .foregroundColor(isRecording ? .red : Color.euniPrimary)
                        
                        Text(isRecording ? "Stop Recording" : "Start Recording")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.euniFieldBackground)
                            .stroke(isRecording ? Color.red : Color.euniPrimary, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
                
                // Recording Status
                if isRecording {
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .scaleEffect(isRecording ? 1.0 : 0.5)
                                .animation(.easeInOut(duration: 1.0).repeatForever(), value: isRecording)
                            
                            Text("Recording in progress...")
                                .font(.subheadline)
                                .foregroundColor(Color.euniSecondary)
                        }
                        
                        Text(formatDuration(recordingDuration))
                            .font(.caption)
                            .foregroundColor(Color.euniSecondary)
                            .monospacedDigit()
                    }
                }
                
                // Segment info
                if !transcriptManager.transcriptSegments.isEmpty {
                    Text("\(transcriptManager.transcriptSegments.count) segments recorded")
                        .font(.caption)
                        .foregroundColor(Color.euniSecondary)
                }
            }
            .padding(.horizontal, 40)
            
            // Transcript Display
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Live Transcript")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.euniText)
                    
                    Spacer()
                    
                    if !transcriptManager.fullTranscript.isEmpty {
                        Button("Clear") {
                            transcriptManager.clearTranscript()
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(Color.euniSecondary)
                    }
                }
                
                TranscriptView(manager: transcriptManager)
                    .frame(minHeight: 300)
                    .background(Color.euniFieldBackground)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.euniBorder, lineWidth: 1)
                    )
            }
            .padding(.horizontal, 20)
            
            // Save Button
            if !transcriptManager.fullTranscript.isEmpty {
                Button("Save Transcript") {
                    saveTranscript()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.bottom, 20)
            }
            
            Spacer()
        }
        .onAppear {
            setupRecorder()
            requestPermissions()
        }
        .onDisappear {
            stopRecording()
        }
        .alert("Microphone Permission Required", isPresented: $showingPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                    NSWorkspace.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please grant microphone access in System Settings to record therapy sessions.")
        }
        .alert("Recording Error", isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func setupRecorder() {
        recorder = LiveRecorder(transcriptManager: transcriptManager)
    }
    
    private func requestPermissions() {
        // Request speech recognition permission
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                print("DEBUG: Speech recognition authorization status: \(status.rawValue)")
                switch status {
                case .authorized:
                    print("DEBUG: Speech recognition authorized")
                case .denied:
                    print("DEBUG: Speech recognition denied")
                    self.showingPermissionAlert = true
                case .restricted:
                    print("DEBUG: Speech recognition restricted")
                    self.showingPermissionAlert = true
                case .notDetermined:
                    print("DEBUG: Speech recognition not determined")
                    self.showingPermissionAlert = true
                @unknown default:
                    print("DEBUG: Speech recognition unknown status")
                    self.showingPermissionAlert = true
                }
            }
        }
        
        // Also request microphone permission (macOS handles this automatically when audio recording starts)
        print("DEBUG: Microphone permission will be requested automatically when recording starts on macOS")
    }
    
    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        guard let recorder = recorder else {
            errorMessage = "Recorder not initialized"
            showingErrorAlert = true
            return
        }
        
        do {
            try recorder.startRecording()
            isRecording = true
            recordingDuration = 0
            
            // Start duration timer
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                recordingDuration += 1
            }
        } catch {
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
            showingErrorAlert = true
        }
    }
    
    private func stopRecording() {
        recorder?.stopRecording()
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func saveTranscript() {
        // Save the transcript to the current activity
        guard let selectedActivity = chatViewModel.selectedActivity else {
            errorMessage = "No activity selected to save transcript"
            showingErrorAlert = true
            return
        }
        
        // Create a clean, unified transcript format
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .medium
        
        let formattedTranscript = """
        Therapy Session Recording
        Date: \(dateFormatter.string(from: Date()))
        Client: \(chatViewModel.selectedClient?.identifier ?? "Unknown")
        Duration: \(formatDuration(recordingDuration))
        
        Transcript:
        \(transcriptManager.fullTranscript)
        """
        
        // Save to the activity
        if let clientIndex = chatViewModel.clients.firstIndex(where: { $0.id == chatViewModel.selectedClientID }),
           let activityIndex = chatViewModel.clients[clientIndex].activities.firstIndex(where: { $0.id == selectedActivity.id }) {
            
            chatViewModel.clients[clientIndex].activities[activityIndex].content = formattedTranscript
            chatViewModel.saveClient(chatViewModel.clients[clientIndex])
            
            // Also update the chat view with the transcript
            if let activeChat = chatViewModel.activeChat {
                // Clear existing messages
                for message in activeChat.messages {
                    modelContext.delete(message)
                }
                activeChat.messages.removeAll()
                
                // Add the transcript as a user message
                let transcriptMessage = Message(prompt: formattedTranscript)
                transcriptMessage.chat = activeChat
                activeChat.messages.append(transcriptMessage)
                
                // Reload the message view
                messageViewModel.load(of: activeChat)
            }
            
            // Clear the transcript after saving
            transcriptManager.clearTranscript()
            recordingDuration = 0
        }
    }
}

struct ChatView: View {
    @Environment(ChatViewModel.self) private var chatViewModel
    @Environment(MessageViewModel.self) private var messageViewModel
    @Environment(CodeHighlighter.self) private var codeHighlighter

    @AppStorage("experimentalCodeHighlighting") private var experimentalCodeHighlighting = false
    @Default(.fontSize) private var fontSize: Double

    @State private var ollamaKit: OllamaKit
    @State private var prompt = ""
    @State private var scrollProxy: ScrollViewProxy? = nil
    @State private var isPreferencesPresented = false
    @State private var isEasyNotePresented = false
    @State private var showAddClientSheet = false
    @FocusState private var isFocused: Bool
    
    private let taskOptions = [
        "Create a Treatment Plan",
        "Create a Client Session Note",
        "Brainstorm",
        "Record Therapy Session"
    ]
    
    init() {
        let baseURL = URL(string: Defaults[.defaultHost])!
        self._ollamaKit = State(initialValue: OllamaKit(baseURL: baseURL))
    }
    
    private func updateSystemPrompt() {
        print("DEBUG: updateSystemPrompt() called - selectedTask: '\(chatViewModel.selectedTask)'")
        
        // Get the appropriate system prompt from ChatViewModel
        let newType = chatViewModel.getActivityTypeFromTask(chatViewModel.selectedTask)
        let systemPrompt = chatViewModel.getSystemPromptForActivityType(newType)
        
        print("DEBUG: New activity type from task: \(newType.rawValue)")
        print("DEBUG: Current activeChat: \(chatViewModel.activeChat?.id.uuidString ?? "nil")")
        print("DEBUG: Current selectedActivity: \(chatViewModel.selectedActivity?.id.uuidString ?? "nil")")
        
        // Check if we're switching between different activity types via toolbar picker
        let currentPrompt = chatViewModel.activeChat?.systemPrompt ?? ""
        let previousType = currentPrompt.lowercased().contains("brainstorm") ? ActivityType.brainstorm :
                          currentPrompt.lowercased().contains("treatment plan") ? ActivityType.treatmentPlan :
                          ActivityType.sessionNote
        
        print("DEBUG: Previous type: \(previousType.rawValue), New type: \(newType.rawValue)")
        
        // Only clear chat if:
        // 1. We're switching between different activity types AND
        // 2. There's no currently selected activity (meaning this is a toolbar switch, not sidebar selection)
        if previousType != newType && chatViewModel.activeChat != nil && chatViewModel.selectedActivity == nil {
            print("DEBUG: Switching activity type via toolbar from \(previousType.rawValue) to \(newType.rawValue), clearing chat")
            chatViewModel.clearChatForNewActivityType()
        } else if previousType != newType && chatViewModel.selectedActivity != nil {
            print("DEBUG: Activity type change detected but selectedActivity exists, updating system prompt only")
        }
        
        // Update the active chat's system prompt
        if let activeChat = chatViewModel.activeChat {
            activeChat.systemPrompt = systemPrompt
            print("DEBUG: Updated system prompt for \(newType.rawValue)")
        } else {
            print("DEBUG: No active chat to update system prompt")
        }
    }
    
    var body: some View {
        MainChatContent(
            prompt: $prompt,
            messageViewModel: messageViewModel,
            chatViewModel: chatViewModel,
            fontSize: fontSize,
            isFocused: _isFocused,
            isEasyNotePresented: $isEasyNotePresented,
            isPreferencesPresented: $isPreferencesPresented,
            showAddClientSheet: $showAddClientSheet,
            ollamaKit: $ollamaKit,
            taskOptions: taskOptions,
            copyAction: copyAction,
            generateAction: generateAction,
            regenerateAction: regenerateAction,
            onActiveChatChanged: onActiveChatChanged,
            updateSystemPrompt: updateSystemPrompt
        )
        .sheet(isPresented: $isEasyNotePresented, onDismiss: {
            print("DEBUG: ChatView - EasyNote sheet dismissed")
        }) {
            NavigationView {
                EasyNoteSheet(prompt: $prompt, generateAction: {
                    print("DEBUG: ChatView - EasyNote generateAction called")
                    if !prompt.isEmpty {
                        print("DEBUG: ChatView - Processing EasyNote prompt, length: \(prompt.count)")
                        chatViewModel.handleGenerateAction(prompt: prompt)
                    } else {
                        print("DEBUG: ChatView - Empty prompt from EasyNote")
                    }
                })
            }
            .frame(minWidth: 1000, minHeight: 800)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    // MARK: - Helper Views
    
    struct MainChatContent: View {
        @Binding var prompt: String
        let messageViewModel: MessageViewModel
        let chatViewModel: ChatViewModel
        let fontSize: Double
        @FocusState var isFocused: Bool
        @Binding var isEasyNotePresented: Bool
        @Binding var isPreferencesPresented: Bool
        @Binding var showAddClientSheet: Bool
        @Binding var ollamaKit: OllamaKit
        let taskOptions: [String]
        let copyAction: (_ content: String) -> Void
        let generateAction: () -> Void
        let regenerateAction: () -> Void
        let onActiveChatChanged: () -> Void
        let updateSystemPrompt: () -> Void
        
        @State private var scrollProxy: ScrollViewProxy? = nil
        @Environment(CodeHighlighter.self) private var codeHighlighter
        @AppStorage("experimentalCodeHighlighting") private var experimentalCodeHighlighting = false
        
        var body: some View {
            ScrollViewReader { proxy in
                mainContentView(proxy: proxy)
            }
            .navigationTitle("")
            .toolbar {
                toolbarContent
            }
            .sheet(isPresented: $showAddClientSheet, onDismiss: {
                if let last = chatViewModel.clients.last {
                    chatViewModel.selectedClientID = last.id
                }
            }) {
                addClientSheet
            }
            .inspector(isPresented: $isPreferencesPresented) {
                inspectorContent
            }
            .onChange(of: chatViewModel.activeChat?.id) { oldValue, newValue in
                print("DEBUG: ChatView - Active chat changed: \(oldValue?.uuidString ?? "nil") -> \(newValue?.uuidString ?? "nil")")
                onActiveChatChanged()
            }
        }
        
        private func mainContentView(proxy: ScrollViewProxy) -> some View {
                VStack {
                    MessagesListView(
                        messages: messageViewModel.messages,
                        tempResponse: messageViewModel.tempResponse,
                        isGenerating: messageViewModel.loading == .generate,
                        copyAction: copyAction,
                        regenerateAction: regenerateAction
                    )
                    .scrollContentBackground(.hidden)
                    .background(Color.euniFieldBackground.opacity(0.5))
                    
                // Show RecordingView for Record Therapy Session activity, otherwise show ChatInputView
                if chatViewModel.getActivityTypeFromTask(chatViewModel.selectedTask) == .recordSession {
                    RecordingView()
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                        .padding(.horizontal)
                        .visible(if: chatViewModel.activeChat.isNotNil, removeCompletely: true)
                } else {
                    ChatInputView(
                        prompt: $prompt,
                        isEasyNotePresented: $isEasyNotePresented,
                        messageViewModel: messageViewModel,
                        chatViewModel: chatViewModel,
                        fontSize: fontSize,
                        isFocused: _isFocused,
                        generateAction: generateAction,
                        onActiveChatChanged: onActiveChatChanged
                    )
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    .visible(if: chatViewModel.activeChat.isNotNil, removeCompletely: true)
                }
                }
                .onAppear {
                    self.scrollProxy = proxy
                    
                    // Refresh models list to ensure picker shows current models
                    chatViewModel.fetchModelsFromBackend()
                }
                .onChange(of: chatViewModel.activeChat?.id) { _, _ in
                    onActiveChatChanged()
                }
                .onChange(of: messageViewModel.tempResponse) { _, _ in
                    if let proxy = scrollProxy {
                        scrollToBottom(proxy: proxy, messages: messageViewModel.messages)
                    }
                }
                .onChange(of: fontSize) { _, _ in
                    codeHighlighter.fontSize = fontSize
                }
                .onChange(of: experimentalCodeHighlighting) { _, _ in
                    codeHighlighter.enabled = experimentalCodeHighlighting
                }
            }
        
        @ToolbarContentBuilder
        private var toolbarContent: some ToolbarContent {
            if chatViewModel.isDPKNYMode {
                // DPKNY mode: only show the pencil/paper icon
                ToolbarItem(placement: .navigation) {
                    newSessionButton
                }
            } else {
                // Normal mode: show all toolbar items
                leftToolbarItems
                centerToolbarItem
                rightToolbarItems
            }
        }
        
        private var leftToolbarItems: some ToolbarContent {
                    ToolbarItem(placement: .navigation) {
                        HStack(spacing: 16) {
                    newSessionButton
                    activityPicker
                }
            }
        }
        
        private var newSessionButton: some View {
                            Button(action: {
                                chatViewModel.createNewActivity()
                                
                                // Ensure the view resets to the new activity
                                prompt = ""
                                if let newActivityId = chatViewModel.selectedActivityID {
                                    DispatchQueue.main.async {
                                        // Force loading the activity chat
                                        if let clientIndex = chatViewModel.clients.firstIndex(where: { $0.id == chatViewModel.selectedClientID }),
                                           let activity = chatViewModel.clients[clientIndex].activities.first(where: { $0.id == newActivityId }) {
                                            chatViewModel.loadActivityChat(activity)
                                            messageViewModel.load(of: chatViewModel.activeChat)
                                        }
                                    }
                                }
                            }) {
                                Image(systemName: "square.and.pencil")
                                    .foregroundColor(Color.euniPrimary)
                            }
                            .keyboardShortcut("n")
            .help(chatViewModel.isDPKNYMode ? "Start new brainstorm" : "Create new activity")
        }
                            
        private var activityPicker: some View {
                            VStack(spacing: 4) {
                                Text("Activity")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color.euniSecondary)
                
                Picker("Choose Activity", selection: activityPickerBinding) {
                                    ForEach(taskOptions, id: \.self) { task in
                                        Text(task).tag(task)
                                    }
                                }
                                .frame(width: 200)
                .onChange(of: chatViewModel.selectedTask) { _, newValue in
                    handleActivityChange(newValue)
                                }
                            }
                            .padding(.vertical, 8)
                        }
        
        private var activityPickerBinding: Binding<String> {
            Binding(
                get: { chatViewModel.selectedTask },
                set: { chatViewModel.selectedTask = $0 }
            )
        }
        
        private func handleActivityChange(_ newTask: String) {
            print("DEBUG: Toolbar selectedTask changed to '\(newTask)'")
            updateActiveEasySheet()
        }
        
        private func updateActiveEasySheet() {
            // This method updates the easy sheet type based on selected task
            // Implementation will be in the ChatFieldView where the state exists
        }
        
        private var centerToolbarItem: some ToolbarContent {
                    ToolbarItem(placement: .principal) {
                clientPicker
            }
        }
        
        private var clientPicker: some View {
                        VStack(spacing: 4) {
                            Text("Client")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color.euniSecondary)
                
                Picker("Choose Client", selection: clientPickerBinding) {
                    Text("Choose Client").tag(UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)
                    ForEach(chatViewModel.clients) { client in
                        Text(client.identifier).tag(client.id)
                    }
                    Text("Add New Client").tag(UUID(uuidString: "00000000-0000-0000-0000-000000000000")!)
                }
                .frame(width: 200)
                .onChange(of: chatViewModel.selectedClientID) { _, newValue in
                    handleClientChange(newValue)
                }
            }
            .padding(.vertical, 8)
        }
        
        private var clientPickerBinding: Binding<UUID> {
            Binding(
                                get: { chatViewModel.selectedClientID ?? UUID(uuidString: "00000000-0000-0000-0000-000000000001")! },
                                set: { newValue in
                                    if newValue == UUID(uuidString: "00000000-0000-0000-0000-000000000000") {
                                        showAddClientSheet = true
                                    } else if newValue != UUID(uuidString: "00000000-0000-0000-0000-000000000001") {
                                        chatViewModel.selectedClientID = newValue
                                    }
                                }
            )
        }
        
        private func handleClientChange(_ newClientID: UUID?) {
            print("DEBUG: Client selection changed to \(newClientID?.uuidString ?? "nil")")
            
            // Only call onClientSelected if we're actually switching to a valid client
            if let newValue = newClientID, 
               newValue != UUID(uuidString: "00000000-0000-0000-0000-000000000001") {
                chatViewModel.onClientSelected()
                    }
        }
        
        private var rightToolbarItems: some ToolbarContent {
                    ToolbarItem(placement: .automatic) {
                        HStack(spacing: 16) {
                    assistantPicker
                    ModeSelector()
                    preferencesButton
                }
                .padding(.vertical, 8)
            }
        }
        
        private var assistantPicker: some View {
            VStack(spacing: 4) {
                Text("Assistant")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.euniSecondary)

                // Check if OpenAI is selected
                if let serviceType = Defaults[.selectedAIServiceType],
                   (serviceType == .openAIUser || serviceType == .openAISubscription) {
                    // For OpenAI, just show "OpenAI" as text, no picker
                    Text("OpenAI")
                        .font(.system(size: 14))
                        .foregroundColor(Color.euniText)
                        .frame(width: 200, height: 28)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                } else {
                    // For Ollama, show the normal picker
                    Picker("Choose an Assistant", selection: assistantPickerBinding) {
                        ForEach(chatViewModel.models, id: \.self) { model in
                            // For LlamaCpp, models are already friendly names like "Flash"
                            // For OllamaKit, models are IDs like "qwen3:0.6b", so we convert them
                            let displayName = AssistantModel.nameFor(modelId: model)
                            Text(displayName).tag(model)
                        }
                    }
                    .frame(width: 200)
                }
            }
        }

        private var assistantPickerBinding: Binding<String> {
            Binding(
                get: { 
                    // Return the actual model value, ensuring it matches what's in the models array
                    let currentModel = chatViewModel.activeChat?.model ?? ""
                    // If current model is not in the models list, return the first available model
                    if !chatViewModel.models.contains(currentModel) && !chatViewModel.models.isEmpty {
                        return chatViewModel.models.first ?? ""
                    }
                    return currentModel
                },
                set: { newModel in
                    // Only update if the new model is valid and in our models list
                    if chatViewModel.models.contains(newModel) {
                        chatViewModel.activeChat?.model = newModel
                    }
                }
            )
        }
        
        private var preferencesButton: some View {
                            Button(action: { isPreferencesPresented.toggle() }) {
                                Image(systemName: "sidebar.trailing")
                            }
                            .help("Open preferences - configure AI settings and models")
                            .foregroundColor(Color.euniSecondary)
                        }
        
        private var addClientSheet: some View {
                NavigationStack {
                    AddClientView()
                }
                .frame(minWidth: 600, minHeight: 900)
            }
        
        private var inspectorContent: some View {
                ChatPreferencesView(ollamaKit: $ollamaKit)
                    .inspectorColumnWidth(min: 320, ideal: 320)
        }
        
        private func scrollToBottom(proxy: ScrollViewProxy, messages: [Message]) {
            guard messages.count > 0 else { return }
            guard let lastMessage = messages.last else { return }
            
            DispatchQueue.main.async {
                proxy.scrollTo(lastMessage, anchor: .bottom)
            }
        }
    }
    
    struct MessagesListView: View {
        let messages: [Message]
        let tempResponse: String
        let isGenerating: Bool
        let copyAction: (_ content: String) -> Void
        let regenerateAction: () -> Void
        
        var body: some View {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(messages) { message in
                        VStack(spacing: 16) {
                            UserMessageView(content: message.displayPrompt, copyAction: copyAction)
                            
                            if let response = message.response {
                                AssistantMessageView(
                                    content: response,
                                    isGenerating: false,
                                    isLastMessage: message == messages.last,
                                    copyAction: copyAction,
                                    regenerateAction: regenerateAction
                                )
                            } else if message == messages.last && isGenerating {
                                // Show thinking indicator for the last message with no response when generating
                                AssistantMessageView(
                                    content: tempResponse,
                                    isGenerating: true,
                                    isLastMessage: true,
                                    copyAction: copyAction,
                                    regenerateAction: regenerateAction
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Only show this if tempResponse is not empty and not already shown above
                    if !tempResponse.isEmpty && (messages.isEmpty || messages.last?.response != nil) {
                        AssistantMessageView(
                            content: tempResponse,
                            isGenerating: true,
                            isLastMessage: true,
                            copyAction: copyAction,
                            regenerateAction: regenerateAction
                        )
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
        }
    }
    
    struct ChatInputView: View {
        @Binding var prompt: String
        @Binding var isEasyNotePresented: Bool
        let messageViewModel: MessageViewModel
        let chatViewModel: ChatViewModel
        let fontSize: Double
        @FocusState var isFocused: Bool
        let generateAction: () -> Void
        let onActiveChatChanged: () -> Void
        
        var body: some View {
            VStack {
                ChatFieldView(
                    prompt: $prompt,
                    isEasyNotePresented: $isEasyNotePresented,
                    messageViewModel: messageViewModel,
                    chatViewModel: chatViewModel,
                    fontSize: fontSize,
                    isFocused: _isFocused,
                    generateAction: generateAction,
                    onActiveChatChanged: onActiveChatChanged
                )
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func onActiveChatChanged() {
        print("DEBUG: ChatView - onActiveChatChanged called")
        self.prompt = ""
        if chatViewModel.shouldFocusPrompt {
            chatViewModel.shouldFocusPrompt = false
            Task {
                try await Task.sleep(for: .seconds(0.8))
                withAnimation {
                    self.isFocused = true
                }
            }
        }

        // Only check Ollama connection if OllamaKit is the selected backend
        let selectedBackend = Defaults[.selectedAIBackend]
        print("DEBUG: ChatView - Selected backend: \(selectedBackend.displayName)")
        
        if selectedBackend == .ollamaKit {
        if let activeChat = chatViewModel.activeChat, 
           let host = activeChat.host, 
           let baseURL = URL(string: host) {
                print("DEBUG: ChatView - Using OllamaKit, updating with host: \(host)")
            self.ollamaKit = OllamaKit(baseURL: baseURL)
            
            // Check Ollama connection with retry
            Task {
                var retryCount = 0
                let maxRetries = 3
                
                while retryCount < maxRetries {
                    do {
                        let isReachable = await ollamaKit.reachable()
                        if isReachable {
                            print("DEBUG: ChatView - Successfully connected to Ollama")
                            self.chatViewModel.isHostReachable = true
                            self.chatViewModel.fetchModels(self.ollamaKit)
                            break
                        } else {
                            print("DEBUG: ChatView - Ollama not reachable, attempt \(retryCount + 1) of \(maxRetries)")
                            self.chatViewModel.isHostReachable = false
                            retryCount += 1
                            if retryCount < maxRetries {
                                try await Task.sleep(for: .seconds(2))
                            }
                        }
                    } catch {
                        print("DEBUG: ChatView - Error connecting to Ollama: \(error)")
                        retryCount += 1
                        if retryCount < maxRetries {
                            try await Task.sleep(for: .seconds(2))
                        }
                    }
                }
                
                if retryCount >= maxRetries {
                    print("DEBUG: ChatView - Failed to connect to Ollama after \(maxRetries) attempts")
                    // Update UI to show connection error
                    DispatchQueue.main.async {
                        self.chatViewModel.error = .fetchModels("Unable to connect to Ollama server after multiple attempts. Please verify that Ollama is running and accessible at \(host)")
                    }
                }
            }
            }
        } else if selectedBackend == .openAI {
            print("DEBUG: ChatView - Using OpenAI backend")
            // When using OpenAI, fetch models from the backend manager
            self.chatViewModel.fetchModelsFromBackend()
        } else {
            print("DEBUG: ChatView - Using other backend: \(selectedBackend.displayName)")
            // For other backends, fetch models from the backend manager
            self.chatViewModel.fetchModelsFromBackend()
        }
    }
    
    private func copyAction(_ content: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
    }
    
    private func generateAction() {
        print("DEBUG: ChatView - generateAction called")
        guard let activeChat = chatViewModel.activeChat, 
              !activeChat.model.isEmpty, 
              chatViewModel.isHostReachable else {
            print("DEBUG: ChatView - Cannot generate: activeChat=\(chatViewModel.activeChat != nil), model=\(chatViewModel.activeChat?.model ?? "nil"), reachable=\(chatViewModel.isHostReachable)")
            return
        }

        if messageViewModel.loading == .generate {
            print("DEBUG: ChatView - Cancelling existing generation")
            messageViewModel.cancelGeneration()
        } else {
            let promptToSend = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !promptToSend.isEmpty else {
                print("DEBUG: ChatView - Empty prompt, clearing")
                self.prompt = ""
                return
            }

            // Verify that the system prompt matches the selected activity type
            let activityType = chatViewModel.getActivityTypeFromTask(chatViewModel.selectedTask)
            let expectedPrompt = chatViewModel.getSystemPromptForActivityType(activityType)
            
            if activityType == .brainstorm && activeChat.systemPrompt != expectedPrompt {
                print("DEBUG: ChatView - Correcting system prompt for Brainstorm before generating")
                activeChat.systemPrompt = expectedPrompt
            }
            
            print("DEBUG: ChatView - Generating with prompt length: \(promptToSend.count) for activity type: \(activityType.rawValue)")
            print("DEBUG: ChatView - Prompt preview: \(String(promptToSend.prefix(100)))...")
            
            // Use the new method to handle generation properly
            chatViewModel.handleGenerateAction(prompt: promptToSend)
        }
        
        self.prompt = ""
    }
    
    private func regenerateAction() {
        guard let activeChat = chatViewModel.activeChat, !activeChat.model.isEmpty, chatViewModel.isHostReachable else { return }
        
        if messageViewModel.loading == .generate {
            messageViewModel.cancelGeneration()
        } else {
            guard let activeChat = chatViewModel.activeChat else { return }
            
            messageViewModel.regenerate(activeChat: activeChat)
        }
        
        prompt = ""
    }
}

struct ChatFieldView: View {
    @Binding var prompt: String
    @Binding var isEasyNotePresented: Bool
    let messageViewModel: MessageViewModel
    let chatViewModel: ChatViewModel
    let fontSize: Double
    @FocusState var isFocused: Bool
    let generateAction: () -> Void
    let onActiveChatChanged: () -> Void
    @State private var speechRecognitionVM = SpeechRecognitionViewModel()
    @State private var textHeight: CGFloat = 40
    
    // Add state for tracking which easy sheet to show
    @State private var activeEasySheet: EasySheetType = .none
    @State private var showEasySheet = false
    
    // Enum to track which sheet to show
    private enum EasySheetType {
        case note
        case treatmentPlan
        case none
    }
    
    private var showEasyButton: Bool {
        // Hide Easy button in DPKNY mode to keep interface simple
        !chatViewModel.isDPKNYMode &&
        (chatViewModel.selectedTask.contains("Session Note") ||
         chatViewModel.selectedTask.contains("Treatment Plan"))
    }
    
    private var easyButtonIcon: String {
        switch chatViewModel.selectedTask {
        case "Create a Client Session Note":
            return "note.text.badge.plus"
        case "Create a Treatment Plan":
            return "checklist.checked"
        default:
            return "note.text.badge.plus"
        }
    }
    
    private var easyButtonLabel: String {
        switch chatViewModel.selectedTask {
        case "Create a Client Session Note":
            return "Easy Note"
        case "Create a Treatment Plan":
            return "Easy Plan"
        default:
            return "Easy Note"
        }
    }
    
    private func handleEasyButtonTap() {
        print("DEBUG: Easy button clicked for task: \(chatViewModel.selectedTask)")
        updateActiveEasySheet()
        showEasySheet = true
        print("DEBUG: showEasySheet set to true")
    }
    
    private func updateActiveEasySheet() {
        switch chatViewModel.selectedTask {
        case "Create a Client Session Note":
            print("DEBUG: Setting activeEasySheet to .note")
            activeEasySheet = .note
        case "Create a Treatment Plan":
            print("DEBUG: Setting activeEasySheet to .treatmentPlan")
            activeEasySheet = .treatmentPlan
        default:
            print("DEBUG: Setting activeEasySheet to .none")
            activeEasySheet = .none
        }
    }
    
    var body: some View {
        VStack {
            mainChatFieldContent
            footerContent
        }
        .alert("Microphone Access Required", isPresented: $speechRecognitionVM.showingPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                    NSWorkspace.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please grant microphone access in System Settings to use voice input.")
        }
        .alert("Speech Recognition Error", isPresented: $speechRecognitionVM.showingErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(speechRecognitionVM.errorMessage)
        }
        .onAppear {
            updateActiveEasySheet()
        }
        .onChange(of: chatViewModel.selectedTask) { oldValue, newValue in
            handleTaskChange(oldValue: oldValue, newValue: newValue)
        }
        .sheet(isPresented: $showEasySheet, onDismiss: {
            print("DEBUG: Sheet dismissed, activeEasySheet was: \(activeEasySheet)")
            activeEasySheet = .none
            print("DEBUG: Reset activeEasySheet to .none")
        }) {
            easySheetContent
        }
    }
    
    private var mainChatFieldContent: some View {
            HStack(alignment: .top, spacing: 8) {
            leftColumnButtons
            chatTextEditor
            sendButton
        }
        .padding(8)
        .background(Color.euniFieldBackground)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.euniBorder, lineWidth: 1)
        )
    }
    
    private var leftColumnButtons: some View {
                VStack(spacing: 8) {
                if showEasyButton {
                        Button(action: handleEasyButtonTap) {
                            Image(systemName: easyButtonIcon)
                                .foregroundStyle(.white)
                                .fontWeight(.bold)
                                .padding(8)
                        }
                        .help("\(easyButtonLabel) - Quick form to create structured \(chatViewModel.selectedTask.lowercased())")
                        .background(Color.euniPrimary)
                        .buttonStyle(.borderless)
                        .clipShape(.circle)
                    }
                        
                        Button {
                            if speechRecognitionVM.isRecording {
                                speechRecognitionVM.stopRecording()
                            } else {
                                speechRecognitionVM.startRecording { transcribedText in
                                    prompt = transcribedText
                                }
                            }
                        } label: {
                            Image(systemName: speechRecognitionVM.isRecording ? "stop.circle.fill" : "mic.circle")
                                .foregroundStyle(Color.euniText)
                                .fontWeight(.bold)
                                .padding(8)
                        }
                        .help(speechRecognitionVM.isRecording ? "Stop voice recording" : "Start voice recording - speak your prompt")
                        .background(speechRecognitionVM.isRecording ? Color.euniError : Color.euniSecondary)
                        .buttonStyle(.borderless)
                        .clipShape(.circle)
        }
                }
                
    private var chatTextEditor: some View {
                TextEditor(text: $prompt)
                    .font(.system(size: fontSize))
                    .frame(height: max(40, textHeight))
                    .scrollContentBackground(.hidden)
                    .background(Color.euniFieldBackground)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.euniBorder, lineWidth: 1)
                    )
                    .focused($isFocused)
                    .onChange(of: prompt) { _, newValue in
                updateTextHeight(for: newValue)
                    }
                    .onSubmit {
                handleSubmit()
            }
            .onKeyPress(.return) {
                return handleReturnKey()
                        }
                    }
                
    private var sendButton: some View {
                Button(action: generateAction) {
                    Image(systemName: messageViewModel.loading == .generate ? "stop.fill" : "arrow.up")
                        .foregroundStyle(Color.euniText)
                        .fontWeight(.bold)
                        .padding(8)
                }
                .background(messageViewModel.loading == .generate ? Color.euniError : Color.euniPrimary)
                .buttonStyle(.borderless)
                .clipShape(.circle)
                .disabled(prompt.isEmpty && messageViewModel.loading != .generate)
            }
    
    private var footerContent: some View {
        Group {
            if chatViewModel.loading != nil {
                ProgressView()
                    .controlSize(.small)
            } else if case .fetchModels(let message) = chatViewModel.error {
                HStack {
                    Text(message)
                        .foregroundStyle(.red)
                    
                    Button("Try Again", action: onActiveChatChanged)
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                }
                .font(.callout)
            } else if messageViewModel.messages.isEmpty == false {
                HStack {
                Text("\u{2318}+R to regenerate the response")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    dpknyToggleButton
                }
            } else {
                HStack {
                Text("AI can make mistakes. Please double-check responses.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    dpknyToggleButton
                }
            }
        }
    }
    
    private var dpknyToggleButton: some View {
        Toggle("DPKNY", isOn: Binding(
            get: { chatViewModel.isDPKNYMode },
            set: { _ in chatViewModel.toggleDPKNYMode() }
        ))
        .toggleStyle(.button)
        .buttonStyle(.borderless)
        .font(.caption)
        .foregroundColor(chatViewModel.isDPKNYMode ? .white : .secondary)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(chatViewModel.isDPKNYMode ? Color.euniPrimary : Color.clear)
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .help("Super Simple Mode to chat directly with the AI")
    }
    
    @ViewBuilder
    private var easySheetContent: some View {
            switch activeEasySheet {
            case .note:
                NavigationView {
                    EasyNoteSheet(prompt: $prompt, generateAction: {
                        if !prompt.isEmpty {
                            generateAction()
                        }
                    })
                }
                .frame(minWidth: 1000, minHeight: 800)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .treatmentPlan:
                NavigationView {
                    EasyTreatmentPlanSheet(prompt: $prompt, generateAction: generateAction)
                }
                .frame(minWidth: 1000, minHeight: 800)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .none:
                EmptyView()
            }
        }
    
    private func updateTextHeight(for text: String) {
        let size = CGSize(width: NSScreen.main?.frame.width ?? 800 - 100, height: .infinity)
        let estimatedHeight = text.boundingRect(
            with: size,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: NSFont.systemFont(ofSize: fontSize)],
            context: nil
        ).height
        textHeight = min(max(40, estimatedHeight + 20), 200)
    }
    
    private func handleTaskChange(oldValue: String, newValue: String) {
        print("DEBUG: ChatFieldView - selectedTask changed from '\(oldValue)' to '\(newValue)'")
        
        // Update activeEasySheet whenever the task changes
        updateActiveEasySheet()
        
        // Check if we're switching between different activity types
        let oldActivityType = chatViewModel.getActivityTypeFromTask(oldValue)
        let newActivityType = chatViewModel.getActivityTypeFromTask(newValue)
        
        print("DEBUG: ChatFieldView Activity type change: \(oldActivityType.rawValue) → \(newActivityType.rawValue)")
        
        // If we're switching to a different activity type, force a clean start
        if oldActivityType != newActivityType {
            print("DEBUG: ChatFieldView - Forcing clean activity type transition")
            chatViewModel.clearChatForNewActivityType()
        }
    }
    
    private func handleSubmit() {
        print("DEBUG: TextEditor onSubmit triggered")
        if messageViewModel.loading != .generate && !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            print("DEBUG: Submitting via Enter key")
            generateAction()
        }
    }
    
    private func handleReturnKey() -> KeyPress.Result {
        print("DEBUG: Return key pressed")
        
        // Send the message when Enter is pressed (without modifiers)
        let promptToSend = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !promptToSend.isEmpty && messageViewModel.loading != .generate {
            print("DEBUG: Sending message via Enter key")
            generateAction()
            return .handled
        }
        
        return .ignored
    }
}

//
//  RecordingViewModel.swift
//  ClientNote
//
//  Extracted from ChatView.swift
//  Handles voice recording with real-time transcription
//

import Foundation
import AVFoundation
import Speech
import Combine

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

// MARK: - Live Recorder

/// Handles live audio recording with automatic segmentation and real-time transcription
class LiveRecorder: NSObject {
    // MARK: - Properties

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

    // MARK: - Initialization

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

    // MARK: - Public Methods

    /// Start recording audio with real-time transcription
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

    /// Stop recording and clean up resources
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

    // MARK: - Private Methods

    /// Start a new recording segment
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

    /// Setup speech recognition for the current segment
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

    /// Finish the current recording segment
    private func finishCurrentSegment() {
        // End the current speech recognition request
        recognitionRequest?.endAudio()
    }
}

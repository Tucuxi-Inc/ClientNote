import SwiftUI
import Speech
import AVFoundation

struct EasyNoteSheet: View {
    @Binding var prompt: String
    let generateAction: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    // Note Format
    @State private var selectedNoteFormat = "BIRP"
    @State private var customNoteFormat = ""
    
    // Therapeutic Approach
    @State private var selectedApproach = "CBT"
    @State private var selectedInterventions: Set<String> = []
    
    // Other fields
    @State private var presentingIssue = "Anxiety"
    @State private var customPresentingIssue = ""
    @State private var clientResponse = "Engaged and cooperative"
    @State private var customClientResponse = ""
    @State private var clinicalFocus = "Cognitive distortions"
    @State private var customClinicalFocus = ""
    @State private var treatmentGoals = "Reduce anxiety symptoms"
    @State private var customTreatmentGoals = ""
    
    // Additional Notes
    @State private var additionalNotes = ""
    @State private var isRecording = false
    @State private var speechRecognizer: SFSpeechRecognizer?
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var audioEngine = AVAudioEngine()
    @State private var showingPermissionAlert = false
    @State private var showingNetworkAlert = false
    @State private var networkErrorMessage = ""
    
    private let noteFormats = ["BIRP", "PIRP", "SOAP", "DAP", "Other"]
    private let approaches = ["CBT", "DBT", "ACT", "Psychodynamic", "Person-Centered", "EMDR", "IFS"]
    private let presentingIssues = ["Anxiety", "Depression", "Trauma", "Relationship conflict", "Emotional dysregulation", "Grief", "Identity exploration", "Other"]
    private let clientResponses = ["Engaged and cooperative", "Resistant but participated", "Emotionally activated", "Demonstrated insight", "Avoidant or withdrawn", "Expressed ambivalence", "Other"]
    private let clinicalFocuses = ["Cognitive distortions", "Maladaptive schemas", "Emotional regulation", "Attachment patterns", "Trauma processing", "Behavioral change", "Other"]
    private let treatmentGoalsList = ["Reduce anxiety symptoms", "Increase emotional resilience", "Improve interpersonal functioning", "Develop insight into patterns", "Increase acceptance and psychological flexibility", "Other"]
    
    private var interventions: [String: [String]] = [
        "CBT": ["Cognitive restructuring", "Socratic questioning", "Thought records", "Identifying automatic thoughts", "Behavioral activation", "Schema identification"],
        "DBT": ["Mindfulness training", "Distress tolerance", "Emotion regulation skills", "Interpersonal effectiveness", "Diary card review", "Chain analysis"],
        "ACT": ["Values clarification", "Cognitive defusion", "Acceptance techniques", "Present-moment awareness", "Committed action planning", "Self-as-context work"],
        "Psychodynamic": ["Exploring defense mechanisms", "Attachment pattern analysis", "Transference/Countertransference exploration", "Insight development", "Free association", "Interpretation of unconscious material"],
        "Person-Centered": ["Reflective listening", "Unconditional positive regard", "Empathic responding", "Genuineness/congruence", "Encouraging self-exploration"],
        "EMDR": ["Bilateral stimulation", "Desensitization of trauma", "Resource development", "Installation of positive cognition", "Assessment of SUDs/VoC", "Target sequencing"],
        "IFS": ["Identifying parts", "Unblending techniques", "Facilitating Self-to-part connection", "Mapping internal system", "Direct access and witnessing parts"]
    ]
    
    init(prompt: Binding<String>, generateAction: @escaping () -> Void) {
        self._prompt = prompt
        self.generateAction = generateAction
    }
    
    var body: some View {
        NavigationView {
            HSplitView {
                // Left column - Form fields
                Form {
                    Section("Note Format") {
                        Picker("Format", selection: $selectedNoteFormat) {
                            ForEach(noteFormats, id: \.self) { format in
                                Text(format).tag(format)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        if selectedNoteFormat == "Other" {
                            TextField("Custom Format", text: $customNoteFormat)
                        }
                    }
                    
                    Section("Therapeutic Approach") {
                        Picker("Approach", selection: $selectedApproach) {
                            ForEach(approaches, id: \.self) { approach in
                                Text(approach).tag(approach)
                            }
                        }
                        
                        if let approachInterventions = interventions[selectedApproach] {
                            ForEach(approachInterventions, id: \.self) { intervention in
                                Toggle(intervention, isOn: Binding(
                                    get: { selectedInterventions.contains(intervention) },
                                    set: { isSelected in
                                        if isSelected {
                                            selectedInterventions.insert(intervention)
                                        } else {
                                            selectedInterventions.remove(intervention)
                                        }
                                    }
                                ))
                            }
                        }
                    }
                    
                    Section("Presenting Issue") {
                        Picker("Issue", selection: $presentingIssue) {
                            ForEach(presentingIssues, id: \.self) { issue in
                                Text(issue).tag(issue)
                            }
                        }
                        
                        if presentingIssue == "Other" {
                            TextField("Custom Issue", text: $customPresentingIssue)
                        }
                    }
                    
                    Section("Client Response") {
                        Picker("Response", selection: $clientResponse) {
                            ForEach(clientResponses, id: \.self) { response in
                                Text(response).tag(response)
                            }
                        }
                        
                        if clientResponse == "Other" {
                            TextField("Custom Response", text: $customClientResponse)
                        }
                    }
                    
                    Section("Clinical Focus") {
                        Picker("Focus", selection: $clinicalFocus) {
                            ForEach(clinicalFocuses, id: \.self) { focus in
                                Text(focus).tag(focus)
                            }
                        }
                        
                        if clinicalFocus == "Other" {
                            TextField("Custom Focus", text: $customClinicalFocus)
                        }
                    }
                    
                    Section("Treatment Goals") {
                        Picker("Goals", selection: $treatmentGoals) {
                            ForEach(treatmentGoalsList, id: \.self) { goal in
                                Text(goal).tag(goal)
                            }
                        }
                        
                        if treatmentGoals == "Other" {
                            TextField("Custom Goals", text: $customTreatmentGoals)
                        }
                    }
                }
                .frame(minWidth: 300, maxWidth: 400)
                
                // Right column - Additional Notes
                VStack {
                    Text("Additional Notes")
                        .font(.headline)
                        .padding(.top)
                    
                    TextEditor(text: $additionalNotes)
                        .font(.body)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(8)
                        .background(Color(.textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding()
                    
                    HStack {
                        Button(action: {
                            if isRecording {
                                stopRecording()
                            } else {
                                startRecording()
                            }
                        }) {
                            Label(isRecording ? "Stop Recording" : "Start Recording", 
                                  systemImage: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                .foregroundColor(isRecording ? .red : .blue)
                        }
                        .buttonStyle(.bordered)
                        .padding(.bottom)
                        
                        if isRecording {
                            Text("Recording...")
                                .foregroundColor(.red)
                                .padding(.bottom)
                        }
                    }
                }
                .frame(minWidth: 300, maxWidth: .infinity)
                .padding()
            }
            .navigationTitle("Easy Note")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        cleanupResources()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Generate Note") {
                        generatePrompt()
                        generateAction()
                        cleanupResources()
                        dismiss()
                    }
                }
            }
            .alert("Microphone Access Required", isPresented: $showingPermissionAlert) {
                Button("Open Settings") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Please enable microphone access in System Settings to use voice input.")
            }
            .alert("Speech Recognition Error", isPresented: $showingNetworkAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(networkErrorMessage)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            resetState()
            requestSpeechRecognitionPermission()
        }
        .onDisappear {
            cleanupResources()
        }
    }
    
    private func resetState() {
        // Reset all state variables to their initial values
        selectedNoteFormat = "BIRP"
        customNoteFormat = ""
        selectedApproach = "CBT"
        selectedInterventions = []
        presentingIssue = "Anxiety"
        customPresentingIssue = ""
        clientResponse = "Engaged and cooperative"
        customClientResponse = ""
        clinicalFocus = "Cognitive distortions"
        customClinicalFocus = ""
        treatmentGoals = "Reduce anxiety symptoms"
        customTreatmentGoals = ""
        additionalNotes = ""
        isRecording = false
        showingPermissionAlert = false
        showingNetworkAlert = false
        networkErrorMessage = ""
    }
    
    private func cleanupResources() {
        // Stop recording if active
        if isRecording {
            stopRecording()
        }
        
        // Clean up speech recognition resources
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        // Reset audio engine
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        // Reset speech recognizer
        speechRecognizer = nil
    }
    
    private func requestSpeechRecognitionPermission() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    print("Speech recognition authorized")
                    // Initialize speech recognizer after authorization
                    self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
                    if let recognizer = self.speechRecognizer {
                        if recognizer.isAvailable {
                            print("Speech recognition is available")
                        } else {
                            print("Speech recognition is not available on this device")
                            self.showingPermissionAlert = true
                        }
                    } else {
                        print("Failed to initialize speech recognizer")
                        self.showingPermissionAlert = true
                    }
                case .denied:
                    print("Speech recognition permission denied")
                    self.showingPermissionAlert = true
                case .restricted:
                    print("Speech recognition is restricted on this device")
                    self.showingPermissionAlert = true
                case .notDetermined:
                    print("Speech recognition authorization not determined")
                    self.showingPermissionAlert = true
                @unknown default:
                    print("Unknown authorization status")
                    self.showingPermissionAlert = true
                }
            }
        }
    }
    
    private func startRecording() {
        guard let recognizer = speechRecognizer else {
            print("Speech recognizer not initialized")
            return
        }
        
        guard recognizer.isAvailable else {
            print("Speech recognition is not available")
            networkErrorMessage = "Speech recognition is not available on this device."
            showingNetworkAlert = true
            return
        }
        
        do {
            if audioEngine.isRunning {
                audioEngine.stop()
                recognitionRequest?.endAudio()
                isRecording = false
                return
            }
            
            // Reset any existing task
            recognitionTask?.cancel()
            recognitionTask = nil
            
            let inputNode = audioEngine.inputNode
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            
            guard let recognitionRequest = recognitionRequest else {
                print("Unable to create recognition request")
                networkErrorMessage = "Unable to create recognition request. Please try again."
                showingNetworkAlert = true
                return
            }
            
            recognitionRequest.shouldReportPartialResults = true
            
            recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [self] result, error in
                if let error = error {
                    print("Recognition error: \(error.localizedDescription)")
                    if let error = error as NSError? {
                        print("Error domain: \(error.domain)")
                        print("Error code: \(error.code)")
                        
                        // Handle specific error cases
                        switch (error.domain, error.code) {
                        case ("kLSRErrorDomain", 301):
                            // This is a normal cancellation when stopping recording
                            print("Recognition request canceled (normal)")
                            return
                        case ("kAFAssistantErrorDomain", 1101):
                            // Local speech recognition error
                            print("Local speech recognition error: \(error.localizedDescription)")
                            return
                        case (_, 1110):
                            // Only show "No speech detected" error if we're still recording
                            // and haven't received any results yet
                            if isRecording && additionalNotes.isEmpty {
                                networkErrorMessage = "No speech detected. Please try speaking again."
                                showingNetworkAlert = true
                            }
                        default:
                            // Only show error alert for unexpected errors
                            if !isRecording {
                                // Don't show errors if we're stopping recording
                                return
                            }
                            networkErrorMessage = "Speech recognition error: \(error.localizedDescription)"
                            showingNetworkAlert = true
                        }
                    }
                    self.stopRecording()
                    return
                }
                
                guard let result = result else {
                    print("No recognition result available")
                    return
                }
                
                print("Received recognition result: \(result.bestTranscription.formattedString)")
                
                DispatchQueue.main.async {
                    // Only update if we have content to avoid clearing the field
                    if !result.bestTranscription.formattedString.isEmpty {
                        self.additionalNotes = result.bestTranscription.formattedString
                    }
                }
                
                if result.isFinal {
                    print("Recognition completed with final result")
                    // Don't stop recording here, let the user control it
                }
            }
            
            guard recognitionTask != nil else {
                print("Failed to create recognition task")
                networkErrorMessage = "Failed to create recognition task. Please try again."
                showingNetworkAlert = true
                return
            }
            
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                recognitionRequest.append(buffer)
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true
            print("Recording started successfully")
            
        } catch {
            print("Error starting recording: \(error.localizedDescription)")
            if let error = error as NSError? {
                print("Error domain: \(error.domain)")
                print("Error code: \(error.code)")
                networkErrorMessage = "Error starting recording: \(error.localizedDescription)"
                showingNetworkAlert = true
            }
            stopRecording()
        }
    }
    
    private func stopRecording() {
        print("Stopping recording...")
        
        // Cancel the recognition task first to prevent error messages
        recognitionTask?.cancel()
        recognitionTask = nil
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        isRecording = false
        print("Recording stopped")
    }
    
    private func generatePrompt() {
        let noteFormat = selectedNoteFormat == "Other" ? customNoteFormat : selectedNoteFormat
        let presentingIssueText = presentingIssue == "Other" ? customPresentingIssue : presentingIssue
        let clientResponseText = clientResponse == "Other" ? customClientResponse : clientResponse
        let clinicalFocusText = clinicalFocus == "Other" ? customClinicalFocus : clinicalFocus
        let treatmentGoalsText = treatmentGoals == "Other" ? customTreatmentGoals : treatmentGoals
        
        let interventionsText = selectedInterventions.isEmpty ? 
            "No specific interventions selected" : 
            selectedInterventions.joined(separator: ", ")
        
        var promptText = """
        You are a clinical documentation assistant helping a therapist generate an insurance-ready psychotherapy progress note using the \(noteFormat) format.

        Guidelines:
        – Use clear, objective, and concise clinical language  
        – Maintain gender-neutral pronouns  
        – Focus on observable behaviors, reported thoughts and feelings, therapist interventions, and clinical goals  
        – Apply relevant concepts from \(selectedApproach), including typical interventions and session themes  
        – Use documentation language suitable for EHRs and insurance billing  
        – If schemas, distortions, or core beliefs are addressed, name them using standard psychological terms  
        – Conclude with a brief, action-oriented treatment plan

        Session Context:
        Client presented with \(presentingIssueText).  
        Therapeutic approach used: \(selectedApproach)  
        Therapist interventions included: \(interventionsText)  
        Client response: \(clientResponseText)  
        Clinical focus: \(clinicalFocusText)  
        Treatment goal(s): \(treatmentGoalsText)
        """
        
        if !additionalNotes.isEmpty {
            promptText += "\n\nAdditional Notes:\n\(additionalNotes)"
        }
        
        promptText += "\n\nNow generate the note."
        
        prompt = promptText
    }
}

struct EasyNoteSheet_Previews: PreviewProvider {
    static var previews: some View {
        EasyNoteSheet(prompt: .constant(""), generateAction: {})
    }
}

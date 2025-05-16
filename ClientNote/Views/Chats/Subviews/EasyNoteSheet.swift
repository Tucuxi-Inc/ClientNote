import SwiftUI
import Speech
import AVFoundation
import OllamaKit
import Defaults

// MARK: - ICDResult Model
struct ICDResult: Identifiable {
    let id = UUID()
    let code: String
    let description: String
}

struct EasyNoteSheet: View {
    @Binding var prompt: String
    let generateAction: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(ChatViewModel.self) private var chatViewModel
    @Environment(MessageViewModel.self) private var messageViewModel
    @State private var ollamaKit: OllamaKit
    
    // Add a new property to store the chat entry text
    @State private var chatEntryText: String = ""
    
    // Add a new property to store the full prompt
    @State private var fullPrompt: String = ""
    
    // Date and Time fields
    @State private var selectedDate = Date()
    @State private var selectedTime = Date()
    
    // Note Format
    @State private var selectedNoteFormat = "BIRP"
    @State private var customNoteFormat = ""
    
    // Therapeutic Approach
    @State private var selectedApproach = "CBT (Cognitive Behavioral Therapy)"
    @State private var customApproach = ""
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
    
    // Location field
    @State private var selectedLocation = "In-Person"
    private let locations = ["In-Person", "First Telehealth Visit", "Subsequent Telehealth Visit"]
    
    // Insurance Code/Diagnosis Fields
    @State private var insuranceQuery = ""
    @State private var icdResults: [ICDResult] = []
    @State private var selectedICDCode = ""
    @State private var selectedICDDescription = ""
    @State private var isSearchingICD = false
    @State private var icdSearchError: String? = nil
    
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
    
    // Suicidal Ideation or Self-Harm
    @State private var hasSuicidalIdeation = false
    @State private var suicidalIdeationPastSession = false
    @State private var suicidalIdeationCurrentSession = false
    @State private var suicidalIdeationBothSessions = false
    
    private let noteFormats = ["BIRP", "PIRP", "SOAP", "DAP", "Other"]
    private let approaches = [
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
    private let presentingIssues = ["Anxiety", "Depression", "Trauma", "Relationship conflict", "Emotional dysregulation", "Grief", "Identity exploration", "Other"]
    private let clientResponses = ["Engaged and cooperative", "Resistant but participated", "Emotionally activated", "Demonstrated insight", "Avoidant or withdrawn", "Expressed ambivalence", "Other"]
    private let clinicalFocuses = ["Cognitive distortions", "Maladaptive schemas", "Emotional regulation", "Attachment patterns", "Trauma processing", "Behavioral change", "Other"]
    private let treatmentGoalsList = ["Reduce anxiety symptoms", "Increase emotional resilience", "Improve interpersonal functioning", "Develop insight into patterns", "Increase acceptance and psychological flexibility", "Other"]
    
    // Enhanced Therapeutic Approaches and Interventions Dictionary
    private var interventions: [String: [String]] = [
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
            ],
            "EMDR (Eye Movement Desensitization and Reprocessing)": [
                "Bilateral stimulation",
                "Desensitization of trauma",
                "Resource development",
                "Installation of positive cognition",
                "Assessment of SUDs/VoC",
                "Target sequencing",
                "Trauma narrative reprocessing"
            ],
            "IFS (Internal Family Systems)": [
                "Identifying parts (e.g., exile, manager, firefighter)",
                "Unblending techniques",
                "Facilitating Self-to-part connection",
                "Mapping internal system",
                "Direct access and witnessing parts",
                "Self-to-part communication",
                "Unburdening process",
                "Parts dialogue",
                "Integration of parts"
            ],
            "Solution-Focused Brief Therapy (SFBT)": [
                "Miracle question",
                "Scaling questions",
                "Exception-finding",
                "Coping questions",
                "SMART goal setting",
                "Complimenting strengths",
                "Future-focused narrative building",
                "Visualization of preferred future",
                "Resource and Strength Mapping"
            ],
            "Narrative Therapy": [
                "Externalizing the problem",
                "Mapping problem influence",
                "Exploring dominant story effects",
                "Double-listening (trauma + resilience)",
                "Re-authoring preferred narratives",
                "Therapeutic letter writing",
                "Re-membering conversations",
                "Identifying unique outcomes"
            ],
            "TF-CBT (Trauma-Focused Cognitive Behavioral Therapy)": [
                "Psychoeducation about trauma",
                "Feelings thermometer / emotion wheels",
                "Relaxation techniques",
                "Cognitive coping (CBT triangle, logs)",
                "Trauma narrative (storytelling, drawing)",
                "In vivo exposure",
                "Caregiver-child conjoint sessions",
                "Cognitive restructuring worksheets",
                "Safety planning"
            ],
            "Behavioral Therapy": [
                "Systematic desensitization",
                "Counterconditioning",
                "Reinforcement (positive/negative)",
                "Punishment protocols",
                "Behavioral activation",
                "Graded exposure",
                "Contingency management",
                "Self-monitoring (ABC model, diaries)",
                "Functional behavior analysis",
                "Social skills training"
            ],
            "Motivational Interviewing (MI)": [
                "OARS (Open questions, Affirmations, Reflective listening, Summarizing)",
                "Confidence rulers / readiness rulers",
                "Decisional balance",
                "Exploring values-discrepancy",
                "Change talk elicitation",
                "Rolling with resistance",
                "SMART goal setting"
            ],
            "Play Therapy": [
                "Sand tray and miniatures",
                "Puppets and symbolic play",
                "Dollhouse / role play",
                "Therapeutic board games",
                "Emotion flashcards",
                "Art therapy (drawing, clay)",
                "Storytelling and narrative play",
                "Co-regulation through grounding",
                "Bibliotherapy",
                "Processing trauma through play"
            ],
            "Gottman Method Couples Therapy": [
                "Love Maps",
                "Fondness and admiration exercises",
                "Four Horsemen framework",
                "Stress-reducing conversation",
                "Positive Perspective",
                "Managing conflict (soft start-up, repair attempts)",
                "Creating shared meaning",
                "5:1 interaction ratio",
                "Dreams and values discussion"
            ],
            "Integrative Family and Couple Therapy (IFCT)": [
                "Genograms and relational mapping",
                "Identifying conflict cycles",
                "Emotion-focused interventions",
                "Structural techniques (boundary clarification)",
                "Attachment-based psychoeducation",
                "Reframing family narratives",
                "Communication skill-building",
                "Enactments and sculpting",
                "Homework (e.g., empathy journals)"
            ]
    ]
    
    init(prompt: Binding<String>, generateAction: @escaping () -> Void) {
        self._prompt = prompt
        self.generateAction = generateAction
        
        // Initialize ollamaKit with the default host
        let baseURL = URL(string: Defaults[.defaultHost])!
        self._ollamaKit = State(initialValue: OllamaKit(baseURL: baseURL))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 20) {
                // LEFT COLUMN - FORM
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Session Information Section
                        GroupBox {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Session Information")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                
                                HStack {
                                    Text("Date")
                                        .fontWeight(.semibold)
                                        .foregroundColor(Color.euniText)
                                    
                                    DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                                        .datePickerStyle(.compact)
                                }
                                
                                HStack {
                                    Text("Time")
                                        .fontWeight(.semibold)
                                        .foregroundColor(Color.euniText)
                                    
                                    DatePicker("Time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                                        .datePickerStyle(.compact)
                                }
                                
                                Picker("Location", selection: $selectedLocation) {
                                    ForEach(locations, id: \.self) { location in
                                        Text(location).tag(location)
                                    }
                                }
                            }
                            .padding()
                        }
                        
                        // Note Format Section
                        GroupBox {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Note Format")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                
                                HStack {
                                    Text("Note Format")
                                        .fontWeight(.semibold)
                                        .foregroundColor(Color.euniText)
                                    
                                    Picker("Format", selection: $selectedNoteFormat) {
                                        ForEach(noteFormats, id: \.self) { format in
                                            Text(format).tag(format)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                }
                                
                                if selectedNoteFormat == "Other" {
                                    TextField("Custom Note Format", text: $customNoteFormat)
                                        .textFieldStyle(.roundedBorder)
                                }
                            }
                            .padding()
                        }
                        
                        // Therapeutic Approach Section
                        GroupBox {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Therapeutic Approach")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                
                                HStack {
                                    Text("Therapeutic Approach")
                                        .fontWeight(.semibold)
                                        .foregroundColor(Color.euniText)
                                    
                                    Picker("Approach", selection: $selectedApproach) {
                                        ForEach(approaches, id: \.self) { approach in
                                            Text(approach).tag(approach)
                                        }
                                    }
                                }
                                
                                if selectedApproach == "Other" {
                                    TextField("Custom Therapeutic Approach", text: $customApproach)
                                        .textFieldStyle(.roundedBorder)
                                } else if let approachInterventions = interventions[selectedApproach] {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Interventions:")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        
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
                                            .toggleStyle(SwitchToggleStyle(tint: .primary))
                                        }
                                    }
                                }
                            }
                            .padding()
                        }
                        
                        // Presenting Issue Section
                        GroupBox {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Presenting Issue")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                
                                HStack {
                                    Text("Presenting Issue")
                                        .fontWeight(.semibold)
                                        .foregroundColor(Color.euniText)
                                    
                                    Picker("Issue", selection: $presentingIssue) {
                                        ForEach(presentingIssues, id: \.self) { issue in
                                            Text(issue).tag(issue)
                                        }
                                    }
                                }
                                
                                if presentingIssue == "Other" {
                                    TextField("Custom Presenting Issue", text: $customPresentingIssue)
                                        .textFieldStyle(.roundedBorder)
                                }
                            }
                            .padding()
                        }
                        
                        // Client Response Section
                        GroupBox {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Client Response")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                
                                HStack {
                                    Text("Client Response")
                                        .fontWeight(.semibold)
                                        .foregroundColor(Color.euniText)
                                    
                                    Picker("Response", selection: $clientResponse) {
                                        ForEach(clientResponses, id: \.self) { response in
                                            Text(response).tag(response)
                                        }
                                    }
                                }
                                
                                if clientResponse == "Other" {
                                    TextField("Custom Client Response", text: $customClientResponse)
                                        .textFieldStyle(.roundedBorder)
                                }
                            }
                            .padding()
                        }
                        
                        // Clinical Focus Section
                        GroupBox {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Clinical Focus")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                
                                HStack {
                                    Text("Clinical Focus")
                                        .fontWeight(.semibold)
                                        .foregroundColor(Color.euniText)
                                    
                                    Picker("Focus", selection: $clinicalFocus) {
                                        ForEach(clinicalFocuses, id: \.self) { focus in
                                            Text(focus).tag(focus)
                                        }
                                    }
                                }
                                
                                if clinicalFocus == "Other" {
                                    TextField("Custom Clinical Focus", text: $customClinicalFocus)
                                        .textFieldStyle(.roundedBorder)
                                }
                            }
                            .padding()
                        }
                        
                        // Treatment Goals Section
                        GroupBox {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Treatment Goals")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                
                                HStack {
                                    Text("Treatment Goals")
                                        .fontWeight(.semibold)
                                        .foregroundColor(Color.euniText)
                                    
                                    Picker("Goals", selection: $treatmentGoals) {
                                        ForEach(treatmentGoalsList, id: \.self) { goal in
                                            Text(goal).tag(goal)
                                        }
                                    }
                                }
                                
                                if treatmentGoals == "Other" {
                                    TextField("Custom Treatment Goals", text: $customTreatmentGoals)
                                        .textFieldStyle(.roundedBorder)
                                }
                            }
                            .padding()
                        }
                        
                        // Insurance Code/Diagnosis Section
                        GroupBox {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Insurance Code/Diagnosis")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                
                                HStack {
                                    Text("ICD-10/Diagnosis")
                                        .fontWeight(.semibold)
                                        .foregroundColor(Color.euniText)
                                    
                                    TextField("ICD-10/Diagnosis", text: $insuranceQuery)
                                        .textFieldStyle(.roundedBorder)
                                        .padding(.leading, 8)
                                        .onChange(of: insuranceQuery) { oldValue, newValue in
                                            if newValue.count >= 2 {
                                                fetchICD10Codes(query: newValue)
                                            } else {
                                                icdResults = []
                                                icdSearchError = nil
                                            }
                                        }
                                }
                                
                                if isSearchingICD {
                                    ProgressView()
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 4)
                                } else if let error = icdSearchError {
                                    Text(error)
                                        .foregroundColor(Color.euniError)
                                        .font(.caption)
                                        .padding(.vertical, 4)
                                } else if !icdResults.isEmpty {
                                    List(icdResults) { result in
                                        Button(action: {
                                            selectedICDCode = result.code
                                            selectedICDDescription = result.description
                                            insuranceQuery = "\(result.code) - \(result.description)"
                                            icdResults = []
                                        }) {
                                            Text("\(result.code) - \(result.description)")
                                                .foregroundColor(Color.euniText)
                                        }
                                    }
                                    .frame(height: 100)
                                }
                            }
                            .padding()
                        }
                    }
                    .padding()
                }
                .frame(minWidth: 400, idealWidth: 450, maxWidth: .infinity)
                .background(Color.euniBackground)
                
                // RIGHT COLUMN - NOTES
                VStack(alignment: .leading, spacing: 16) {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Additional Notes")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            HStack {
                                Text("Additional Notes")
                                    .fontWeight(.semibold)
                                    .foregroundColor(Color.euniText)
                                
                                Spacer()
                                
                                Button(action: {
                                    if isRecording {
                                        stopRecording()
                                    } else {
                                        startRecording()
                                    }
                                }) {
                                    Label(isRecording ? "Stop Recording" : "Start Recording",
                                          systemImage: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                        .foregroundColor(isRecording ? Color.euniError : Color.euniPrimary)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            if isRecording {
                                Text("Recording...")
                                    .foregroundColor(Color.euniError)
                                    .padding(.leading, 8)
                            }
                            
                            ScrollView {
                                TextEditor(text: $additionalNotes)
                                    .font(.body)
                                    .padding(8)
                                    .background(Color.euniFieldBackground)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.euniBorder, lineWidth: 1)
                                    )
                                    .frame(minHeight: 300)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Toggle("Client Expressed Suicidal Ideation or Self-Harm", isOn: $hasSuicidalIdeation)
                                    .fontWeight(.semibold)
                                    .foregroundColor(Color.euniText)
                                    .padding(.top, 12)
                                
                                if hasSuicidalIdeation {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Toggle("In a past session", isOn: $suicidalIdeationPastSession)
                                            .onChange(of: suicidalIdeationPastSession) { _, newValue in
                                                if newValue && suicidalIdeationBothSessions {
                                                    suicidalIdeationBothSessions = false
                                                }
                                                if newValue && suicidalIdeationCurrentSession {
                                                    suicidalIdeationCurrentSession = false
                                                    suicidalIdeationBothSessions = true
                                                }
                                            }
                                        
                                        Toggle("For the first time in the current session", isOn: $suicidalIdeationCurrentSession)
                                            .onChange(of: suicidalIdeationCurrentSession) { _, newValue in
                                                if newValue && suicidalIdeationBothSessions {
                                                    suicidalIdeationBothSessions = false
                                                }
                                                if newValue && suicidalIdeationPastSession {
                                                    suicidalIdeationPastSession = false
                                                    suicidalIdeationBothSessions = true
                                                }
                                            }
                                        
                                        Toggle("In a past session and the current session", isOn: $suicidalIdeationBothSessions)
                                            .onChange(of: suicidalIdeationBothSessions) { _, newValue in
                                                if newValue {
                                                    suicidalIdeationPastSession = false
                                                    suicidalIdeationCurrentSession = false
                                                }
                                            }
                                    }
                                    .padding(.leading, 20)
                                }
                            }
                        }
                        .padding()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(minWidth: 400, idealWidth: 450, maxWidth: .infinity)
            }
            .padding()
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
                        // Store the full prompt with PIRP instructions for the model
                        let modelPrompt = fullPrompt
                        
                        // Call the generate action with the display prompt and model prompt
                        if let activeChat = chatViewModel.activeChat {
                            messageViewModel.generate(ollamaKit, activeChat: activeChat, prompt: chatEntryText, modelPrompt: modelPrompt)
                        }
                        
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.euniBackground)
        .navigationTitle("Easy Note")
        .foregroundColor(.primary)
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
        selectedDate = Date()
        selectedTime = Date()
        selectedNoteFormat = "BIRP"
        customNoteFormat = ""
        selectedApproach = "CBT (Cognitive Behavioral Therapy)"
        customApproach = ""
        selectedInterventions = []
        presentingIssue = "Anxiety"
        customPresentingIssue = ""
        clientResponse = "Engaged and cooperative"
        customClientResponse = ""
        clinicalFocus = "Cognitive distortions"
        customClinicalFocus = ""
        treatmentGoals = "Reduce anxiety symptoms"
        customTreatmentGoals = ""
        selectedLocation = "In-Person"
        additionalNotes = ""
        isRecording = false
        showingPermissionAlert = false
        showingNetworkAlert = false
        networkErrorMessage = ""
        insuranceQuery = ""
        selectedICDCode = ""
        selectedICDDescription = ""
        icdResults = []
        isSearchingICD = false
        icdSearchError = nil
        chatEntryText = ""
        fullPrompt = ""
        hasSuicidalIdeation = false
        suicidalIdeationPastSession = false
        suicidalIdeationCurrentSession = false
        suicidalIdeationBothSessions = false
    }
    
    private func cleanupResources() {
        // Stop recording if active
        if isRecording {
            stopRecording()
        }
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        speechRecognizer = nil
    }
    
    private func requestSpeechRecognitionPermission() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    print("Speech recognition authorized")
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
                case .denied, .restricted, .notDetermined:
                    print("Speech recognition permission not granted or restricted")
                    self.showingPermissionAlert = true
                @unknown default:
                    print("Unknown speech recognition status")
                    self.showingPermissionAlert = true
                }
            }
        }
    }
    
    private func startRecording() {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
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
            
            recognitionTask?.cancel()
            recognitionTask = nil
            
            let inputNode = audioEngine.inputNode
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else {
                networkErrorMessage = "Unable to create recognition request. Please try again."
                showingNetworkAlert = true
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
                                self.networkErrorMessage = "No speech detected. Please try speaking again."
                                self.showingNetworkAlert = true
                            }
                        default:
                            if !self.isRecording { return }
                            self.networkErrorMessage = "Speech recognition error: \(error.localizedDescription)"
                            self.showingNetworkAlert = true
                        }
                    }
                    self.stopRecording()
                    return
                }
                
                guard let result = result else { return }
                
                DispatchQueue.main.async {
                    if !result.bestTranscription.formattedString.isEmpty {
                        self.additionalNotes = result.bestTranscription.formattedString
                    }
                }
            }
            
            guard recognitionTask != nil else {
                networkErrorMessage = "Failed to create recognition task. Please try again."
                showingNetworkAlert = true
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
            networkErrorMessage = "Error starting recording: \(error.localizedDescription)"
            showingNetworkAlert = true
            stopRecording()
        }
    }
    
    private func stopRecording() {
        recognitionTask?.cancel()
        recognitionTask = nil
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        isRecording = false
    }
    
    // MARK: - ICD-10 API Integration
    private func fetchICD10Codes(query: String) {
        guard !query.isEmpty else {
            icdResults = []
            icdSearchError = nil
            return
        }
        
        isSearchingICD = true
        icdSearchError = nil
        
        // Construct URL with required parameters
        let baseURL = "https://clinicaltables.nlm.nih.gov/api/icd10cm/v3/search"
        let parameters = [
            "sf": "code,name",  // Search fields: code and name
            "terms": query,     // Search terms
            "maxList": "10",    // Limit results to 10 items
            "df": "code,name"   // Display fields: code and name
        ]
        
        var components = URLComponents(string: baseURL)
        components?.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        guard let url = components?.url else {
            isSearchingICD = false
            icdSearchError = "Invalid search query"
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10 // 10 second timeout
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isSearchingICD = false
                
                if let error = error {
                    self.icdSearchError = "Search failed: \(error.localizedDescription)"
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.icdSearchError = "Invalid server response"
                    return
                }
                
                guard httpResponse.statusCode == 200 else {
                    self.icdSearchError = "Server error: \(httpResponse.statusCode)"
                    return
                }
                
                guard let data = data else {
                    self.icdSearchError = "No data received"
                    return
                }
                
                do {
                    // Parse the JSON array response
                    if let jsonArray = try JSONSerialization.jsonObject(with: data, options: []) as? [Any],
                       jsonArray.count >= 4,  // API returns array with at least 4 elements
                       let descriptions = jsonArray[3] as? [[String]] {  // Fourth element contains [code, name] pairs
                        
                        var results: [ICDResult] = []
                        for pair in descriptions {
                            if pair.count >= 2 {
                                let code = pair[0]
                                let description = pair[1]
                                results.append(ICDResult(code: code, description: description))
                            }
                        }
                        self.icdResults = results
                    } else {
                        self.icdSearchError = "Invalid response format"
                    }
                } catch {
                    self.icdSearchError = "Failed to parse response: \(error.localizedDescription)"
                }
            }
        }
        task.resume()
    }
    
    private func generatePrompt() {
        // Format date and time
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        let formattedDate = dateFormatter.string(from: selectedDate)
        
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        let formattedTime = timeFormatter.string(from: selectedTime)
        
        // Create the base prompt with date and time
        var promptText = "Date: \(formattedDate)\nTime: \(formattedTime)\n\n"
        
        // Add location
        promptText += "Location: \(selectedLocation)\n"
        
        // Add telehealth placeholder if needed
        if selectedLocation == "First Telehealth Visit" {
            promptText += "Telehealth Note: This was the client's first telehealth session. Document that informed consent for telehealth was obtained, that the client was informed of potential risks and limitations, that the therapists license or registration number was provided, and that the therapist made efforts to identify local emergency resources relevant to the client’s location.\n\n"
        } else if selectedLocation == "Subsequent Telehealth Visit" {
            promptText += "Telehealth Note: This was a subsequent telehealth session. Document that the therapist confirmed the client’s full name and present physical address, assessed the appropriateness of continuing via telehealth, and ensured confidentiality and safety using best practices for secure communication. \n\n"
        }
        
        // Add note format
        promptText += "Note Format: \(selectedNoteFormat == "Other" ? customNoteFormat : selectedNoteFormat)\n\n"
        
        // Add therapeutic approach
        promptText += "Therapeutic Approach: \(selectedApproach == "Other" ? customApproach : selectedApproach)\n"
        
        // Add selected interventions
        if !selectedInterventions.isEmpty {
            promptText += "Interventions: \(selectedInterventions.joined(separator: ", "))\n"
        }
        
        // Add presenting issue
        promptText += "Presenting Issue: \(presentingIssue == "Other" ? customPresentingIssue : presentingIssue)\n"
        
        // Add client response
        promptText += "Client Response: \(clientResponse == "Other" ? customClientResponse : clientResponse)\n"
        
        // Add clinical focus
        promptText += "Clinical Focus: \(clinicalFocus == "Other" ? customClinicalFocus : clinicalFocus)\n"
        
        // Add treatment goals
        promptText += "Treatment Goals: \(treatmentGoals == "Other" ? customTreatmentGoals : treatmentGoals)\n"
        
        // Add insurance code/diagnosis
        if !insuranceQuery.isEmpty {
            promptText += "Insurance Code/Diagnosis: \(insuranceQuery)\n"
        }
        
        // Add additional notes
        if !additionalNotes.isEmpty {
            promptText += "\nAdditional Notes:\n\(additionalNotes)\n"
        }
        
        // Add suicidal ideation/self-harm information if applicable
        if hasSuicidalIdeation {
            promptText += "\nClient Expressed Suicidal Ideation or Self-Harm"
            
            if suicidalIdeationPastSession {
                promptText += " in a past session"
            } else if suicidalIdeationCurrentSession {
                promptText += " for the first time in the current session"
            } else if suicidalIdeationBothSessions {
                promptText += " in a past session and the current session"
            }
            
            promptText += "\n\nif either (a) the client has expressed suicidal ideation or self harm for the first time during the session, or (b) the client has expressed suicidal ideation or self-harm previously and also in the current session, document this clearly and clinically. Include: (1) the client's specific statements or behaviors that prompted risk assessment, (2) identified risk and protective factors, (3) the outcome of any suicide risk assessment and rationale for the therapists clinical judgment, (4) any safety plan developed collaboratively with the client, and (5) follow-up arrangements. Use objective language and avoid vague phrasing. If the client has expressed suicidal ideation or self harm in a previous session, but has not in the current session, note that the client has previously expressed suicidal ideation, that there was no further expression during the current session, but note that the therapist reviewed the client's safety plan with them. If a formal assessment tool was used, reference it. Ensure the note reflects ethical care, clinical reasoning, and legal defensibility.\n"
        }
        
        // Store the display prompt (without PIRP instructions)
        chatEntryText = promptText
        
        // If PIRP format is selected, append the PIRP instructions to the full prompt
        if selectedNoteFormat == "PIRP" {
            fullPrompt = promptText + "\n\nFor your reference, here is how to structure PIRP Clinical Note Language:\n\n" +
                "PIRP Clinical Note Language differs from BIRP in that it leads with the Presenting Problem, followed by the Intervention, then the Response, and finally the Plan. This format is particularly useful for documenting specific therapeutic interactions and their outcomes.\n\n" +
                "Key therapeutic elements to include:\n" +
                "- Presenting Problem: Client's current issue, symptoms, or concerns\n" +
                "- Intervention: Specific therapeutic techniques or approaches used\n" +
                "- Response: Client's reaction to the intervention\n" +
                "- Plan: Next steps, homework, or follow-up actions\n\n" +
                "PIRP Note Template:\n" +
                "P: [Presenting Problem] - Describe the client's current issue or concern\n" +
                "I: [Intervention] - Detail the specific therapeutic approach or technique used\n" +
                "R: [Response] - Document the client's reaction or response to the intervention\n" +
                "P: [Plan] - Outline the next steps, homework, or follow-up actions\n\n" +
                "Example:\n" +
                "P: Client reported increased anxiety related to work deadlines\n" +
                "I: Utilized cognitive restructuring to identify and challenge negative thought patterns\n" +
                "R: Client demonstrated good insight and was able to reframe two specific cognitive distortions\n" +
                "P: Client will practice cognitive restructuring worksheet daily and monitor anxiety levels\n\n" +
                "Additional plug-in language:\n" +
                "- \"Client presented with...\"\n" +
                "- \"Therapist utilized...\"\n" +
                "- \"Client responded by...\"\n" +
                "- \"Plan includes...\""
        } else {
            fullPrompt = promptText
        }
    }
}

struct EasyNoteSheet_Previews: PreviewProvider {
    static var previews: some View {
        EasyNoteSheet(prompt: .constant(""), generateAction: {})
    }
}

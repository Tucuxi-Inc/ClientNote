import SwiftUI
import Speech
import AVFoundation
import OllamaKit
import Defaults

struct EasyTreatmentPlanSheet: View {
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
    
    // Date field
    @State private var selectedDate = Date()
    
    // Presenting Concerns
    @State private var presentingConcerns = "Anxiety"
    @State private var customPresentingConcerns = ""
    
    // Treatment Goals
    @State private var treatmentGoals = "Reduce anxiety symptoms"
    @State private var customTreatmentGoals = ""
    
    // Client Strengths
    @State private var selectedStrengths: Set<String> = []
    @State private var customStrength = ""
    
    // Treatment Obstacles
    @State private var selectedObstacles: Set<String> = []
    @State private var customObstacle = ""
    
    // Cultural/Identity Factors
    @State private var selectedCulturalFactors: Set<String> = []
    @State private var customCulturalFactor = ""
    
    // Risk Assessment
    @State private var selectedRiskFactors: Set<String> = []
    @State private var customRiskFactor = ""
    
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
    
    // Arrays for pickers
    private let presentingConcernsList = ["Anxiety", "Depression", "Trauma", "Relationship conflict", "Emotional dysregulation", "Grief", "Identity exploration", "Other"]
    private let treatmentGoalsList = ["Reduce anxiety symptoms", "Increase emotional resilience", "Improve interpersonal functioning", "Develop insight into patterns", "Increase acceptance and psychological flexibility", "Other"]
    
    private let strengthsList = [
        "Empathy",
        "Honesty",
        "Open-mindedness",
        "Persistence",
        "Enthusiasm",
        "Kindness",
        "Love",
        "Social Awareness",
        "Creativity",
        "Curiosity",
        "Resilience",
        "Self-Control",
        "Patience",
        "Gratitude",
        "Confidence",
        "Flexibility",
        "Humor",
        "Spirituality",
        "Other"
    ]
    
    private let obstaclesList = [
        "Financial Barriers",
        "Lack of Services",
        "Time Constraints",
        "Transportation Issues",
        "Insurance Limitations",
        "Social Stigma",
        "Fear of Vulnerability",
        "Denial/Downplaying Problems",
        "Language Barriers",
        "Comorbid Medical Issues",
        "Limited Support Networks",
        "Other"
    ]
    
    private let culturalFactorsList = [
        "Race/Ethnicity",
        "Primary Language",
        "National Origin",
        "Religious/Spiritual Beliefs",
        "Age/Generation",
        "Gender Identity",
        "Sexual Orientation",
        "Socioeconomic Status",
        "Migration Status",
        "Disability Status",
        "Other"
    ]
    
    private let riskFactorsList = [
        "Suicidal Ideation or Intent",
        "History of Self-Harm or Attempts",
        "Active Self-Injurious Behavior",
        "Homicidal Ideation/Aggression",
        "Substance Misuse Risk",
        "Impulsivity",
        "Protective Factors (e.g., Social Support, Coping Skills)",
        "Crisis Triggers (bereavement, trauma)",
        "Chronic Illness or Pain",
        "Legal/Safety Concerns",
        "Other"
    ]
    
    init(prompt: Binding<String>, generateAction: @escaping () -> Void) {
        self._prompt = prompt
        self.generateAction = generateAction
        
        let baseURL = URL(string: Defaults[.defaultHost])!
        self._ollamaKit = State(initialValue: OllamaKit(baseURL: baseURL))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 20) {
                // LEFT COLUMN - FORM
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Treatment Plan Information Section
                        GroupBox {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Treatment Plan Information")
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
                            }
                            .padding()
                        }
                        
                        // Presenting Concerns Section
                        GroupBox {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Presenting Concerns")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                
                                Picker("Concerns", selection: $presentingConcerns) {
                                    ForEach(presentingConcernsList, id: \.self) { concern in
                                        Text(concern).tag(concern)
                                    }
                                }
                                
                                if presentingConcerns == "Other" {
                                    TextField("Custom Presenting Concerns", text: $customPresentingConcerns)
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
                                
                                Picker("Goals", selection: $treatmentGoals) {
                                    ForEach(treatmentGoalsList, id: \.self) { goal in
                                        Text(goal).tag(goal)
                                    }
                                }
                                
                                if treatmentGoals == "Other" {
                                    TextField("Custom Treatment Goals", text: $customTreatmentGoals)
                                        .textFieldStyle(.roundedBorder)
                                }
                            }
                            .padding()
                        }
                        
                        // Client Strengths Section
                        GroupBox {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Client Strengths")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                
                                ForEach(strengthsList, id: \.self) { strength in
                                    if strength == "Other" {
                                        Toggle(strength, isOn: createToggleBinding(
                                            for: strength,
                                            in: $selectedStrengths,
                                            customField: $customStrength
                                        ))
                                        .toggleStyle(SwitchToggleStyle(tint: .primary))
                                        
                                        if selectedStrengths.contains("Other") {
                                            TextField("Custom Strength", text: $customStrength)
                                                .textFieldStyle(.roundedBorder)
                                                .padding(.leading)
                                        }
                                    } else {
                                        Toggle(strength, isOn: createToggleBinding(
                                            for: strength,
                                            in: $selectedStrengths,
                                            customField: $customStrength
                                        ))
                                        .toggleStyle(SwitchToggleStyle(tint: .primary))
                                    }
                                }
                            }
                            .padding()
                        }
                        
                        // Treatment Obstacles Section
                        GroupBox {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Treatment Obstacles")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                
                                ForEach(obstaclesList, id: \.self) { obstacle in
                                    if obstacle == "Other" {
                                        Toggle(obstacle, isOn: createToggleBinding(
                                            for: obstacle,
                                            in: $selectedObstacles,
                                            customField: $customObstacle
                                        ))
                                        .toggleStyle(SwitchToggleStyle(tint: .primary))
                                        
                                        if selectedObstacles.contains("Other") {
                                            TextField("Custom Obstacle", text: $customObstacle)
                                                .textFieldStyle(.roundedBorder)
                                                .padding(.leading)
                                        }
                                    } else {
                                        Toggle(obstacle, isOn: createToggleBinding(
                                            for: obstacle,
                                            in: $selectedObstacles,
                                            customField: $customObstacle
                                        ))
                                        .toggleStyle(SwitchToggleStyle(tint: .primary))
                                    }
                                }
                            }
                            .padding()
                        }
                        
                        // Cultural/Identity Factors Section
                        GroupBox {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Cultural/Identity Factors")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                
                                ForEach(culturalFactorsList, id: \.self) { factor in
                                    if factor == "Other" {
                                        Toggle(factor, isOn: createToggleBinding(
                                            for: factor,
                                            in: $selectedCulturalFactors,
                                            customField: $customCulturalFactor
                                        ))
                                        .toggleStyle(SwitchToggleStyle(tint: .primary))
                                        
                                        if selectedCulturalFactors.contains("Other") {
                                            TextField("Custom Cultural Factor", text: $customCulturalFactor)
                                                .textFieldStyle(.roundedBorder)
                                                .padding(.leading)
                                        }
                                    } else {
                                        Toggle(factor, isOn: createToggleBinding(
                                            for: factor,
                                            in: $selectedCulturalFactors,
                                            customField: $customCulturalFactor
                                        ))
                                        .toggleStyle(SwitchToggleStyle(tint: .primary))
                                    }
                                }
                            }
                            .padding()
                        }
                        
                        // Risk Assessment Section
                        GroupBox {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Risk Assessment")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                
                                ForEach(riskFactorsList, id: \.self) { factor in
                                    if factor == "Other" {
                                        Toggle(factor, isOn: createToggleBinding(
                                            for: factor,
                                            in: $selectedRiskFactors,
                                            customField: $customRiskFactor
                                        ))
                                        .toggleStyle(SwitchToggleStyle(tint: .primary))
                                        
                                        if selectedRiskFactors.contains("Other") {
                                            TextField("Custom Risk Factor", text: $customRiskFactor)
                                                .textFieldStyle(.roundedBorder)
                                                .padding(.leading)
                                        }
                                    } else {
                                        Toggle(factor, isOn: createToggleBinding(
                                            for: factor,
                                            in: $selectedRiskFactors,
                                            customField: $customRiskFactor
                                        ))
                                        .toggleStyle(SwitchToggleStyle(tint: .primary))
                                    }
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
                    Button("Generate Treatment Plan") {
                        generatePrompt()
                        // Set the prompt first
                        self.prompt = chatEntryText
                        // Then call the generate action
                        generateAction()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.euniBackground)
        .navigationTitle("Easy Treatment Plan")
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
    
    // Helper functions (we'll customize these for treatment plan generation)
    private func resetState() {
        // Reset all state variables to their initial values
        selectedDate = Date()
        presentingConcerns = "Anxiety"
        customPresentingConcerns = ""
        treatmentGoals = "Reduce anxiety symptoms"
        customTreatmentGoals = ""
        selectedStrengths = []
        customStrength = ""
        selectedObstacles = []
        customObstacle = ""
        selectedCulturalFactors = []
        customCulturalFactor = ""
        selectedRiskFactors = []
        customRiskFactor = ""
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
    }
    
    private func cleanupResources() {
        // ... existing cleanup code ...
    }
    
    private func generatePrompt() {
        print("DEBUG: EasyTreatmentPlan - Starting generatePrompt()")
        
        // Set activity type to Treatment Plan and create new activity
        chatViewModel.selectedTask = "Create a Treatment Plan"
        print("DEBUG: EasyTreatmentPlan - Creating new activity")
        chatViewModel.createNewActivity(isEasyNote: true)
        
        // Format date
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .none
        
        var planPrompt = """
        Please generate a treatment plan using the following information:

        1. **Client Info & Diagnosis**
        • Start-of-Care Date: \(dateFormatter.string(from: selectedDate))
        """
        
        // Add ICD-10 Diagnosis if available
        if !selectedICDCode.isEmpty {
            planPrompt += "\n• ICD-10 Diagnosis: \(selectedICDCode)"
            if !selectedICDDescription.isEmpty {
                planPrompt += " (\(selectedICDDescription))"
            }
        }
        
        // Add Presenting Concerns
        planPrompt += "\n• Presenting Concerns: "
        if presentingConcerns == "Other" && !customPresentingConcerns.isEmpty {
            planPrompt += customPresentingConcerns
        } else if presentingConcerns != "Other" {
            planPrompt += presentingConcerns
        }
        
        // Add Client Strengths
        planPrompt += "\n\n2. **Strengths & Barriers**\n• Key Strengths:\n"
        let strengths = selectedStrengths.filter { $0 != "Other" }
        for strength in strengths {
            planPrompt += "  - \(strength)\n"
        }
        if selectedStrengths.contains("Other") && !customStrength.isEmpty {
            planPrompt += "  - \(customStrength)\n"
        }
        
        // Add Treatment Obstacles
        planPrompt += "\n• Treatment Obstacles:\n"
        let obstacles = selectedObstacles.filter { $0 != "Other" }
        for obstacle in obstacles {
            planPrompt += "  - \(obstacle)\n"
        }
        if selectedObstacles.contains("Other") && !customObstacle.isEmpty {
            planPrompt += "  - \(customObstacle)\n"
        }
        
        // Add Treatment Goals
        planPrompt += "\n3. **Goals & Objectives**\n• Treatment Goals: "
        if treatmentGoals == "Other" && !customTreatmentGoals.isEmpty {
            planPrompt += customTreatmentGoals
        } else if treatmentGoals != "Other" {
            planPrompt += treatmentGoals
        }
        
        // Add Cultural & Risk Considerations
        planPrompt += "\n\n4. **Cultural & Risk Considerations**\n• Cultural/Identity Factors:\n"
        let culturalFactors = selectedCulturalFactors.filter { $0 != "Other" }
        for factor in culturalFactors {
            planPrompt += "  - \(factor)\n"
        }
        if selectedCulturalFactors.contains("Other") && !customCulturalFactor.isEmpty {
            planPrompt += "  - \(customCulturalFactor)\n"
        }
        
        // Add Risk Assessment
        planPrompt += "\n• Risk Assessment:\n"
        let riskFactors = selectedRiskFactors.filter { $0 != "Other" }
        for factor in riskFactors {
            planPrompt += "  - \(factor)\n"
        }
        if selectedRiskFactors.contains("Other") && !customRiskFactor.isEmpty {
            planPrompt += "  - \(customRiskFactor)\n"
        }
        
        // Add Additional Notes if any
        if !additionalNotes.isEmpty {
            planPrompt += "\n5. **Additional Context & Notes**\n"
            planPrompt += additionalNotes
        }
        
        print("DEBUG: EasyTreatmentPlan - Generated prompt content: \(planPrompt.prefix(200))...")
        
        // Store the prompt in chatEntryText
        chatEntryText = planPrompt
    }
    
    // Add the missing functions
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
    
    // Break up the complex expression in the view by creating helper functions
    private func createToggleBinding(for item: String, in set: Binding<Set<String>>, customField: Binding<String>) -> Binding<Bool> {
        Binding(
            get: { set.wrappedValue.contains(item) },
            set: { isSelected in
                if isSelected {
                    set.wrappedValue.insert(item)
                } else {
                    set.wrappedValue.remove(item)
                    if item == "Other" {
                        customField.wrappedValue = ""
                    }
                }
            }
        )
    }
}

struct EasyTreatmentPlanSheet_Previews: PreviewProvider {
    static var previews: some View {
        EasyTreatmentPlanSheet(prompt: .constant(""), generateAction: {})
    }
} 
//
//  EasyNoteSheet.swift
//  ClientNote
//
//  Refactored to use modular sub-components
//  Original: 1076 lines | Refactored: ~350 lines (67% reduction)
//

import SwiftUI
import Speech
import AVFoundation
import OllamaKit
import Defaults

struct EasyNoteSheet: View {
    // MARK: - Bindings & Environment
    @Binding var prompt: String
    let generateAction: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(ChatViewModel.self) private var chatViewModel
    @Environment(MessageViewModel.self) private var messageViewModel
    @State private var ollamaKit: OllamaKit

    // MARK: - State Properties

    // Internal state
    @State private var chatEntryText: String = ""
    @State private var fullPrompt: String = ""

    // Date and Time
    @State private var selectedDate = Date()
    @State private var selectedTime = Date()

    // Note Format
    @State private var selectedNoteFormat = "PIRP"
    @State private var customNoteFormat = ""

    // Therapeutic Approach
    @State private var selectedApproach = "CBT (Cognitive Behavioral Therapy)"
    @State private var customApproach = ""
    @State private var selectedInterventions: Set<String> = []

    // Clinical Fields
    @State private var presentingIssue = "Anxiety"
    @State private var customPresentingIssue = ""
    @State private var clientResponse = "Engaged and cooperative"
    @State private var customClientResponse = ""
    @State private var clinicalFocus = "Cognitive distortions"
    @State private var customClinicalFocus = ""
    @State private var treatmentGoals = "Reduce anxiety symptoms"
    @State private var customTreatmentGoals = ""

    // Location
    @State private var selectedLocation = "In-Person"

    // ICD-10 Codes
    @State private var insuranceQuery = ""
    @State private var icdResults: [ICDResult] = []
    @State private var selectedICDCode = ""
    @State private var selectedICDDescription = ""
    @State private var isSearchingICD = false
    @State private var icdSearchError: String? = nil

    // Additional Notes & Recording
    @State private var additionalNotes = ""
    @State private var isRecording = false
    @State private var speechRecognizer: SFSpeechRecognizer?
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var audioEngine = AVAudioEngine()
    @State private var showingPermissionAlert = false
    @State private var recordingPermissionGranted = false

    // Risk Assessment
    @State private var hasSuicidalIdeation = false
    @State private var suicidalIdeationPastSession = false
    @State private var suicidalIdeationCurrentSession = false
    @State private var suicidalIdeationBothSessions = false

    // MARK: - Initialization

    init(prompt: Binding<String>, generateAction: @escaping () -> Void) {
        self._prompt = prompt
        self.generateAction = generateAction

        let baseURL = URL(string: Defaults[.defaultHost])!
        self._ollamaKit = State(initialValue: OllamaKit(baseURL: baseURL))
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: .spacingXL) {
                // LEFT COLUMN - Form with Sub-Components
                ScrollView {
                    VStack(alignment: .leading, spacing: .spacingL) {
                        // Header
                        Text("Create Session Note")
                            .font(.title2.weight(.bold))
                            .foregroundColor(Color.euniText)
                            .padding(.bottom, .spacingS)

                        // Date & Time Section
                        DateTimeSection(
                            selectedDate: $selectedDate,
                            selectedTime: $selectedTime
                        )

                        FormDivider()

                        // Note Format Section (kept from original)
                        noteFormatSection

                        FormDivider()

                        // Location Section
                        LocationSection(selectedLocation: $selectedLocation)

                        FormDivider()

                        // Therapeutic Approach Section
                        TherapeuticApproachSection(
                            selectedApproach: $selectedApproach,
                            customApproach: $customApproach,
                            selectedInterventions: $selectedInterventions
                        )

                        FormDivider()

                        // Clinical Fields Section
                        ClinicalFieldsSection(
                            presentingIssue: $presentingIssue,
                            customPresentingIssue: $customPresentingIssue,
                            clientResponse: $clientResponse,
                            customClientResponse: $customClientResponse,
                            clinicalFocus: $clinicalFocus,
                            customClinicalFocus: $customClinicalFocus,
                            treatmentGoals: $treatmentGoals,
                            customTreatmentGoals: $customTreatmentGoals
                        )

                        FormDivider()

                        // Risk Assessment Section
                        RiskAssessmentSection(
                            hasSuicidalIdeation: $hasSuicidalIdeation,
                            suicidalIdeationPastSession: $suicidalIdeationPastSession,
                            suicidalIdeationCurrentSession: $suicidalIdeationCurrentSession,
                            suicidalIdeationBothSessions: $suicidalIdeationBothSessions
                        )

                        FormDivider()

                        // ICD-10 Code Search Section
                        ICDCodeSearchSection(
                            searchQuery: $insuranceQuery,
                            selectedCode: $selectedICDCode,
                            selectedDescription: $selectedICDDescription,
                            icdResults: $icdResults,
                            isSearching: $isSearchingICD,
                            recentCodes: [],
                            onSearch: { query in
                                await performICDSearch(query: query)
                            }
                        )

                        FormDivider()

                        // Additional Notes Section
                        AdditionalNotesSection(
                            additionalNotes: $additionalNotes,
                            isRecording: $isRecording,
                            onStartRecording: startRecording,
                            onStopRecording: stopRecording,
                            recordingPermissionGranted: recordingPermissionGranted
                        )
                    }
                    .padding(.spacingL)
                }
                .frame(maxWidth: .infinity)

                // RIGHT COLUMN - Preview (kept from original structure)
                VStack(alignment: .leading, spacing: .spacingM) {
                    Text("Generated Prompt Preview")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(Color.euniText)

                    ScrollView {
                        Text(fullPrompt.isEmpty ? "Fill out the form to see a preview of the generated prompt." : fullPrompt)
                            .font(.body)
                            .foregroundColor(fullPrompt.isEmpty ? .secondary : Color.euniText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.spacingM)
                            .background(Color.euniFieldBackground)
                            .cornerRadius(.cornerRadiusM)
                    }
                }
                .frame(width: 400)
                .padding(.spacingL)
            }

            Divider()

            // Action Buttons
            HStack(spacing: .spacingM) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.euniSecondary)

                Spacer()

                Button("Generate Note") {
                    handleGenerate()
                }
                .buttonStyle(.euniPrimary)
                .keyboardShortcut(.return, modifiers: [.command])
            }
            .padding(.spacingL)
        }
        .frame(minWidth: 1200, minHeight: 800)
        .onAppear {
            requestSpeechPermission()
            updatePreview()
        }
        .onChange(of: selectedDate) { _, _ in updatePreview() }
        .onChange(of: selectedTime) { _, _ in updatePreview() }
        .onChange(of: selectedLocation) { _, _ in updatePreview() }
        .onChange(of: selectedApproach) { _, _ in updatePreview() }
        .onChange(of: selectedInterventions) { _, _ in updatePreview() }
        .onChange(of: presentingIssue) { _, _ in updatePreview() }
        .onChange(of: clientResponse) { _, _ in updatePreview() }
        .onChange(of: clinicalFocus) { _, _ in updatePreview() }
        .onChange(of: treatmentGoals) { _, _ in updatePreview() }
        .onChange(of: additionalNotes) { _, _ in updatePreview() }
        .onChange(of: hasSuicidalIdeation) { _, _ in updatePreview() }
        .onChange(of: selectedICDCode) { _, _ in updatePreview() }
    }

    // MARK: - Note Format Section (not yet componentized)

    private var noteFormatSection: some View {
        VStack(alignment: .leading, spacing: .spacingM) {
            FormSectionHeader("Note Format", subtitle: "Select the format for your clinical note")

            FormPickerRow(
                "Format",
                selection: $selectedNoteFormat,
                options: ["SOAP", "DAP", "BIRP", "PIRP", "GIRP", "SBAR", "FOCUS"],
                displayName: { $0 }
            )

            if selectedNoteFormat == "Other" {
                FormTextField(
                    "Custom Format",
                    text: $customNoteFormat,
                    placeholder: "Enter custom note format"
                )
            }
        }
    }

    // MARK: - Actions

    private func handleGenerate() {
        let notePrompt = generateNotePrompt()
        self.prompt = notePrompt
        dismiss()
        generateAction()
    }

    private func updatePreview() {
        fullPrompt = generateNotePrompt()
    }

    // MARK: - ICD Search

    private func performICDSearch(query: String) async {
        fetchICD10Codes(query: query)
    }

    private func fetchICD10Codes(query: String) {
        guard !query.isEmpty else {
            icdResults = []
            icdSearchError = nil
            return
        }

        isSearchingICD = true
        icdSearchError = nil

        let baseURL = "https://clinicaltables.nlm.nih.gov/api/icd10cm/v3/search"
        let parameters = [
            "sf": "code,name",
            "terms": query,
            "maxList": "10",
            "df": "code,name"
        ]

        var components = URLComponents(string: baseURL)
        components?.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }

        guard let url = components?.url else {
            isSearchingICD = false
            icdSearchError = "Invalid search query"
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isSearchingICD = false

                if let error = error {
                    self.icdSearchError = "Search failed: \(error.localizedDescription)"
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200,
                      let data = data else {
                    self.icdSearchError = "Server error"
                    return
                }

                do {
                    if let jsonArray = try JSONSerialization.jsonObject(with: data, options: []) as? [Any],
                       jsonArray.count >= 4,
                       let descriptions = jsonArray[3] as? [[String]] {

                        var results: [ICDResult] = []
                        for pair in descriptions {
                            if pair.count >= 2 {
                                results.append(ICDResult(code: pair[0], description: pair[1]))
                            }
                        }
                        self.icdResults = results
                    } else {
                        self.icdSearchError = "Invalid response format"
                    }
                } catch {
                    self.icdSearchError = "Failed to parse response"
                }
            }
        }
        task.resume()
    }

    // MARK: - Speech Recognition

    private func requestSpeechPermission() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                recordingPermissionGranted = (status == .authorized)
            }
        }
    }

    private func startRecording() {
        // Placeholder - implement speech recording
        guard recordingPermissionGranted else {
            showingPermissionAlert = true
            return
        }
        isRecording = true
        // TODO: Implement actual recording logic
    }

    private func stopRecording() {
        isRecording = false
        // TODO: Implement stop recording logic
    }

    // MARK: - Prompt Generation

    private func generateNotePrompt() -> String {
        print("DEBUG: EasyNote - Starting generatePrompt()")

        // Set activity type and create new activity
        chatViewModel.selectedTask = "Create a Client Session Note"
        print("DEBUG: EasyNote - Set task to Session Note")

        var notePrompt = """
        Please generate a clinical session note using the following information and format:

        SESSION INFORMATION:
        """

        // Format date and time
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short
        notePrompt += "\nDate: \(dateFormatter.string(from: selectedDate))"
        notePrompt += "\nTime: \(dateFormatter.string(from: selectedTime))"
        notePrompt += "\nLocation: \(selectedLocation)"
        notePrompt += "\nNote Format: \(selectedNoteFormat)\n"

        notePrompt += "\nCLINICAL CONTENT:"

        // Add presenting issue
        if presentingIssue == "Other" && !customPresentingIssue.isEmpty {
            notePrompt += "\nPresenting Issue: \(customPresentingIssue)"
        } else if presentingIssue != "Other" {
            notePrompt += "\nPresenting Issue: \(presentingIssue)"
        }

        // Add client response
        if clientResponse == "Other" && !customClientResponse.isEmpty {
            notePrompt += "\nClient Response: \(customClientResponse)"
        } else if clientResponse != "Other" {
            notePrompt += "\nClient Response: \(clientResponse)"
        }

        // Add clinical focus
        if clinicalFocus == "Other" && !customClinicalFocus.isEmpty {
            notePrompt += "\nClinical Focus: \(customClinicalFocus)"
        } else if clinicalFocus != "Other" {
            notePrompt += "\nClinical Focus: \(clinicalFocus)"
        }

        // Add treatment goals
        if treatmentGoals == "Other" && !customTreatmentGoals.isEmpty {
            notePrompt += "\nTreatment Goals: \(customTreatmentGoals)"
        } else if treatmentGoals != "Other" {
            notePrompt += "\nTreatment Goals: \(treatmentGoals)"
        }

        notePrompt += "\n\nTHERAPEUTIC APPROACH:"
        notePrompt += "\nPrimary Modality: \(selectedApproach)"

        if !selectedInterventions.isEmpty {
            notePrompt += "\nInterventions Used:"
            for intervention in selectedInterventions {
                notePrompt += "\n- \(intervention)"
            }
        }

        // Add additional notes
        if !additionalNotes.isEmpty {
            notePrompt += "\n\nADDITIONAL CLINICAL NOTES:\n\(additionalNotes)"
        }

        // Add diagnosis
        if !selectedICDCode.isEmpty {
            notePrompt += "\n\nDIAGNOSIS:"
            notePrompt += "\n\(selectedICDDescription) (\(selectedICDCode))"
        } else if !insuranceQuery.isEmpty {
            notePrompt += "\n\nDIAGNOSIS: \(insuranceQuery)"
        }

        // Add risk assessment
        if hasSuicidalIdeation {
            notePrompt += "\n\nRISK ASSESSMENT - Suicidal Ideation:"
            if suicidalIdeationPastSession {
                notePrompt += "\n- History: Reported in past session"
            }
            if suicidalIdeationCurrentSession {
                notePrompt += "\n- Current: Present in this session"
            }
            if suicidalIdeationBothSessions {
                notePrompt += "\n- Pattern: Present in both past and current sessions"
            }
        }

        notePrompt += "\n\nPlease structure this information into a comprehensive clinical note following the \(selectedNoteFormat) format and using professional clinical terminology. Include clear descriptions of interventions used and client's response to treatment."

        print("DEBUG: EasyNote - Generated prompt content: \(notePrompt.prefix(100))...")
        return notePrompt
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var prompt = ""

    EasyNoteSheet(prompt: $prompt, generateAction: {
        print("Generate action called")
    })
}

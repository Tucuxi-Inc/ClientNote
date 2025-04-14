import SwiftUI

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
            .navigationTitle("Easy Note")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Generate Note") {
                        generatePrompt()
                        generateAction()
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 500, minHeight: 600)
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
        
        prompt = """
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

        Now generate the note.
        """
    }
}

struct EasyNoteSheet_Previews: PreviewProvider {
    static var previews: some View {
        EasyNoteSheet(prompt: .constant(""), generateAction: {})
    }
}

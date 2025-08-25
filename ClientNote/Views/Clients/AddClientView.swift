import SwiftUI
import Foundation

struct AddClientView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ChatViewModel.self) private var chatViewModel
    
    // Client Information
    @State private var clientIdentifier: String = ""
    @State private var clientName: String = ""
    @State private var clientGender: String = ""
    @State private var dateOfBirth: Date = Date()
    @State private var startOfCare: Date = Date()
    @State private var presentingConcerns: String = ""
    @State private var relevantHistory: String = ""
    
    // Assessment Summary
    @State private var presentingSymptoms: String = ""
    @State private var insuranceQuery: String = ""
    @State private var icdResults: [ICDResult] = []
    @State private var icdSearchError: String? = nil
    @State private var isSearchingICD: Bool = false
    @State private var selectedICDCode: String = ""
    @State private var selectedICDDescription: String = ""
    @State private var clientStrengths: String = ""
    @State private var treatmentObstacles: String = ""
    
    // Treatment Goals
    @State private var longTermGoals: String = ""
    @State private var shortTermGoals: String = ""
    
    // Cultural Considerations
    @State private var culturalFactors: String = ""
    
    // Risk Assessment
    @State private var riskAssessment: String = ""
    
    // Additional Notes
    @State private var additionalNotes: String = ""
    
    var body: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 20) {
                // LEFT COLUMN
                VStack(alignment: .leading, spacing: 4) {
                    // Client Information Section
                    Group {
                        Text("Client Information")
                            .font(.title3)
                            .fontWeight(.bold)
                        VStack(alignment: .leading, spacing: 2) {
                            DatePicker("Start of Care", selection: $startOfCare, displayedComponents: .date)
                            DatePicker("Date of Birth", selection: $dateOfBirth, displayedComponents: .date)
                            
                            TextField("Client Identifier/Pseudonym (required)", text: $clientIdentifier)
                                .textFieldStyle(.roundedBorder)
                                .accessibilityLabel("Client Identifier")
                                .accessibilityHint("Enter a unique identifier or pseudonym for the client")
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(clientIdentifier.isEmpty ? Color.red.opacity(0.3) : Color.clear, lineWidth: 1)
                                )
                            
                            TextField("Name (optional)", text: $clientName)
                                .textFieldStyle(.roundedBorder)
                            TextField("Client Gender (optional)", text: $clientGender)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    
                    // Assessment Summary Section
                    Group {
                        Text("Assessment Summary")
                            .font(.title3)
                            .fontWeight(.bold)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Presenting Symptoms")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            TextEditor(text: $presentingSymptoms)
                                .frame(height: 30)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                                .background(Color(NSColor.textBackgroundColor))
                            
                            Text("Client Strengths")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            TextEditor(text: $clientStrengths)
                                .frame(height: 30)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                                .background(Color(NSColor.textBackgroundColor))
                            
                            Text("Treatment Obstacles")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            TextEditor(text: $treatmentObstacles)
                                .frame(height: 30)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                                .background(Color(NSColor.textBackgroundColor))
                        }
                    }
                    
                    // Treatment Goals Section
                    Group {
                        Text("Treatment Goals")
                            .font(.title3)
                            .fontWeight(.bold)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Long-Term Goals")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            TextEditor(text: $longTermGoals)
                                .frame(height: 30)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                                .background(Color(NSColor.textBackgroundColor))
                            
                            Text("Short-Term Goals")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            TextEditor(text: $shortTermGoals)
                                .frame(height: 30)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                                .background(Color(NSColor.textBackgroundColor))
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                
                // RIGHT COLUMN
                VStack(alignment: .leading, spacing: 4) {
                    // Clinical Content Section
                    Group {
                        Text("Clinical Content")
                            .font(.title3)
                            .fontWeight(.bold)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Presenting Concerns")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            TextEditor(text: $presentingConcerns)
                                .frame(height: 30)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                                .background(Color(NSColor.textBackgroundColor))
                                .accessibilityLabel("Presenting Concerns")
                                .accessibilityHint("Describe the client's main concerns or reasons for seeking therapy")
                            
                            Text("Relevant History")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            TextEditor(text: $relevantHistory)
                                .frame(height: 30)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                                .background(Color(NSColor.textBackgroundColor))
                        }
                    }
                    
                    // ICD-10/Diagnosis Section
                    Group {
                        Text("Diagnosis")
                            .font(.title3)
                            .fontWeight(.bold)
                        VStack(alignment: .leading, spacing: 2) {
                            TextField("ICD-10/Diagnosis", text: $insuranceQuery)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: insuranceQuery) { oldValue, newValue in
                                    if newValue.count >= 2 {
                                        fetchICD10Codes(query: newValue)
                                    } else {
                                        icdResults = []
                                        icdSearchError = nil
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
                                .frame(height: 80)
                            }
                        }
                    }
                    
                    // Additional Information Section
                    Group {
                        Text("Additional Information")
                            .font(.title3)
                            .fontWeight(.bold)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Cultural Factors")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            TextEditor(text: $culturalFactors)
                                .frame(height: 25)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                                .background(Color(NSColor.textBackgroundColor))
                            
                            Text("Risk Assessment")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            TextEditor(text: $riskAssessment)
                                .frame(height: 25)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                                .background(Color(NSColor.textBackgroundColor))
                            
                            Text("Additional Notes")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            TextEditor(text: $additionalNotes)
                                .frame(height: 30)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                                .background(Color(NSColor.textBackgroundColor))
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(12)
        }
        .navigationTitle("Add New Client")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    let newClient = Client(
                        identifier: clientIdentifier,
                        name: clientName,
                        gender: clientGender,
                        dateOfBirth: dateOfBirth,
                        startOfCare: startOfCare,
                        presentingConcerns: presentingConcerns,
                        relevantHistory: relevantHistory,
                        presentingSymptoms: presentingSymptoms,
                        insuranceDiagnosis: insuranceQuery,
                        strengths: clientStrengths,
                        obstacles: treatmentObstacles,
                        longTermGoals: longTermGoals,
                        shortTermGoals: shortTermGoals,
                        culturalFactors: culturalFactors,
                        riskAssessment: riskAssessment,
                        additionalNotes: additionalNotes
                    )
                    chatViewModel.addClient(newClient)
                    dismiss()
                }
                .disabled(clientIdentifier.isEmpty)
            }
        }
    }
}

private extension AddClientView {
    func fetchICD10Codes(query: String) {
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
                    if let jsonArray = try JSONSerialization.jsonObject(with: data, options: []) as? [Any],
                       jsonArray.count >= 4,
                       let descriptions = jsonArray[3] as? [[String]] {
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
} 
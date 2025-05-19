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
            VStack(alignment: .leading, spacing: 24) {
                // Client Information Section
                Group {
                    Text("Client Information")
                        .font(.title3)
                        .fontWeight(.bold)
                    VStack(alignment: .leading, spacing: 16) {
                        DatePicker("Start of Care", selection: $startOfCare, displayedComponents: .date)
                        
                        TextField("Client Identifier/Pseudonym (required)", text: $clientIdentifier)
                            .textFieldStyle(.roundedBorder)
                        TextField("Name (optional)", text: $clientName)
                            .textFieldStyle(.roundedBorder)
                        
                        TextField("Client Gender (optional)", text: $clientGender)
                            .textFieldStyle(.roundedBorder)
                DatePicker("Date of Birth", selection: $dateOfBirth, displayedComponents: .date)
                        
                        Text("Presenting Concerns")
                            .font(.headline)
                        TextEditor(text: $presentingConcerns)
                            .frame(height: 100)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                        
                        Text("Relevant History")
                            .font(.headline)
                        TextEditor(text: $relevantHistory)
                            .frame(height: 100)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                    }
                }
                
                Divider()
                
                // Assessment Summary Section
                Group {
                    Text("Assessment Summary")
                        .font(.title3)
                        .fontWeight(.bold)
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Presenting Symptoms")
                            .font(.headline)
                        TextEditor(text: $presentingSymptoms)
                            .frame(height: 100)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                        
                        Group {
                            Text("Insurance Code/Diagnosis (DSM or ICD-10)")
                                .font(.headline)
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
                        
                        Text("Client Personal Strengths and Resources (optional)")
                            .font(.headline)
                        TextEditor(text: $clientStrengths)
                            .frame(height: 100)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                        
                        Text("Potential Obstacles to Treatment (optional)")
                            .font(.headline)
                        TextEditor(text: $treatmentObstacles)
                            .frame(height: 100)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                    }
                }
                
                Divider()
                
                // Treatment Goals Section
                Group {
                    Text("Treatment Goals")
                        .font(.title3)
                        .fontWeight(.bold)
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Long-Term SMART Goals")
                            .font(.headline)
                        TextEditor(text: $longTermGoals)
                            .frame(height: 120)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                        
                        Text("Short-Term Goals")
                            .font(.headline)
                        TextEditor(text: $shortTermGoals)
                            .frame(height: 120)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                    }
                }
                
                Divider()
                
                // Cultural Considerations Section
                Group {
                    Text("Cultural Considerations")
                        .font(.title3)
                        .fontWeight(.bold)
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Cultural Factors (optional)")
                            .font(.headline)
                        TextEditor(text: $culturalFactors)
                            .frame(height: 100)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                    }
                }
                
                Divider()
                
                // Risk Assessment Section
                Group {
                    Text("Risk Assessment")
                        .font(.title3)
                        .fontWeight(.bold)
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Identified Risks and Safety Planning (optional)")
                            .font(.headline)
                        TextEditor(text: $riskAssessment)
                    .frame(height: 100)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                    }
                }
                
                Divider()
                
                // Additional Notes Section
                Group {
                    Text("Additional Notes")
                        .font(.title3)
                        .fontWeight(.bold)
                    TextEditor(text: $additionalNotes)
                        .frame(height: 120)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                }
            }
            .padding(24)
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
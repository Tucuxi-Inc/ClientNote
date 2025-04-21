//
//  ChatPreferencesView.swift
//  Ollamac
//
//  Created by Kevin Hermawan on 8/4/24.
//

import Defaults
import OllamaKit
import SwiftUI
import SwiftUIIntrospect

struct ChatPreferencesView: View {
    @Environment(ChatViewModel.self) private var chatViewModel
    
    @Binding private var ollamaKit: OllamaKit
    
    @State private var isUpdateOllamaHostPresented: Bool = false
    @State private var isUpdateSystemPromptPresented: Bool = false
    @State private var showAdvancedSettings: Bool = false
    @State private var showModelInfoPopover: Bool = false
    @State private var selectedDownloadModel: String = "gemma3:1b"
    @State private var isPullingModel: Bool = false
    @State private var pullProgress: Double = 0.0
    @State private var pullStatus: String = ""
    
    @Default(.defaultModel) private var model: String
    @State private var host: String
    @State private var systemPrompt: String
    @State private var temperature: Double
    @State private var topP: Double
    @State private var topK: Int
    
    private let availableModels = [
        "gemma3:1b",
        "granite3.3:2b",
        "gemma3:4b",
        "phi4-mini:3.8b",
        "granite3.3:8b"
    ]
    
    init(ollamaKit: Binding<OllamaKit>) {
        self._ollamaKit = ollamaKit
        
        self.host = Defaults[.defaultHost]
        self.systemPrompt = Defaults[.defaultSystemPrompt]
        self.temperature = Defaults[.defaultTemperature]
        self.topP = Defaults[.defaultTopP]
        self.topK = Defaults[.defaultTopK]
    }
    
    var body: some View {
        Form {
            Section {
                Picker("Selected Model", selection: $model) {
                    ForEach(chatViewModel.models, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
            } header: {
                HStack {
                    Text("Choose Installed Model")
                    
                    Spacer()
                    
                    Button(action: { chatViewModel.fetchModels(ollamaKit) }) {
                        if chatViewModel.loading == .fetchModels {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Refresh")
                                .foregroundColor(Color.euniPrimary)
                        }
                    }
                    .buttonStyle(.accessoryBar)
                    .disabled(chatViewModel.loading == .fetchModels)
                }
            }
            .onChange(of: model) { _, newValue in
                self.chatViewModel.activeChat?.model = newValue
            }
            
            Section {
                Picker("Select Model to Download", selection: $selectedDownloadModel) {
                    ForEach(availableModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                
                Button(action: { pullModel(selectedDownloadModel) }) {
                    if isPullingModel {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("Downloading... \(Int(pullProgress * 100))%")
                        }
                    } else {
                        Text("Download Model")
                    }
                }
                .disabled(isPullingModel)
                .foregroundColor(isPullingModel ? Color.euniSecondary : Color.euniPrimary)
                
                if !pullStatus.isEmpty {
                    if pullStatus.starts(with: "Successfully downloaded") {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(pullStatus)
                                .font(.caption)
                                .foregroundColor(Color.euniText)
                        }
                        .padding(.top, 4)
                    } else if pullStatus != "success" {
                        HStack {
                            Text(pullStatus)
                                .font(.caption)
                                .foregroundColor(Color.euniSecondary)
                        }
                        .padding(.top, 4)
                    }
                }
            } header: {
                HStack {
                    Text("Download an AI Model")
                    
                    Spacer()
                    
                    Button(action: { showModelInfoPopover = true }) {
                        Image(systemName: "info.circle")
                            .foregroundColor(Color.euniPrimary)
                    }
                    .buttonStyle(.accessoryBar)
                    .popover(isPresented: $showModelInfoPopover) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("About AI Models")
                                .font(.headline)
                                .foregroundColor(Color.euniText)
                                .padding(.bottom, 4)
                            
                            Text("These models are optimized to work on most MacBooks with Apple Silicon and at least 8GB of memory.")
                                .foregroundColor(Color.euniText)
                            
                            Text("Model Information:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(Color.euniText)
                                .padding(.top, 4)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("• gemma3:1b - Very lightweight model (~815MB)")
                                    .foregroundColor(Color.euniText)
                                Text("• granite3.3:2b - Compact model from Allen AI")
                                    .foregroundColor(Color.euniText)
                                Text("• gemma3:4b - Balanced model (~3.3GB)")
                                    .foregroundColor(Color.euniText)
                                Text("• phi4-mini:3.8b - Microsoft's compact model (~2.5GB)")
                                    .foregroundColor(Color.euniText)
                                Text("• granite3.3:8b - Larger model for better quality")
                                    .foregroundColor(Color.euniText)
                            }
                            
                            Text("You can download any other open-source model from ollama.com.")
                                .foregroundColor(Color.euniSecondary)
                                .padding(.top, 4)
                        }
                        .padding()
                        .frame(width: 320)
                        .background(Color.euniBackground)
                    }
                }
            }
            
            Section {
                // Empty section for spacing
            }
            
            Section {
                Button(action: {
                    withAnimation {
                        showAdvancedSettings.toggle()
                    }
                }) {
                    HStack {
                        Text("Advanced Settings")
                        Spacer()
                        Image(systemName: showAdvancedSettings ? "chevron.up" : "chevron.down")
                            .font(.caption)
                    }
                }
                .buttonStyle(.plain)
            }
            
            if showAdvancedSettings {
                Section {
                    Text(host)
                        .help(host)
                        .lineLimit(1)
                } header: {
                    HStack {
                        Text("Host")
                        
                        Spacer()
                        
                        Button("Change", action: { isUpdateOllamaHostPresented = true })
                            .buttonStyle(.accessoryBar)
                            .foregroundColor(Color.euniPrimary)
                    }
                }
                .onChange(of: host) { _, newValue in
                    self.chatViewModel.activeChat?.host = newValue
                    
                    if let baseURL = URL(string: newValue) {
                        self.ollamaKit = OllamaKit(baseURL: baseURL)
                    }
                }
                
                Section {
                    Text(systemPrompt)
                        .help(systemPrompt)
                        .lineLimit(3)
                } header: {
                    HStack {
                        Text("System Prompt")
                        
                        Spacer()
                        
                        Button("Change", action: { isUpdateSystemPromptPresented = true })
                            .buttonStyle(.accessoryBar)
                            .foregroundColor(Color.euniPrimary)
                    }
                } footer: {
                    Button("Restore Default System Prompt") {
                        systemPrompt = "You're Euni™ - Client Notes.  You are a clinical documentation assistant helping a therapist generate an insurance-ready psychotherapy progress note. You will use the information provided to you here to write a psychotherapy progress note using (unless otherwise instructed by the user) the BIRP format (Behavior, Intervention, Response, Plan). Requirements: Use clear, objective, and concise clinical language, Maintain gender-neutral pronouns, Do not make up quotes - only use exact quotes if and when provided by the user. Focus on observable behaviors, reported thoughts and feelings, therapist interventions, and clinical goals, Apply relevant approaches and techniques, including typical interventions and session themes, Use documentation language suitable for EHRs and insurance billing, If schemas, distortions, or core beliefs are addressed, name them using standard psychological terms, Conclude with a brief, action-oriented treatment plan. If this was the client's first telehealth session, document that informed consent for telehealth was obtained (verbal or written), that the client was informed of potential risks and limitations, that the therapists license or registration number was provided, and that the therapist made efforts to identify local emergency resources relevant to the client’s location. If this was a subsequent telehealth session, document that the therapist confirmed the client’s full name and present physical address, assessed the appropriateness of continuing via telehealth, and ensured confidentiality and safety using best practices for secure communication. If the client expressed suicidal ideation or self harm during the session, document this clearly and clinically. Include: (1) the client's specific statements or behaviors that prompted risk assessment, (2) identified risk and protective factors, (3) the outcome of any suicide risk assessment and rationale for the therapists clinical judgment, (4) any safety plan developed collaboratively with the client, and (5) follow-up arrangements. Use objective language and avoid vague phrasing. If a formal assessment tool was used, reference it. Ensure the note reflects ethical care, clinical reasoning, and legal defensibility."
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                    .foregroundColor(Color.euniPrimary)
                }
                .onChange(of: systemPrompt) { _, newValue in
                    self.chatViewModel.activeChat?.systemPrompt = newValue
                }
                
                Section {
                    Slider(value: $temperature, in: 0...1, step: 0.1) {
                        Text(temperature.formatted())
                    } minimumValueLabel: {
                        Text("0")
                    } maximumValueLabel: {
                        Text("1")
                    }
                } header: {
                    Text("Temperature")
                } footer: {
                    ChatPreferencesFooterView("Controls randomness. Higher values increase creativity, lower values are more focused.")
                }
                .onChange(of: temperature) { _, newValue in
                    self.chatViewModel.activeChat?.temperature = newValue
                }
                
                Section {
                    Slider(value: $topP, in: 0...1, step: 0.1) {
                        Text(topP.formatted())
                    } minimumValueLabel: {
                        Text("0")
                    } maximumValueLabel: {
                        Text("1")
                    }
                } header: {
                    Text("Top P")
                } footer: {
                    ChatPreferencesFooterView("Affects diversity. Higher values increase variety, lower values are more conservative.")
                }
                .onChange(of: topP) { _, newValue in
                    self.chatViewModel.activeChat?.topP = newValue
                }
                
                Section {
                    Stepper(topK.formatted(), value: $topK)
                } header: {
                    Text("Top K")
                } footer: {
                    ChatPreferencesFooterView("Limits token pool. Higher values increase diversity, lower values are more focused.")
                }
                .onChange(of: topK) { _, newValue in
                    self.chatViewModel.activeChat?.topK = newValue
                }
            }
        }
        .onChange(of: self.chatViewModel.activeChat) { _, newValue in
            if let model = newValue?.model {
                self.model = model
            }
            
            if let host = newValue?.host {
                self.host = host
            }
            
            if let systemPrompt = newValue?.systemPrompt {
                self.systemPrompt = systemPrompt
            }
            
            if let temperature = newValue?.temperature {
                self.temperature = temperature
            }
            
            if let topP = newValue?.topP {
                self.topP = topP
            }
            
            if let topK = newValue?.topK {
                self.topK = topK
            }
        }
        .sheet(isPresented: $isUpdateOllamaHostPresented) {
            UpdateOllamaHostSheet(host: host) { host in
                self.host = host
            }
        }
        .sheet(isPresented: $isUpdateSystemPromptPresented) {
            UpdateSystemPromptSheet(prompt: systemPrompt) { prompt in
                self.systemPrompt = prompt
            }
        }
    }
    
    func pullModel(_ modelName: String) {
        guard !isPullingModel else { return }
        
        isPullingModel = true
        pullProgress = 0.0
        pullStatus = "Starting download..."
        
        Task {
            await pullOllamaModel(modelName)
            await MainActor.run {
                isPullingModel = false
                
                // Refresh models list to show the newly pulled model
                chatViewModel.fetchModels(ollamaKit)
                
                // If the model was successfully pulled, update the selected model
                if pullStatus == "success" {
                    // Set a short delay to allow models list to refresh
                    Task {
                        try? await Task.sleep(for: .seconds(1))
                        if chatViewModel.models.contains(modelName) {
                            model = modelName
                            // Also update the active chat's model
                            chatViewModel.activeChat?.model = modelName
                        }
                        
                        // Show success status briefly, then clear
                        pullStatus = "Successfully downloaded \(modelName)"
                        
                        try? await Task.sleep(for: .seconds(3))
                        if pullStatus == "Successfully downloaded \(modelName)" {
                            pullStatus = ""
                        }
                    }
                }
            }
        }
    }
    
    func pullOllamaModel(_ modelName: String) async {
        guard let url = URL(string: "\(host)/api/pull") else { 
            await MainActor.run {
                pullStatus = "Error: Invalid Ollama host URL"
                isPullingModel = false
            }
            return 
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let pullRequest: [String: Any] = ["model": modelName, "stream": true]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: pullRequest)
            
            let (data, response) = try await URLSession.shared.bytes(for: request)
            
            // Check for HTTP errors
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode >= 400 {
                    let errorMessage: String
                    switch httpResponse.statusCode {
                    case 404:
                        errorMessage = "Ollama service not found. Is Ollama running?"
                    case 500...599:
                        errorMessage = "Ollama server error (HTTP \(httpResponse.statusCode))"
                    default:
                        errorMessage = "HTTP error \(httpResponse.statusCode)"
                    }
                    
                    await MainActor.run {
                        pullStatus = "Error: \(errorMessage)"
                        isPullingModel = false
                    }
                    return
                }
            }
            
            var buffer = Data()
            var completedSize: Int64 = 0
            var totalSize: Int64 = 1 // Prevent division by zero
            
            for try await byte in data {
                buffer.append(contentsOf: [byte])
                
                if byte == 10 { // Newline character
                    if let responseString = String(data: buffer, encoding: .utf8),
                       let responseData = responseString.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] {
                        
                        if let status = json["status"] as? String {
                            await MainActor.run {
                                pullStatus = status
                                
                                if status == "success" {
                                    pullProgress = 1.0
                                }
                            }
                            
                            if let completed = json["completed"] as? Int64 {
                                completedSize = completed
                            }
                            
                            if let total = json["total"] as? Int64, total > 0 {
                                totalSize = total
                            }
                            
                            if completedSize > 0 && totalSize > 0 {
                                let progress = Double(completedSize) / Double(totalSize)
                                await MainActor.run {
                                    pullProgress = min(progress, 0.99) // Cap at 99% until "success"
                                }
                            }
                        }
                        
                        // If there's an error field in the response
                        if let errorMessage = json["error"] as? String {
                            await MainActor.run {
                                pullStatus = "Error: \(errorMessage)"
                                isPullingModel = false
                            }
                            return
                        }
                    }
                    
                    buffer.removeAll()
                }
            }
        } catch let urlError as URLError {
            await MainActor.run {
                let errorMessage: String
                switch urlError.code {
                case .notConnectedToInternet:
                    errorMessage = "No internet connection"
                case .timedOut:
                    errorMessage = "Connection timed out"
                case .cannotConnectToHost:
                    errorMessage = "Cannot connect to Ollama. Is Ollama running?"
                default:
                    errorMessage = urlError.localizedDescription
                }
                
                pullStatus = "Error: \(errorMessage)"
                isPullingModel = false
            }
        } catch {
            await MainActor.run {
                pullStatus = "Error: \(error.localizedDescription)"
                isPullingModel = false
            }
        }
    }
}

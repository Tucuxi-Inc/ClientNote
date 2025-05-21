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
    @State private var showingNoteFormatInfo: Bool = false
    @State private var selectedDownloadModel: String = "qwen3:0.6b"
    @State private var isPullingModel: Bool = false
    @State private var pullProgress: Double = 0.0
    @State private var pullStatus: String = ""
    @State private var showAddClientSheet: Bool = false
    
    @Default(.defaultHost) private var host
    @Default(.defaultSystemPrompt) private var systemPrompt
    @Default(.defaultTemperature) private var temperature
    @Default(.defaultTopP) private var topP
    @Default(.defaultTopK) private var topK
    
    private let taskOptions = [
        "Create a Treatment Plan",
        "Create a Client Session Note",
        "Brainstorm"
    ]
    
    private func updateSystemPrompt() {
        // Get the appropriate system prompt from ChatViewModel
        let type = chatViewModel.getActivityTypeFromTask(chatViewModel.selectedTask)
        systemPrompt = chatViewModel.getSystemPromptForActivityType(type)
        
        // Update the active chat's system prompt
        self.chatViewModel.activeChat?.systemPrompt = systemPrompt
    }
    
    private let availableModels = [
        "qwen3:0.6b",
        "gemma3:1b",
        "qwen3:1.7b",
        "granite3.3:2b",
        "gemma3:4b",
        "granite3.3:8b"
    ]
    
    // Temporary client list - will be replaced with actual client data
    private let clients = [
        "Select a Client",  // Placeholder client first
        "Add New Client"
    ]
    
    private func showNoteFormatInfo() {
        showingNoteFormatInfo = true
    }
    
    init(ollamaKit: Binding<OllamaKit>) {
        self._ollamaKit = ollamaKit
    }
    
    var body: some View {
        @Bindable var bindableChatViewModel = chatViewModel
        
        Form {
            // Client Section
            Section {
                clientPicker
            } header: {
                Text("Client")
            }
            
            // Note Format Section
            Section {
                noteFormatView
            } header: {
                Text("Note Format")
            }
            
            // Template Section
            Section {
                noteTemplateView
            } header: {
                Text("Additional Note Format Template/Information")
            } footer: {
                Text("Enter or paste a sample note format that you'd like the system to reference when generating notes.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Task Section
            Section {
                Picker("Choose Activity", selection: Binding(
                    get: { chatViewModel.selectedTask },
                    set: { chatViewModel.selectedTask = $0 }
                )) {
                    ForEach(taskOptions, id: \.self) { task in
                        Text(task).tag(task)
                    }
                }
            } header: {
                Text("Activity")
            }
            .onChange(of: chatViewModel.selectedTask) { _, _ in
                updateSystemPrompt()
            }
            
            // Assistant Section
            Section {
                // Picker for choosing from downloaded models
                Picker("Choose an Assistant", selection: Binding(
                    get: { chatViewModel.activeChat?.model ?? "" },
                    set: { newModel in
                        chatViewModel.activeChat?.model = newModel
                    }
                )) {
                    ForEach(chatViewModel.models, id: \.self) { model in
                        Text(AssistantModel.nameFor(modelId: model)).tag(model)
                    }
                }
            } header: {
                Text("Assistant")
            }
            
            // Additional Assistants Section
            Section {
                // Picker for selecting model to download
                Picker("Choose an Assistant", selection: $selectedDownloadModel) {
                    ForEach(AssistantModel.all, id: \.modelId) { assistant in
                        Text(assistant.name).tag(assistant.modelId)
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
                        Text("Download Assistant")
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
                    Text("Additional Assistants")
                    
                    Spacer()
                    
                    Button(action: { showModelInfoPopover = true }) {
                        Image(systemName: "info.circle")
                            .foregroundColor(Color.euniPrimary)
                    }
                    .buttonStyle(.accessoryBar)
                    .popover(isPresented: $showModelInfoPopover) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Available Assistants")
                                .font(.headline)
                                .foregroundColor(Color.euniText)
                                .padding(.bottom, 8)
                            
                            Text("These Assistants use large language models optimized to work on most MacBooks with Apple Silicon and at least 8GB of memory.")
                                .foregroundColor(Color.euniText)
                            
                            Text("Assistant Information:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(Color.euniText)
                                .padding(.top, 8)
                            
                            // Column titles
                            HStack {
                                Text("Assistant")
                                    .fontWeight(.bold)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("Size / Context")
                                    .fontWeight(.bold)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                Text("Model")
                                    .fontWeight(.bold)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            .foregroundColor(Color.euniText)
                            
                            Divider()
                            
                            // Assistant rows
                            Group {
                                ForEach(AssistantModel.all, id: \.modelId) { assistant in
                                    assistantRow(name: assistant.name, 
                                               description: assistant.description, 
                                               size: assistant.size, 
                                               model: assistant.modelId)
                                }
                            }
                        }
                        .padding()
                        .frame(minWidth: 350, maxWidth: 500)
                    }
                }
            }
            
            // Commented out Advanced Settings
            /*
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
                        systemPrompt = "You're Euni™ - Client Notes.  You are a clinical documentation assistant helping a therapist generate an insurance-ready psychotherapy progress note. You will use the information provided to you here to write a psychotherapy progress note using (unless otherwise instructed by the user) the BIRP format (Behavior, Intervention, Response, Plan). Requirements: Use clear, objective, and concise clinical language, Maintain gender-neutral pronouns, Do not make up quotes - only use exact quotes if and when provided by the user. Focus on observable behaviors, reported thoughts and feelings, therapist interventions, and clinical goals, Apply relevant approaches and techniques, including typical interventions and session themes, Use documentation language suitable for EHRs and insurance billing, If schemas, distortions, or core beliefs are addressed, name them using standard psychological terms, Conclude with a brief, action-oriented treatment plan. If this was the client's first telehealth session, document that informed consent for telehealth was obtained (verbal or written), that the client was informed of potential risks and limitations, that the therapists license or registration number was provided, and that the therapist made efforts to identify local emergency resources relevant to the client's location. If this was a subsequent telehealth session, document that the therapist confirmed the client's full name and present physical address, assessed the appropriateness of continuing via telehealth, and ensured confidentiality and safety using best practices for secure communication. If the client expressed suicidal ideation or self harm during the session, document this clearly and clinically. Include: (1) the client's specific statements or behaviors that prompted risk assessment, (2) identified risk and protective factors, (3) the outcome of any suicide risk assessment and rationale for the therapists clinical judgment, (4) any safety plan developed collaboratively with the client, and (5) follow-up arrangements. Use objective language and avoid vague phrasing. If a formal assessment tool was used, reference it. Ensure the note reflects ethical care, clinical reasoning, and legal defensibility."
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
            */
        }
        .onChange(of: self.chatViewModel.activeChat) { _, newValue in
            if let model = newValue?.model {
                self.selectedDownloadModel = model
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
        .onAppear {
            chatViewModel.fetchModels(ollamaKit)
        }
    }
    
    private var clientPicker: some View {
        Picker("Choose Client", selection: Binding(
            get: { chatViewModel.selectedClientID ?? UUID() },
            set: { newValue in
                if newValue == UUID(uuidString: "00000000-0000-0000-0000-000000000000") {
                    showAddClientSheet = true
                } else {
                    chatViewModel.selectedClientID = newValue
                }
            }
        )) {
            ForEach(chatViewModel.clients) { client in
                Text(client.identifier).tag(client.id)
            }
            Text("Add New Client").tag(UUID(uuidString: "00000000-0000-0000-0000-000000000000")!)
        }
        .sheet(isPresented: $showAddClientSheet, onDismiss: {
            if let last = chatViewModel.clients.last {
                chatViewModel.selectedClientID = last.id
            }
        }) {
            NavigationStack {
                AddClientView()
            }
            .frame(minWidth: 600, minHeight: 900)
        }
    }
    
    private var noteFormatView: some View {
        HStack {
            Picker("Note Format", selection: Binding(
                get: { chatViewModel.selectedNoteFormat },
                set: { chatViewModel.selectedNoteFormat = $0 }
            )) {
                ForEach(chatViewModel.availableNoteFormats) { format in
                    Text(format.id).tag(format.id)
                }
            }
            
            Button(action: { showNoteFormatInfo() }) {
                Image(systemName: "info.circle")
                    .foregroundColor(Color.euniPrimary)
            }
            .buttonStyle(.borderless)
            .popover(isPresented: $showingNoteFormatInfo) {
                noteFormatInfoPopover
            }
        }
    }
    
    private var noteFormatInfoPopover: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Note Format Information")
                .font(.headline)
                .padding(.bottom, 8)
            
            ForEach(chatViewModel.availableNoteFormats) { format in
                VStack(alignment: .leading, spacing: 4) {
                    Text("**\(format.id)** - \(format.name)")
                        .font(.subheadline)
                    Text(format.focus)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(format.description)
                        .font(.caption)
                        .padding(.top, 4)
                }
                .padding(.bottom, 12)
            }
        }
        .padding()
        .frame(width: 400)
    }
    
    private var noteTemplateView: some View {
        TextEditor(text: Binding(
            get: { chatViewModel.noteFormatTemplate },
            set: { chatViewModel.noteFormatTemplate = $0 }
        ))
        .frame(height: 100)
        .font(.system(.body, design: .monospaced))
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
                            selectedDownloadModel = modelName
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
    
    @ViewBuilder
    func assistantRow(name: String, description: String, size: String, model: String) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundColor(Color.euniText.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(size)
                .frame(maxWidth: .infinity, alignment: .center)
                .font(.caption)
                .foregroundColor(Color.euniText)
            
            Text(model)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .font(.caption)
                .foregroundColor(Color.euniText)
        }
    }
}

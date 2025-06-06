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
    @Environment(AIBackendManager.self) private var aiBackendManager
    
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
    @State private var clientToDelete: UUID? = nil
    @State private var showDeleteClientConfirmation = false
    @State private var showFinalDeleteConfirmation = false
    
    @Default(.defaultHost) private var host
    @Default(.defaultSystemPrompt) private var systemPrompt
    @Default(.defaultTemperature) private var temperature
    @Default(.defaultTopP) private var topP
    @Default(.defaultTopK) private var topK
    @Default(.selectedAIBackend) private var selectedAIBackend
    
    private let availableModels = [
        "qwen3:0.6b",
        "gemma3:1b",
        "qwen3:1.7b",
        "granite3.3:2b",
        "gemma3:4b",
        "granite3.3:8b"
    ]
    
    init(ollamaKit: Binding<OllamaKit>) {
        self._ollamaKit = ollamaKit
    }
    
    var body: some View {
        @Bindable var bindableChatViewModel = chatViewModel
        
        Form {
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
            
            // Additional Assistants Section
            Section {
                // Show current backend
                HStack {
                    Text("Using:")
                        .foregroundColor(.secondary)
                    Text(selectedAIBackend.displayName)
                        .fontWeight(.medium)
                        .foregroundColor(Color.euniPrimary)
                    Spacer()
                    if selectedAIBackend == .ollamaKit {
                        Text("Downloads from Ollama")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Downloads from HuggingFace")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
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
                        HStack {
                            Image(systemName: selectedAIBackend == .ollamaKit ? "arrow.down.circle" : "arrow.down.doc")
                            Text("Download Assistant")
                        }
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
                            
                            // Show backend-specific info
                            if selectedAIBackend == .llamaCpp {
                                Text("Using built-in Llama: Models are downloaded directly from HuggingFace and run with our integrated llama.cpp engine.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 4)
                            } else {
                                Text("Using Ollama: Models are downloaded through the Ollama application and managed by the Ollama server.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 4)
                            }
                            
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
            
            // Client Removal Section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Remove a client and all associated records")
                        .foregroundColor(Color.euniError)
                        .font(.caption)
                    
                    Picker("Select Client to Remove", selection: $clientToDelete) {
                        Text("Select a Client").tag(nil as UUID?)
                        ForEach(chatViewModel.clients) { client in
                            Text(client.identifier).tag(client.id as UUID?)
                        }
                    }
                    
                    if clientToDelete != nil {
                        Button(role: .destructive) {
                            showDeleteClientConfirmation = true
                        } label: {
                            Label("Delete Selected Client", systemImage: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.borderless)
                        .padding(.top, 4)
                    }
                }
            } header: {
                Text("Remove Client")
            } footer: {
                Text("Warning: This will permanently delete the client and all their session notes, treatment plans, and brainstorm sessions.")
                    .foregroundColor(Color.euniError)
            }
            
            // Copyright section at the bottom
            Section {
                Text("Euni™ - Client Notes © 2025 Tucuxi, Inc.")
                    .font(.caption)
                    .foregroundColor(Color.euniSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }
        }
        .onChange(of: self.chatViewModel.activeChat) { _, newValue in
            if let model = newValue?.model {
                self.selectedDownloadModel = model
            }
            
            // Only update host for OllamaKit
            if selectedAIBackend == .ollamaKit {
                if let host = newValue?.host {
                    self.host = host
                }
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
        .onChange(of: selectedAIBackend) { _, _ in
            // Refresh models when backend changes
            if selectedAIBackend == .ollamaKit {
                chatViewModel.fetchModels(ollamaKit)
            } else {
                chatViewModel.fetchModelsFromBackend()
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
            if selectedAIBackend == .ollamaKit {
                chatViewModel.fetchModels(ollamaKit)
            } else {
                chatViewModel.fetchModelsFromBackend()
            }
        }
        .alert("Delete Client?", isPresented: $showDeleteClientConfirmation) {
            Button("Cancel", role: .cancel) {
                clientToDelete = nil
            }
            Button("Proceed", role: .destructive) {
                showFinalDeleteConfirmation = true
            }
        } message: {
            if let clientID = clientToDelete,
               let client = chatViewModel.clients.first(where: { $0.id == clientID }) {
                Text("Are you sure you want to delete the client '\(client.identifier)' and all their associated records?")
            }
        }
        .alert("Final Confirmation", isPresented: $showFinalDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                clientToDelete = nil
            }
            Button("Yes, Delete Everything", role: .destructive) {
                deleteSelectedClient()
            }
        } message: {
            if let clientID = clientToDelete,
               let client = chatViewModel.clients.first(where: { $0.id == clientID }) {
                Text("This will permanently delete '\(client.identifier)' and ALL their records. This action cannot be undone.\n\nAre you absolutely sure?")
            }
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
    
    private func showNoteFormatInfo() {
        showingNoteFormatInfo = true
    }
    
    // Backend-aware model pulling functionality
    func pullModel(_ modelName: String) {
        guard !isPullingModel else { return }
        
        isPullingModel = true
        pullProgress = 0.0
        pullStatus = "Starting download..."
        
        Task {
            if selectedAIBackend == .ollamaKit {
                await pullOllamaModel(modelName)
            } else {
                await pullLlamaKitModel(modelName)
            }
            
            await MainActor.run {
                isPullingModel = false
                
                // Refresh models list to show the newly pulled model
                if selectedAIBackend == .ollamaKit {
                    chatViewModel.fetchModels(ollamaKit)
                } else {
                    chatViewModel.fetchModelsFromBackend()
                }
                
                // If the model was successfully pulled, update the selected model
                if pullStatus == "success" {
                    // Set a short delay to allow models list to refresh
                    Task {
                        try? await Task.sleep(for: .seconds(1))
                        
                        if selectedAIBackend == .ollamaKit {
                            if chatViewModel.models.contains(modelName) {
                                selectedDownloadModel = modelName
                                // Also update the active chat's model
                                chatViewModel.activeChat?.model = modelName
                            }
                        } else {
                            // For LlamaKit, update the default model path
                            if let assistant = AssistantModel.all.first(where: { $0.modelId == modelName }),
                               let fileName = assistant.llamaKitFileName {
                                let modelPath = getModelDownloadPath().appendingPathComponent(fileName).path
                                Defaults[.llamaKitModelPath] = modelPath
                                
                                // Try to load the model in the backend
                                try? await aiBackendManager.loadModelForLlamaCpp(modelPath)
                            }
                        }
                        
                        // Show success status briefly, then clear
                        let assistant = AssistantModel.all.first(where: { $0.modelId == modelName })
                        pullStatus = "Successfully downloaded \(assistant?.name ?? modelName)"
                        
                        try? await Task.sleep(for: .seconds(3))
                        if pullStatus == "Successfully downloaded \(assistant?.name ?? modelName)" {
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
    
    func pullLlamaKitModel(_ modelName: String) async {
        guard let assistant = AssistantModel.all.first(where: { $0.modelId == modelName }),
              let downloadURL = assistant.downloadURL,
              let fileName = assistant.llamaKitFileName,
              let url = URL(string: downloadURL) else {
            await MainActor.run {
                pullStatus = "Error: Invalid model configuration for \(modelName)"
                isPullingModel = false
            }
            return
        }
        
        let downloadPath = getModelDownloadPath()
        let destinationURL = downloadPath.appendingPathComponent(fileName)
        
        // Create models directory if it doesn't exist
        do {
            try FileManager.default.createDirectory(at: downloadPath, withIntermediateDirectories: true)
        } catch {
            await MainActor.run {
                pullStatus = "Error: Could not create models directory"
                isPullingModel = false
            }
            return
        }
        
        // Check if model already exists
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            await MainActor.run {
                pullProgress = 1.0
                pullStatus = "success"
            }
            return
        }
        
        do {
            await MainActor.run {
                pullStatus = "Downloading \(assistant.name) from HuggingFace..."
            }
            
            // Create a delegate to track download progress
            let delegate = DownloadDelegate { progress in
                Task { @MainActor in
                    self.pullProgress = progress
                    self.pullStatus = "Downloading \(assistant.name)... \(Int(progress * 100))%"
                }
            }
            
            let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
            let (tempURL, response) = try await session.download(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode >= 400 {
                    await MainActor.run {
                        pullStatus = "Error: HTTP \(httpResponse.statusCode) from HuggingFace"
                        isPullingModel = false
                    }
                    return
                }
            }
            
            // Move downloaded file to final location
            try FileManager.default.moveItem(at: tempURL, to: destinationURL)
            
            await MainActor.run {
                pullProgress = 1.0
                pullStatus = "success"
            }
            
        } catch {
            await MainActor.run {
                pullStatus = "Error: \(error.localizedDescription)"
                isPullingModel = false
            }
        }
    }
    
    private func getModelDownloadPath() -> URL {
        // Use the app's Application Support directory (proper location for app-specific data)
        let appSupportPaths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupportPath = appSupportPaths.first!
        
        // Create app-specific subdirectory
        let appName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "ClientNote"
        return appSupportPath
            .appendingPathComponent(appName, isDirectory: true)
            .appendingPathComponent("LlamaKitModels", isDirectory: true)
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
    
    private func deleteSelectedClient() {
        guard let clientID = clientToDelete else { return }
        
        // Use the ChatViewModel method to delete the client
        chatViewModel.deleteClient(clientID)
        
        // Reset our local state
        clientToDelete = nil
    }
}

// Download delegate for tracking progress
class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    private let progressHandler: (Double) -> Void
    
    init(progressHandler: @escaping (Double) -> Void) {
        self.progressHandler = progressHandler
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        progressHandler(progress)
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        progressHandler(1.0)
    }
}

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
    @State private var selectedDownloadModel: String = "Flash"
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
        "Flash",
        "Scout", 
        "Runner",
        "Focus",
        "Sage",
        "Deep Thought"
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
                    ForEach(AssistantModel.all, id: \.name) { assistant in
                        Text(assistant.name).tag(assistant.name)
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
    func pullModel(_ assistantName: String) {
        guard !isPullingModel else { return }
        
        // Find the assistant by name
        guard let assistant = AssistantModel.all.first(where: { $0.name == assistantName }) else {
            pullStatus = "Error: Unknown assistant \(assistantName)"
            return
        }
        
        isPullingModel = true
        pullProgress = 0.0
        pullStatus = "Starting download..."
        
        // Capture values from assistant to avoid Sendable issues
        let assistantModelId = assistant.modelId
        
        Task {
            if selectedAIBackend == .ollamaKit {
                await pullOllamaModel(assistantModelId) // Use modelId for Ollama
            } else {
                await pullLlamaKitModel(assistantName) // Use name for LlamaKit
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
                if pullStatus.starts(with: "Successfully downloaded") {
                    // Set a short delay to allow models list to refresh
                    Task {
                        try? await Task.sleep(for: .seconds(1))
                        
                        if selectedAIBackend == .ollamaKit {
                            // For Ollama, check if the model ID is available
                            if chatViewModel.models.contains(assistantModelId) {
                                selectedDownloadModel = assistantName
                            // Also update the active chat's model
                                chatViewModel.activeChat?.model = assistantModelId
                            }
                        } else {
                            // For LlamaKit, check if the friendly name is available
                            if chatViewModel.models.contains(assistantName) {
                                selectedDownloadModel = assistantName
                                // Update the active chat's model to use the friendly name
                                chatViewModel.activeChat?.model = assistantName
                            }
                        }
                        
                        // Show success status briefly, then clear
                        pullStatus = "Successfully downloaded \(assistantName)"
                        
                        try? await Task.sleep(for: .seconds(3))
                        if pullStatus == "Successfully downloaded \(assistantName)" {
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
    
    func pullLlamaKitModel(_ assistantName: String) async {
        guard let assistant = AssistantModel.all.first(where: { $0.name == assistantName }),
              let downloadURL = assistant.downloadURL,
              let fileName = assistant.llamaKitFileName,
              let url = URL(string: downloadURL) else {
            await MainActor.run {
                pullStatus = "Error: Invalid model configuration for \(assistantName)"
                isPullingModel = false
            }
            return
        }
        
        let downloadPath = getModelDownloadPath()
        let destinationURL = downloadPath.appendingPathComponent(fileName)
        
        // Ensure models directory exists with proper permissions
        do {
            try FileManager.default.createDirectory(at: downloadPath, withIntermediateDirectories: true, attributes: [
                .posixPermissions: 0o755
            ])
            print("DEBUG: Created/verified models directory at: \(downloadPath.path)")
        } catch {
            await MainActor.run {
                pullStatus = "Error: Could not create models directory: \(error.localizedDescription)"
                isPullingModel = false
            }
            return
        }
        
        // Check if file already exists
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            await MainActor.run {
                pullStatus = "\(assistantName) already downloaded"
                isPullingModel = false
            }
            return
        }
        
        // Capture assistant properties before async closures to avoid Sendable issues
        let assistantDisplayName = assistant.name
        
        do {
            await MainActor.run {
                pullStatus = "Downloading \(assistantDisplayName) from HuggingFace..."
                pullProgress = 0.1
            }
            
            // Use data task with manual file writing for better sandbox control
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 300 // 5 minute timeout
            config.timeoutIntervalForResource = 1800 // 30 minute timeout
            
            let session = URLSession(configuration: config)
            
            // Create a temporary file in our own directory for better sandbox control
            let tempDirectory = downloadPath.appendingPathComponent("temp", isDirectory: true)
            try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true, attributes: nil)
            let tempURL = tempDirectory.appendingPathComponent("\(fileName).download")
            
            print("DEBUG: Using controlled temporary location: \(tempURL.path)")
            
            // Use download task with delegate for proper progress reporting
            await MainActor.run {
                pullStatus = "Starting download of \(assistantDisplayName)..."
                pullProgress = 0.1
            }
            
            // Create download task with progress reporting using delegate
            let progressDelegate = ProgressDelegate { progress in
                Task { @MainActor in
                    // Map progress to 0.1 to 0.9 range (leaving room for verification steps)
                    let mappedProgress = 0.1 + (progress * 0.8)
                    pullProgress = min(mappedProgress, 0.9)
                    
                    if progress > 0 {
                        let percentComplete = Int(progress * 100)
                        pullStatus = "Downloading \(assistantDisplayName)... \(percentComplete)%"
                    }
                }
            }
            
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                progressDelegate.completion = { result in
                    Task {
                        do {
                            let (tempLocation, response) = try result.get()
                            
                            // Validate response
                            if let httpResponse = response as? HTTPURLResponse {
                                guard httpResponse.statusCode == 200 else {
                                    throw URLError(.badServerResponse)
                                }
                            }
                            
                            await MainActor.run {
                                pullStatus = "Download complete, verifying \(assistantDisplayName)..."
                                pullProgress = 0.95
                            }
                            
                            // Verify file size
                            let attributes = try FileManager.default.attributesOfItem(atPath: tempLocation.path)
                            let fileSize = attributes[.size] as? Int64 ?? 0
                            print("DEBUG: Downloaded file size: \(fileSize) bytes")
                            
                            guard fileSize > 0 else {
                                throw URLError(.zeroByteResource)
                            }
                            
                            await MainActor.run {
                                pullStatus = "Installing \(assistantDisplayName)..."
                                pullProgress = 0.98
                            }
                            
                            // Remove existing file if it exists (race condition protection)
                            if FileManager.default.fileExists(atPath: destinationURL.path) {
                                try FileManager.default.removeItem(at: destinationURL)
                            }
                            
                            // Move the file to final destination
                            try FileManager.default.moveItem(at: tempLocation, to: destinationURL)
                            print("DEBUG: Successfully moved model file to: \(destinationURL.path)")
                            
                            continuation.resume()
                            
                        } catch {
                            print("DEBUG: Download failed with error: \(error)")
                            await MainActor.run {
                                pullStatus = "Download failed: \(error.localizedDescription)"
                                isPullingModel = false
                            }
                            continuation.resume(throwing: error)
                        }
                    }
                }
                
                let delegateSession = URLSession(configuration: config, delegate: progressDelegate, delegateQueue: nil)
                let downloadTask = delegateSession.downloadTask(with: url)
                downloadTask.resume()
            }
            
            // Verify the file exists at destination
            guard FileManager.default.fileExists(atPath: destinationURL.path) else {
                throw NSError(domain: "ModelDownload", code: 3, userInfo: [
                    NSLocalizedDescriptionKey: "Model file not found after installation"
                ])
            }
            
            await MainActor.run {
                pullStatus = "\(assistantDisplayName) downloaded successfully!"
                pullProgress = 1.0
                isPullingModel = false
            }
            
            // Clean up temporary directory
            try? FileManager.default.removeItem(at: tempDirectory)
            print("DEBUG: Cleaned up temporary directory")
            
            // Clean up session
            session.invalidateAndCancel()
            
        } catch {
            await MainActor.run {
                pullStatus = "Error downloading \(assistantDisplayName): \(error.localizedDescription)"
                isPullingModel = false
                pullProgress = 0.0
                print("DEBUG: Download error for \(assistantName): \(error)")
            }
        }
    }
    
    private func getModelDownloadPath() -> URL {
        // Use the app's Application Support directory (proper location for app-specific data)
        let appSupportPaths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupportPath = appSupportPaths.first!
        
        // Create app-specific subdirectory
        let appName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "ClientNote"
        let appDirectory = appSupportPath.appendingPathComponent(appName, isDirectory: true)
        let modelsDirectory = appDirectory.appendingPathComponent("LlamaKitModels", isDirectory: true)
        
        // Ensure directory exists with proper permissions
        do {
            try FileManager.default.createDirectory(at: modelsDirectory, 
                                                  withIntermediateDirectories: true,
                                                  attributes: [.posixPermissions: 0o755])
            print("DEBUG: Created/verified models directory at: \(modelsDirectory.path)")
        } catch {
            print("DEBUG: Failed to create models directory: \(error)")
            // Fallback to Documents if Application Support fails
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let fallbackPath = documentsPath.appendingPathComponent("ClientNote-Models", isDirectory: true)
            
            do {
                try FileManager.default.createDirectory(at: fallbackPath,
                                                      withIntermediateDirectories: true,
                                                      attributes: [.posixPermissions: 0o755])
                print("DEBUG: Using fallback models directory at: \(fallbackPath.path)")
                return fallbackPath
            } catch {
                print("DEBUG: Even fallback directory creation failed: \(error)")
            }
        }
        
        return modelsDirectory
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

// MARK: - Download Progress Delegate

private class ProgressDelegate: NSObject, URLSessionDownloadDelegate {
    private let progressHandler: (Double) -> Void
    var completion: ((Result<(URL, URLResponse), Error>) -> Void)?
    
    init(progressHandler: @escaping (Double) -> Void) {
        self.progressHandler = progressHandler
        super.init()
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { 
            print("DEBUG: ProgressDelegate - totalBytesExpectedToWrite is 0 or negative: \(totalBytesExpectedToWrite)")
            return 
        }
        
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        print("DEBUG: ProgressDelegate - Progress: \(progress * 100)% (\(totalBytesWritten)/\(totalBytesExpectedToWrite) bytes)")
        
        // Call progress handler directly on main queue
        progressHandler(progress)
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        print("DEBUG: ProgressDelegate - Download finished at: \(location.path)")
        print("DEBUG: ProgressDelegate - File exists at location: \(FileManager.default.fileExists(atPath: location.path))")
        
        do {
            // Verify file exists and get size immediately
            let attributes = try FileManager.default.attributesOfItem(atPath: location.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            print("DEBUG: ProgressDelegate - Downloaded file size: \(fileSize) bytes")
            
            guard fileSize > 0 else {
                throw NSError(domain: "DownloadError", code: 2, userInfo: [
                    NSLocalizedDescriptionKey: "Downloaded file is empty"
                ])
            }
            
            // Create our own temporary location in the app's container
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ClientNoteDownloads")
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
            
            let ourTempLocation = tempDir.appendingPathComponent(UUID().uuidString + ".tmp")
            
            // Move the file immediately to our controlled location before the system cleans it up
            try FileManager.default.moveItem(at: location, to: ourTempLocation)
            print("DEBUG: ProgressDelegate - Moved to controlled temp location: \(ourTempLocation.path)")
            
            // Store our controlled temporary location and response for completion
            if let response = downloadTask.response {
                completion?(.success((ourTempLocation, response)))
            } else {
                let error = NSError(domain: "DownloadError", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "No response received"
                ])
                completion?(.failure(error))
            }
            
        } catch {
            print("DEBUG: ProgressDelegate - Error handling downloaded file: \(error)")
            completion?(.failure(error))
        }
        
        // Clean up session after we've secured the file
        session.invalidateAndCancel()
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            print("DEBUG: ProgressDelegate - Download completed with error: \(error)")
            completion?(.failure(error))
            session.invalidateAndCancel()
        }
        // Success case is handled in didFinishDownloadingTo
    }
}

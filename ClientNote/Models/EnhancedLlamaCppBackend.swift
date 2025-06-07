import Foundation
import Combine
import os.log
import Defaults

// MARK: - Enhanced LlamaCpp Backend with Production Features
@MainActor
class EnhancedLlamaCppBackend: AIBackendProtocol {
    @Published var isReady: Bool = false
    @Published var status: String = "Not initialized"
    
    // Use the production-ready server manager
    private let serverManager = LlamaServerManager()
    private var cancellables = Set<AnyCancellable>()
    private var currentModelPath: String?
    
    init() {
        setupBindings()
    }
    
    // MARK: - AIBackendProtocol Implementation
    
    func initialize() async throws {
        status = "Initialized"
        print("DEBUG: Enhanced LlamaCpp backend initialized")
        
        // Check if we have a configured model path and auto-load it
        var modelPath = Defaults[.llamaKitModelPath]
        
        // MIGRATION: Replace old Q8_0 models with Q4_0 equivalents
        if !modelPath.isEmpty {
            let fileName = URL(fileURLWithPath: modelPath).lastPathComponent
            let migratedPath = migrateToQ4Model(currentPath: modelPath, currentFileName: fileName)
            if migratedPath != modelPath {
                print("DEBUG: Enhanced LlamaCpp - Migrating from Q8_0 to Q4_0 model")
                print("DEBUG: Enhanced LlamaCpp - Old: \(fileName)")
                print("DEBUG: Enhanced LlamaCpp - New: \(URL(fileURLWithPath: migratedPath).lastPathComponent)")
                modelPath = migratedPath
                Defaults[.llamaKitModelPath] = modelPath
            }
        }
        
        if !modelPath.isEmpty {
            print("DEBUG: Enhanced LlamaCpp - Auto-loading configured model: \(modelPath)")
            do {
                try await loadModel(at: modelPath)
                print("DEBUG: Enhanced LlamaCpp - Auto-load completed successfully")
            } catch {
                print("DEBUG: Enhanced LlamaCpp - Auto-load failed: \(error)")
                status = "Error loading model: \(error.localizedDescription)"
            }
        } else {
            print("DEBUG: Enhanced LlamaCpp - No model path configured, waiting for manual model selection")
            status = "No model configured"
        }
    }
    
    func loadModel(at path: String) async throws {
        print("DEBUG: Enhanced LlamaCpp - Loading model at: \(path)")
        
        // Check if model file exists
        guard FileManager.default.fileExists(atPath: path) else {
            let errorMsg = "Model file not found at path: \(path)"
            status = "Error: \(errorMsg)"
            throw AIBackendError.modelLoadFailed(errorMsg)
        }
        
        do {
            // Use the production-ready server manager
            try await serverManager.startServer(modelPath: path)
            
            currentModelPath = path
            status = "Model loaded: \(friendlyModelName(for: path))"
            isReady = true
            
            // Store successful model path
            Defaults[.llamaKitModelPath] = path
            
            print("DEBUG: Enhanced LlamaCpp - Model loaded successfully")
            
        } catch {
            status = "Error loading model: \(error.localizedDescription)"
            isReady = false
            throw AIBackendError.modelLoadFailed(error.localizedDescription)
        }
    }
    
    func listModels() async throws -> [String] {
        print("DEBUG: Enhanced LlamaCpp - listModels() called")
        
        var availableModels: [String] = []
        
        // First, add the currently loaded model if any
        if let modelPath = currentModelPath {
            let friendlyName = friendlyModelName(for: modelPath)
            availableModels.append(friendlyName)
            print("DEBUG: Enhanced LlamaCpp - Added currently loaded model: \(friendlyName)")
        }
        
        // Scan bundled models first, then user downloads directory
        let downloadPaths = [
            getBundledModelsPath(),      // Check bundled models first (Resources/)
            getModelDownloadPath()       // User's downloaded models (LlamaKitModels/)
        ]
        
        print("DEBUG: Enhanced LlamaCpp - Scanning \(downloadPaths.count) directories for models")
        
        for downloadPath in downloadPaths {
            print("DEBUG: Enhanced LlamaCpp - Scanning directory: \(downloadPath.path)")
            
            do {
                let contents = try FileManager.default.contentsOfDirectory(at: downloadPath, 
                                                                         includingPropertiesForKeys: nil)
                
                print("DEBUG: Enhanced LlamaCpp - Found \(contents.count) items in \(downloadPath.path)")
                
                for fileURL in contents {
                    let fileName = fileURL.lastPathComponent
                    let fileExtension = fileURL.pathExtension
                    
                    if fileExtension == "gguf" {
                        let friendlyName = friendlyModelName(for: fileURL.path)
                        print("DEBUG: Enhanced LlamaCpp - Found GGUF model: \(fileName) -> \(friendlyName)")
                        
                        // Avoid duplicates
                        if !availableModels.contains(friendlyName) {
                            availableModels.append(friendlyName)
                            print("DEBUG: Enhanced LlamaCpp - Added model to list: \(friendlyName)")
                        } else {
                            print("DEBUG: Enhanced LlamaCpp - Skipped duplicate model: \(friendlyName)")
                        }
                    }
                }
            } catch {
                print("DEBUG: Enhanced LlamaCpp - Could not scan directory \(downloadPath.path): \(error)")
            }
        }
        
        print("DEBUG: Enhanced LlamaCpp - Total models found: \(availableModels.count)")
        return availableModels
    }
    
    func chat(request: AIChatRequest, onPartialResponse: @escaping (String) -> Void) async throws -> String {
        guard isReady else {
            print("DEBUG: Enhanced LlamaCpp - Chat called but backend not ready")
            throw AIBackendError.notReady
        }
        
        print("DEBUG: Enhanced LlamaCpp - Starting chat with \(request.messages.count) messages")
        
        // Convert AIMessage to simple tuples
        let chatMessages = request.messages.map { message in
            (role: message.openAIRole, content: message.content)
        }
        
        do {
            // Use the enhanced server manager's chat functionality
            let response = try await performEnhancedChat(
                messages: chatMessages,
                temperature: request.temperature,
                progressHandler: onPartialResponse
            )
            
            print("DEBUG: Enhanced LlamaCpp - Chat completed successfully. Response length: \(response.count)")
            return response
            
        } catch {
            print("DEBUG: Enhanced LlamaCpp - Chat failed with error: \(error)")
            throw AIBackendError.chatFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Enhanced Chat Implementation
    
    private func performEnhancedChat(
        messages: [Any], // Using Any for now, will be converted to proper format
        temperature: Double? = nil,
        progressHandler: @escaping (String) -> Void
    ) async throws -> String {
        guard serverManager.serverStatus == .ready else {
            throw LlamaServerManager.ServerError.serverNotReady
        }
        
        let url = URL(string: "http://127.0.0.1:8080/v1/chat/completions")!
        
        // Convert messages to the format expected by the server
        let openAIMessages = messages.compactMap { message -> [String: String]? in
            if let aiMessage = message as? (role: String, content: String) {
                return ["role": aiMessage.role, "content": aiMessage.content]
            }
            return nil
        }
        
        let requestBody: [String: Any] = [
            "model": "model",
            "messages": openAIMessages,
            "temperature": temperature ?? 0.7,
            "stream": true
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw LlamaServerManager.ServerError.requestEncodingFailed(error.localizedDescription)
        }
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        let session = URLSession(configuration: config)
        
        return try await withCheckedThrowingContinuation { continuation in
            let task = session.dataTask(with: request) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: LlamaServerManager.ServerError.requestFailed(error.localizedDescription))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    continuation.resume(throwing: LlamaServerManager.ServerError.invalidResponse)
                    return
                }
                
                guard httpResponse.statusCode == 200 else {
                    continuation.resume(throwing: LlamaServerManager.ServerError.httpError(httpResponse.statusCode))
                    return
                }
                
                guard let data = data else {
                    continuation.resume(throwing: LlamaServerManager.ServerError.noData)
                    return
                }
                
                // Process streaming response
                let responseString = String(data: data, encoding: .utf8) ?? ""
                let fullResponse = self.processStreamingResponse(responseString, progressHandler: progressHandler)
                continuation.resume(returning: fullResponse)
            }
            
            task.resume()
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func setupBindings() {
        // Bind server manager status to our published properties
        serverManager.$serverStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] serverStatus in
                self?.updateStatusFromServerManager(serverStatus)
            }
            .store(in: &cancellables)
    }
    
    private func updateStatusFromServerManager(_ serverStatus: LlamaServerManager.ServerStatus) {
        switch serverStatus {
        case .stopped:
            isReady = false
            status = "Server stopped"
            
        case .starting:
            isReady = false
            status = "Starting server..."
            
        case .loadingModel(let progress):
            isReady = false
            status = "Loading model... \(Int(progress * 100))%"
            
        case .ready:
            isReady = true
            if let modelPath = currentModelPath {
                status = "Model loaded: \(friendlyModelName(for: modelPath))"
            } else {
                status = "Server ready"
            }
            
        case .error(let message):
            isReady = false
            status = "Error: \(message)"
            
        case .crashed:
            isReady = false
            status = "Server crashed - attempting recovery"
        }
    }
    
    nonisolated private func processStreamingResponse(_ responseString: String, progressHandler: @escaping (String) -> Void) -> String {
        var fullResponse = ""
        let lines = responseString.components(separatedBy: "\n")
        
        for line in lines {
            if line.hasPrefix("data: ") {
                let jsonString = String(line.dropFirst(6))
                if jsonString == "[DONE]" {
                    break
                }
                
                guard let data = jsonString.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let choices = json["choices"] as? [[String: Any]],
                      let firstChoice = choices.first,
                      let delta = firstChoice["delta"] as? [String: Any],
                      let content = delta["content"] as? String else {
                    continue
                }
                
                fullResponse += content
                progressHandler(content)
            }
        }
        
        return fullResponse
    }
    
    private func migrateToQ4Model(currentPath: String, currentFileName: String) -> String {
        // Mapping of old Q8_0 files to new Q4_0 files
        let migrationMap: [String: String] = [
            "Qwen3-0.6B-Q8_0.gguf": "Qwen3-0.6B-Q4_0.gguf",
            "gemma-3-1b-it-Q8_0.gguf": "gemma-3-1b-it-Q4_0.gguf", 
            "Qwen3-1.7B-Q8_0.gguf": "Qwen3-1.7B-Q4_0.gguf",
            "granite-3.3-2b-instruct-Q8_0.gguf": "granite-3.3-2b-instruct-Q4_0.gguf",
            "gemma-3-4b-it-Q8_0.gguf": "gemma-3-4b-it-Q4_0.gguf",
            "granite-3.3-8b-instruct-Q8_0.gguf": "granite-3.3-8b-instruct-Q4_0.gguf"
        ]
        
        guard let newFileName = migrationMap[currentFileName] else {
            // No migration needed
            return currentPath
        }
        
        // Replace the filename in the path
        let directory = URL(fileURLWithPath: currentPath).deletingLastPathComponent()
        let newPath = directory.appendingPathComponent(newFileName).path
        
        // Check if the new Q4_0 file exists
        if FileManager.default.fileExists(atPath: newPath) {
            print("DEBUG: Enhanced LlamaCpp - Found Q4_0 replacement at: \(newPath)")
            return newPath
        } else {
            print("DEBUG: Enhanced LlamaCpp - Q4_0 replacement not found, keeping original: \(currentPath)")
            return currentPath
        }
    }
    
    private func friendlyModelName(for path: String) -> String {
        let fileName = URL(fileURLWithPath: path).lastPathComponent
        
        // Remove .gguf extension
        let nameWithoutExtension = fileName.replacingOccurrences(of: ".gguf", with: "")
        
        // Convert to more readable format
        return nameWithoutExtension
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
    }
    
    private func getBundledModelsPath() -> URL {
        guard let resourcePath = Bundle.main.resourcePath else {
            print("DEBUG: Enhanced LlamaCpp - Warning: Could not get bundle resource path")
            return URL(fileURLWithPath: "/tmp") // Fallback that won't have models
        }
        
        let bundledModelsPath = URL(fileURLWithPath: resourcePath)
        print("DEBUG: Enhanced LlamaCpp - Bundled models path: \(bundledModelsPath.path)")
        return bundledModelsPath
    }
    
    private func getModelDownloadPath() -> URL {
        let appSupportPaths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupportPath = appSupportPaths.first!
        let appName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "ClientNote"
        return appSupportPath
            .appendingPathComponent(appName, isDirectory: true)
            .appendingPathComponent("LlamaKitModels", isDirectory: true)
    }
    
    // MARK: - Public Access to Server Manager
    
    /// Provides access to the enhanced server manager for UI components
    var enhancedServerManager: LlamaServerManager {
        return serverManager
    }
}

// MARK: - Enhanced Backend Extension
// Note: OpenAIChatMessage, OpenAIChatRequest, and AIMessage.openAIRole 
// are already defined in AIBackend.swift 
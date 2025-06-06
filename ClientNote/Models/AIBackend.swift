import Foundation
import OllamaKit
import Defaults

// MARK: - Common Data Structures

struct AIMessage {
    enum Role: String, CaseIterable {
        case system = "system"
        case user = "user"
        case assistant = "assistant"
    }
    
    let role: Role
    let content: String
}

struct AIChatRequest {
    let model: String
    let messages: [AIMessage]
    let temperature: Double?
    let topP: Double?
    let topK: Int?
}

struct AIStreamingResponse {
    let content: String
    let isComplete: Bool
    let tokensPerSecond: Double?
}

// MARK: - AI Backend Protocol

@MainActor
protocol AIBackendProtocol: ObservableObject {
    var isReady: Bool { get }
    var status: String { get }
    
    func initialize() async throws
    func loadModel(at path: String) async throws
    func listModels() async throws -> [String]
    func chat(request: AIChatRequest, onPartialResponse: @escaping (String) -> Void) async throws -> String
}

// MARK: - FreeChat-Style LlamaKit Backend Implementation (DEPRECATED)
/*
@MainActor
class LlamaKitBackend: AIBackendProtocol {
    @Published var isReady: Bool = false
    @Published var status: String = "Not initialized"
    
    nonisolated(unsafe) private var serverProcess: Process?
    private var currentModelPath: String?
    private let host = "127.0.0.1"
    private let port = "8690"
    private var contextLength = 8000
    private let healthChecker = ServerHealthChecker()
    
    init() {
        self.healthChecker.updateURL(URL(string: "http://\(host):\(port)/health"))
    }
    
    func initialize() async throws {
        status = "Initialized"
        print("DEBUG: FreeChat-style LlamaKit backend initialized")
        
        // Check if we have a configured model path and auto-load it
        let modelPath = Defaults[.llamaKitModelPath]
        if !modelPath.isEmpty {
            print("DEBUG: FreeChatBackend - Auto-loading configured model: \(modelPath)")
            do {
                try await loadModel(at: modelPath)
                print("DEBUG: FreeChatBackend - Auto-load completed successfully")
            } catch {
                print("DEBUG: FreeChatBackend - Auto-load failed: \(error)")
                // Don't throw here - let the user manually trigger loading if needed
                status = "Error loading model: \(error.localizedDescription)"
            }
        } else {
            print("DEBUG: FreeChatBackend - No model path configured, waiting for manual model selection")
            status = "No model configured"
        }
    }
    
    func loadModel(at path: String) async throws {
        status = "Loading model..."
        isReady = false
        
        print("DEBUG: FreeChatBackend - Loading model at: \(path)")
        
        // Check if model file exists
        guard FileManager.default.fileExists(atPath: path) else {
            let errorMsg = "Model file not found at path: \(path)"
            status = "Error: \(errorMsg)"
            throw AIBackendError.modelLoadFailed(errorMsg)
        }
        
        // Stop any existing server
        stopServer()
        
        // Start the server with the model
        try await startServer(modelPath: path)
        
        currentModelPath = path
        status = "Model loaded: \(friendlyModelName(for: path))"
        isReady = true
        
        print("DEBUG: FreeChatBackend - Model loaded successfully")
    }
    
    func listModels() async throws -> [String] {
        if let modelPath = currentModelPath {
            let friendlyName = friendlyModelName(for: modelPath)
            return [friendlyName]
        }
        return []
    }
    
    func chat(request: AIChatRequest, onPartialResponse: @escaping (String) -> Void) async throws -> String {
        guard isReady else {
            print("DEBUG: FreeChatBackend - Chat called but backend not ready")
            throw AIBackendError.notReady
        }
        
        print("DEBUG: FreeChatBackend - Starting chat with \(request.messages.count) messages")
        
        // Convert AIMessage to FreeChat format
        let chatMessages = request.messages.map { message in
            FreeChatMessage(role: message.freeChatRole, content: message.content)
        }
        
        do {
            let response = try await performChat(
                messages: chatMessages,
                temperature: request.temperature,
                progressHandler: onPartialResponse
            )
            
            print("DEBUG: FreeChatBackend - Chat completed successfully. Response length: \(response.count)")
            return response
            
        } catch {
            print("DEBUG: FreeChatBackend - Chat failed with error: \(error)")
            throw AIBackendError.chatFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Private Server Management
    
    private func startServer(modelPath: String) async throws {
        guard serverProcess?.isRunning != true else { return }
        
        print("DEBUG: FreeChatBackend - Starting llama.cpp server")
        
        // Configure health checker for this server instance
        healthChecker.updateURL(URL(string: "http://\(host):\(port)/health"))
        print("DEBUG: FreeChatBackend - Health checker configured for: http://\(host):\(port)/health")
        
        serverProcess = Process()
        
        // Find the llama-server executable
        guard let serverExecutable = findLlamaServerExecutable() else {
            throw AIBackendError.modelLoadFailed("llama-server executable not found")
        }
        
        // Check if the executable has proper permissions
        let fileManager = FileManager.default
        if !fileManager.isExecutableFile(atPath: serverExecutable.path) {
            print("DEBUG: FreeChatBackend - Executable permissions missing for: \(serverExecutable.path)")
            
            // Try to make it executable
            do {
                var attributes = try fileManager.attributesOfItem(atPath: serverExecutable.path)
                var permissions = (attributes[FileAttributeKey.posixPermissions] as? Int) ?? 0
                permissions |= 0o755 // Add execute permissions
                attributes[FileAttributeKey.posixPermissions] = permissions
                try fileManager.setAttributes(attributes, ofItemAtPath: serverExecutable.path)
                print("DEBUG: FreeChatBackend - Set executable permissions on: \(serverExecutable.path)")
            } catch {
                print("DEBUG: FreeChatBackend - Failed to set executable permissions: \(error)")
                throw AIBackendError.modelLoadFailed("Executable permissions could not be set: \(error.localizedDescription)")
            }
        }
        
        let processes = ProcessInfo.processInfo.activeProcessorCount
        let threads = max(1, Int(ceil(Double(processes) / 3.0 * 2.0)))
        
        serverProcess!.executableURL = serverExecutable
        serverProcess!.arguments = [
            "--model", modelPath,
            "--threads", "\(threads)",
            "--ctx-size", "\(contextLength)",
            "--port", port,
            "--n-gpu-layers", "99",
            "--host", host
        ]
        
        print("DEBUG: FreeChatBackend - Server command: \(serverExecutable.path) \(serverProcess!.arguments!.joined(separator: " "))")
        
        // Capture output for debugging instead of suppressing it
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        serverProcess!.standardOutput = outputPipe
        serverProcess!.standardError = errorPipe
        
        // Set up async reading of output
        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
                print("DEBUG: llama-server stdout: \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
        }
        
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
                print("DEBUG: llama-server stderr: \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
        }
        
        do {
            try serverProcess!.run()
            print("DEBUG: FreeChatBackend - Process started successfully, PID: \(serverProcess!.processIdentifier)")
        } catch {
            print("DEBUG: FreeChatBackend - Failed to start process: \(error)")
            throw AIBackendError.modelLoadFailed("Failed to start server process: \(error.localizedDescription)")
        }
        
        print("DEBUG: FreeChatBackend - Process started, waiting for server to be ready...")
        
        // Wait for server to be ready
        try await waitForServerReady()
        
        print("DEBUG: FreeChatBackend - Server started successfully on port \(port)")
    }
    
    nonisolated private func stopServer() {
        if let process = serverProcess, process.isRunning {
            print("DEBUG: FreeChatBackend - Stopping server")
            
            // Clean up pipe handlers
            if let stdout = process.standardOutput as? Pipe {
                stdout.fileHandleForReading.readabilityHandler = nil
            }
            if let stderr = process.standardError as? Pipe {
                stderr.fileHandleForReading.readabilityHandler = nil
            }
            
            process.terminate()
            
            // Give it a moment to terminate gracefully
            DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                if process.isRunning {
                    process.terminate()
                    print("DEBUG: FreeChatBackend - Force terminated server process")
                }
            }
        }
        serverProcess = nil
    }
    
    private func findLlamaServerExecutable() -> URL? {
        // Try bundled executable first (sandbox-safe)
        if let bundledPath = Bundle.main.url(forAuxiliaryExecutable: "llama-server") {
            if FileManager.default.fileExists(atPath: bundledPath.path) {
                print("DEBUG: FreeChatBackend - Found bundled llama-server at: \(bundledPath.path)")
                return bundledPath
            }
        }
        
        // Try alternative bundled locations
        if let bundledPath = Bundle.main.url(forResource: "llama-server", withExtension: nil) {
            if FileManager.default.fileExists(atPath: bundledPath.path) {
                print("DEBUG: FreeChatBackend - Found bundled llama-server (resource) at: \(bundledPath.path)")
                return bundledPath
            }
        }
        
        // Check if llama-server is in the main bundle directory
        let bundleURL = Bundle.main.bundleURL.appendingPathComponent("llama-server")
        if FileManager.default.fileExists(atPath: bundleURL.path) {
            print("DEBUG: FreeChatBackend - Found llama-server in bundle root at: \(bundleURL.path)")
            return bundleURL
        }
        
        // Fallback to system paths (may not work in sandbox)
        let possiblePaths: [URL?] = [
            URL(fileURLWithPath: "/usr/local/bin/llama-server"),
            URL(fileURLWithPath: "/opt/homebrew/bin/llama-server"),
            Bundle.main.url(forAuxiliaryExecutable: "FreeChat-server")
        ]
        
        for path in possiblePaths {
            if let url = path {
                if FileManager.default.fileExists(atPath: url.path) {
                    print("DEBUG: FreeChatBackend - Found system llama-server at: \(url.path)")
                    return url
                }
            }
        }
        
        // Try to find via PATH (may not work in sandbox)
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        task.arguments = ["llama-server"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !path.isEmpty {
                    print("DEBUG: FreeChatBackend - Found llama-server via PATH: \(path)")
                    return URL(fileURLWithPath: path)
                }
            }
        } catch {
            print("DEBUG: FreeChatBackend - Error searching PATH: \(error)")
        }
        
        print("DEBUG: FreeChatBackend - llama-server executable not found anywhere")
        return nil
    }
    
    private func waitForServerReady() async throws {
        print("DEBUG: FreeChatBackend - Waiting for server to be ready...")
        print("DEBUG: FreeChatBackend - Health check URL: http://\(host):\(port)/health")
        
        var timeout = 120 // Increased to 2 minutes for large model loading
        let tickInterval = 2 // Check every 2 seconds
        var modelLoading = false
        var lastScore: Double = 0
        
        while timeout > 0 {
            print("DEBUG: FreeChatBackend - Health check attempt, timeout remaining: \(timeout)s")
            
            // Check if process is still running
            guard let process = serverProcess, process.isRunning else {
                print("DEBUG: FreeChatBackend - Server process terminated unexpectedly")
                throw AIBackendError.modelLoadFailed("Server process terminated unexpectedly")
            }
            
            // Check server health
            await healthChecker.check()
            let score = healthChecker.score
            lastScore = score
            
            print("DEBUG: FreeChatBackend - Health score: \(score) (need >= 0.5 for ready, >= 0.05 for loading)")
            
            // Check if server is fully ready
            if score >= 0.5 {
                print("DEBUG: FreeChatBackend - Server is ready!")
                return
            }
            
            // Check if model is loading (this is progress)
            if score >= 0.05 && score < 0.5 {
                if !modelLoading {
                    print("DEBUG: FreeChatBackend - Model loading detected, waiting for completion...")
                    modelLoading = true
                }
                // Reset timeout when we detect loading progress
                if timeout < 60 {
                    timeout = 60 // Give more time when loading is detected
                    print("DEBUG: FreeChatBackend - Extended timeout due to loading progress")
                }
            } else if score == 0 {
                print("DEBUG: FreeChatBackend - No response from server yet...")
            }
            
            try await Task.sleep(for: .seconds(tickInterval))
            timeout -= tickInterval
        }
        
        print("DEBUG: FreeChatBackend - Timeout reached. Final score: \(lastScore)")
        throw AIBackendError.modelLoadFailed("Server failed to become ready within timeout (model loading can take time for large models)")
    }
    
    private func performChat(
        messages: [FreeChatMessage],
        temperature: Double?,
        progressHandler: @escaping (String) -> Void
    ) async throws -> String {
        let url = URL(string: "http://\(host):\(port)/v1/chat/completions")!
        
        let params = ChatParams(
            messages: messages,
            temperature: temperature ?? 0.7
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")
        
        do {
            request.httpBody = try JSONEncoder().encode(params)
        } catch {
            throw AIBackendError.chatFailed("Failed to encode request: \(error.localizedDescription)")
        }
        
        print("DEBUG: FreeChatBackend - Sending chat request to \(url)")
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300 // 5 minutes for generation
        let session = URLSession(configuration: config)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIBackendError.chatFailed("Invalid response type")
            }
            
            print("DEBUG: FreeChatBackend - HTTP response: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("DEBUG: FreeChatBackend - Error response: \(errorBody)")
                throw AIBackendError.chatFailed("Server responded with \(httpResponse.statusCode): \(errorBody)")
            }
            
            // Handle streaming response
            if let responseString = String(data: data, encoding: .utf8) {
                print("DEBUG: FreeChatBackend - Raw response: \(responseString.prefix(200))...")
                
                // Parse streaming response if it contains SSE data
                if responseString.contains("data: ") {
                    return try parseStreamingResponse(responseString, progressHandler: progressHandler)
                } else {
                    // Try to parse as single JSON response
                    return try parseSingleResponse(data, progressHandler: progressHandler)
                }
            } else {
                throw AIBackendError.chatFailed("Invalid response encoding")
            }
            
        } catch {
            print("DEBUG: FreeChatBackend - Request failed: \(error)")
            throw AIBackendError.chatFailed("Request failed: \(error.localizedDescription)")
        }
    }
    
    private func parseStreamingResponse(_ responseString: String, progressHandler: @escaping (String) -> Void) throws -> String {
        var fullResponse = ""
        let lines = responseString.components(separatedBy: .newlines)
        
        for line in lines {
            if line.hasPrefix("data: ") {
                let jsonString = String(line.dropFirst(6)) // Remove "data: " prefix
                
                if jsonString.trimmingCharacters(in: .whitespacesAndNewlines) == "[DONE]" {
                    break
                }
                
                if let data = jsonString.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let delta = firstChoice["delta"] as? [String: Any],
                   let content = delta["content"] as? String {
                    
                    fullResponse += content
                    progressHandler(content)
                }
            }
        }
        
        return fullResponse
    }
    
    private func parseSingleResponse(_ data: Data, progressHandler: @escaping (String) -> Void) throws -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let message = firstChoice["message"] as? [String: Any],
           let content = message["content"] as? String {
            
            progressHandler(content)
            return content
        } else {
            throw AIBackendError.chatFailed("Failed to parse response JSON")
        }
    }
    
    // MARK: - Helper Methods
    
    private func friendlyModelName(for filePath: String) -> String {
        let fileName = URL(fileURLWithPath: filePath).lastPathComponent
        
        let modelMappings: [String: String] = [
            "Qwen3-0.6B-Q4_0.gguf": "Flash",
            "gemma-3-1b-it-Q4_0.gguf": "Scout",
            "Qwen3-1.7B-Q4_0.gguf": "Runner",
            "granite-3.3-2b-instruct-Q4_0.gguf": "Focus",
            "gemma-3-4b-it-Q4_0.gguf": "Sage",
            "granite-3.3-8b-instruct-Q4_0.gguf": "Deep Thought"
        ]
        
        if let friendlyName = modelMappings[fileName] {
            return friendlyName
        }
        
        let lowercaseFileName = fileName.lowercased()
        for (pattern, friendlyName) in modelMappings {
            if lowercaseFileName.contains(pattern.lowercased()) {
                return friendlyName
            }
        }
        
        return fileName.replacingOccurrences(of: ".gguf", with: "")
    }
    
    deinit {
        stopServer()
    }
}
*/

// MARK: - Supporting Classes

// MARK: - Supporting Classes (DEPRECATED - used by old FreeChat backend)
/*
@MainActor
private class ServerHealthChecker {
    // ... implementation commented out
}

private struct ServerHealthResponse {
    // ... implementation commented out  
}

private struct FreeChatMessage: Codable {
    // ... implementation commented out
}

private struct ChatParams: Codable {
    // ... implementation commented out
}
*/

// MARK: - OllamaKit Backend Implementation

@MainActor
class OllamaKitBackend: AIBackendProtocol {
    @Published var isReady: Bool = false
    @Published var status: String = "Checking connection..."
    
    private let ollamaKit: OllamaKit
    private var host: String
    
    init(host: String = "http://localhost:11434") {
        self.host = host
        self.ollamaKit = OllamaKit(baseURL: URL(string: host)!)
    }
    
    func initialize() async throws {
        // Test connection by trying to list models
        do {
            _ = try await listModels()
            isReady = true
            status = "Connected to Ollama at \(host)"
        } catch {
            isReady = false
            status = "Failed to connect to Ollama: \(error.localizedDescription)"
            throw AIBackendError.connectionFailed(error.localizedDescription)
        }
    }
    
    func loadModel(at path: String) async throws {
        // OllamaKit doesn't load models from paths, models are managed by Ollama server
        // This is a no-op for OllamaKit
        status = "Using Ollama server models"
    }
    
    func listModels() async throws -> [String] {
        do {
            let response = try await ollamaKit.models()
            return response.models.map { $0.name }
        } catch {
            throw AIBackendError.modelListFailed(error.localizedDescription)
        }
    }
    
    func chat(request: AIChatRequest, onPartialResponse: @escaping (String) -> Void) async throws -> String {
        guard isReady else {
            throw AIBackendError.notReady
        }
        
        // Convert AIMessage to OllamaKit format
        let okMessages = request.messages.map { message in
            OKChatRequestData.Message(role: message.ollamaKitRole, content: message.content)
        }
        
        let chatData = OKChatRequestData(
            model: request.model,
            messages: okMessages
        )
        
        var fullResponse = ""
        
        do {
            for try await chunk in ollamaKit.chat(data: chatData) {
                if let content = chunk.message?.content {
                    fullResponse += content
                    onPartialResponse(content)
                }
                
                if chunk.done {
                    break
                }
            }
            return fullResponse
        } catch {
            throw AIBackendError.chatFailed(error.localizedDescription)
        }
    }
    
    func updateHost(_ newHost: String) {
        self.host = newHost
        // Note: OllamaKit doesn't have a way to update the baseURL after initialization
        // In a real implementation, you might need to recreate the OllamaKit instance
    }
}

// MARK: - Extensions for Role Conversion

extension AIMessage {
    var freeChatRole: String {
        switch role {
        case .system: return "system"
        case .user: return "user"
        case .assistant: return "assistant"
        }
    }
    
    var openAIRole: String {
        switch role {
        case .system: return "system"
        case .user: return "user"
        case .assistant: return "assistant"
        }
    }
    
    var ollamaKitRole: OKChatRequestData.Message.Role {
        switch role {
        case .system: return .system
        case .user: return .user
        case .assistant: return .assistant
        }
    }
}

// MARK: - AI Backend Manager

@MainActor
@Observable
class AIBackendManager {
    var currentBackend: (any AIBackendProtocol)?
    var selectedBackendType: AIBackend = Defaults[.selectedAIBackend]
    
    init() {
        Task {
            try? await initializeBackend(selectedBackendType)
        }
    }
    
    func initializeBackend(_ backendType: AIBackend) async throws {
        selectedBackendType = backendType
        
        switch backendType {
        case .llamaCpp:
            let backend = LlamaCppBackend()
            try await backend.initialize()
            currentBackend = backend
            
        case .ollamaKit:
            let host = Defaults[.defaultHost]
            let backend = OllamaKitBackend(host: host)
            try await backend.initialize()
            currentBackend = backend
        }
    }
    
    func loadModelForLlamaCpp(_ modelPath: String) async throws {
        guard selectedBackendType == .llamaCpp else {
            throw AIBackendError.invalidBackend("LlamaCpp not selected")
        }
        
        guard let llamaCppBackend = currentBackend as? LlamaCppBackend else {
            throw AIBackendError.backendNotReady("LlamaCpp backend not available")
        }
        
        try await llamaCppBackend.loadModel(at: modelPath)
        
        // Update the stored model path
        Defaults[.llamaKitModelPath] = modelPath
        
        print("DEBUG: Successfully loaded LlamaCpp model: \(modelPath)")
    }
    
    func updateOllamaHost(_ host: String) {
        guard selectedBackendType == .ollamaKit,
              let backend = currentBackend as? OllamaKitBackend else {
            return
        }
        
        backend.updateHost(host)
    }
}

// MARK: - Errors

enum AIBackendError: LocalizedError {
    case notReady
    case connectionFailed(String)
    case modelListFailed(String)
    case chatFailed(String)
    case wrongBackendType
    case invalidBackend(String)
    case backendNotReady(String)
    case modelLoadFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notReady:
            return "AI backend is not ready"
        case .connectionFailed(let message):
            return "Connection failed: \(message)"
        case .modelListFailed(let message):
            return "Failed to list models: \(message)"
        case .chatFailed(let message):
            return "Chat failed: \(message)"
        case .wrongBackendType:
            return "Wrong backend type for this operation"
        case .invalidBackend(let message):
            return "Invalid backend: \(message)"
        case .backendNotReady(let message):
            return "Backend not ready: \(message)"
        case .modelLoadFailed(let message):
            return "Model load failed: \(message)"
        }
    }
}

// MARK: - Direct Llama.cpp Backend Implementation

@MainActor
class LlamaCppBackend: AIBackendProtocol {
    @Published var isReady: Bool = false
    @Published var status: String = "Not initialized"
    
    nonisolated(unsafe) private var serverProcess: Process?
    nonisolated(unsafe) private var watchdogProcess: Process?
    private var currentModelPath: String?
    private let host = "127.0.0.1"
    private let port = "8080" // Standard llama-server port
    private var contextLength = 8000
    private var serverExecutablePath: String?
    private var libPath: String?
    
    init() {}
    
    func initialize() async throws {
        status = "Initialized"
        print("DEBUG: LlamaCpp backend initialized")
        
        // Find llama-server executable and dylib path
        guard let (execPath, dylibPath) = findLlamaServerExecutable() else {
            let errorMsg = "llama-server executable not found in any expected location"
            status = "Error: \(errorMsg)"
            throw AIBackendError.modelLoadFailed(errorMsg)
        }
        
        serverExecutablePath = execPath
        libPath = dylibPath
        print("DEBUG: LlamaCpp - Found llama-server at: \(execPath)")
        print("DEBUG: LlamaCpp - Using library path: \(dylibPath)")
        
        // Check if we have a configured model path and auto-load it
        let modelPath = Defaults[.llamaKitModelPath]
        if !modelPath.isEmpty {
            print("DEBUG: LlamaCpp - Auto-loading configured model: \(modelPath)")
            do {
                try await loadModel(at: modelPath)
                print("DEBUG: LlamaCpp - Auto-load completed successfully")
            } catch {
                print("DEBUG: LlamaCpp - Auto-load failed: \(error)")
                status = "Error loading model: \(error.localizedDescription)"
            }
        } else {
            print("DEBUG: LlamaCpp - No model path configured, waiting for manual model selection")
            status = "No model configured"
        }
    }
    
    private func findLlamaServerExecutable() -> (String, String)? {
        // List of possible locations to check
        let possiblePaths: [(String, String)] = [
            // Development paths (when running from Xcode) - try to find the project source
            (Bundle.main.bundlePath + "/../../../../../../../../Desktop/Euni Client Notes/ClientNote/Resources/llama-bin/llama-server",
             Bundle.main.bundlePath + "/../../../../../../../../Desktop/Euni Client Notes/ClientNote/Resources/llama-bin"),
            
            // Alternative development paths
            (NSHomeDirectory() + "/Desktop/Euni Client Notes/ClientNote/Resources/llama-bin/llama-server",
             NSHomeDirectory() + "/Desktop/Euni Client Notes/ClientNote/Resources/llama-bin"),
            
            // Try current working directory relative paths
            (FileManager.default.currentDirectoryPath + "/ClientNote/Resources/llama-bin/llama-server",
             FileManager.default.currentDirectoryPath + "/ClientNote/Resources/llama-bin"),
            
            // Bundled paths (production)
            (Bundle.main.resourcePath! + "/llama-bin/llama-server",
             Bundle.main.resourcePath! + "/llama-bin"),
            
            // Alternative bundled location
            (Bundle.main.bundlePath + "/Contents/Resources/llama-bin/llama-server",
             Bundle.main.bundlePath + "/Contents/Resources/llama-bin"),
            
            // User's compiled version (non-sandboxed path)
            ("/Users/kevinkeller/downloads/build3/bin/llama-server",
             "/Users/kevinkeller/downloads/build3/bin")
        ]
        
        for (execPath, libPath) in possiblePaths {
            let expandedExecPath = NSString(string: execPath).expandingTildeInPath
            let expandedLibPath = NSString(string: libPath).expandingTildeInPath
            
            print("DEBUG: LlamaCpp - Checking for llama-server at: \(expandedExecPath)")
            
            if FileManager.default.fileExists(atPath: expandedExecPath) {
                // Check if it's executable
                if FileManager.default.isExecutableFile(atPath: expandedExecPath) {
                    print("DEBUG: LlamaCpp - Found executable llama-server at: \(expandedExecPath)")
                    return (expandedExecPath, expandedLibPath)
                } else {
                    print("DEBUG: LlamaCpp - Found llama-server but not executable at: \(expandedExecPath)")
                    
                    // Try to make it executable
                    do {
                        var attributes = try FileManager.default.attributesOfItem(atPath: expandedExecPath)
                        var permissions = (attributes[FileAttributeKey.posixPermissions] as? Int) ?? 0
                        permissions |= 0o755
                        attributes[FileAttributeKey.posixPermissions] = permissions
                        try FileManager.default.setAttributes(attributes, ofItemAtPath: expandedExecPath)
                        
                        // Remove quarantine if present
                        let task = Process()
                        task.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
                        task.arguments = ["-d", "com.apple.quarantine", expandedExecPath]
                        try? task.run()
                        task.waitUntilExit()
                        
                        print("DEBUG: LlamaCpp - Made llama-server executable: \(expandedExecPath)")
                        return (expandedExecPath, expandedLibPath)
                    } catch {
                        print("DEBUG: LlamaCpp - Failed to make executable: \(error)")
                    }
                }
            }
        }
        
        print("DEBUG: LlamaCpp - llama-server not found in any location")
        return nil
    }
    
    func loadModel(at path: String) async throws {
        status = "Loading model..."
        isReady = false
        
        print("DEBUG: LlamaCpp - Loading model at: \(path)")
        
        // Check if model file exists
        guard FileManager.default.fileExists(atPath: path) else {
            let errorMsg = "Model file not found at path: \(path)"
            status = "Error: \(errorMsg)"
            throw AIBackendError.modelLoadFailed(errorMsg)
        }
        
        // Stop any existing server and watchdog
        stopServer()
        
        // Start the server with the model
        try await startServer(modelPath: path)
        
        currentModelPath = path
        status = "Model loaded: \(friendlyModelName(for: path))"
        isReady = true
        
        print("DEBUG: LlamaCpp - Model loaded successfully")
    }
    
    func listModels() async throws -> [String] {
        if let modelPath = currentModelPath {
            let friendlyName = friendlyModelName(for: modelPath)
            return [friendlyName]
        }
        return []
    }
    
    func chat(request: AIChatRequest, onPartialResponse: @escaping (String) -> Void) async throws -> String {
        guard isReady else {
            print("DEBUG: LlamaCpp - Chat called but backend not ready")
            throw AIBackendError.notReady
        }
        
        print("DEBUG: LlamaCpp - Starting chat with \(request.messages.count) messages")
        
        // Convert AIMessage to OpenAI format
        let chatMessages = request.messages.map { message in
            OpenAIChatMessage(role: message.openAIRole, content: message.content)
        }
        
        do {
            let response = try await performChat(
                messages: chatMessages,
                temperature: request.temperature,
                progressHandler: onPartialResponse
            )
            
            print("DEBUG: LlamaCpp - Chat completed successfully. Response length: \(response.count)")
            return response
            
        } catch {
            print("DEBUG: LlamaCpp - Chat failed with error: \(error)")
            throw AIBackendError.chatFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Private Server Management
    
    private func startServer(modelPath: String) async throws {
        guard serverProcess?.isRunning != true else { return }
        
        print("DEBUG: LlamaCpp - Starting llama-server")
        
        guard let serverExecutable = serverExecutablePath,
              let libraryPath = libPath else {
            throw AIBackendError.modelLoadFailed("llama-server executable path not configured")
        }
        
        serverProcess = Process()
        serverProcess!.executableURL = URL(fileURLWithPath: serverExecutable)
        
        // Set environment variables to find the bundled libraries
        var environment = ProcessInfo.processInfo.environment
        environment["DYLD_LIBRARY_PATH"] = libraryPath
        
        // Disable Xcode preview dylib injection to prevent __preview.dylib errors
        environment["DYLD_INSERT_LIBRARIES"] = ""
        environment["__XCODE_BUILT_PRODUCTS_DIR_PATHS"] = ""
        environment["__XPC_DYLD_INSERT_LIBRARIES"] = ""
        environment["__XPC_DYLD_FRAMEWORK_PATH"] = ""
        environment["__XPC_DYLD_LIBRARY_PATH"] = ""
        
        serverProcess!.environment = environment
        
        let threads = max(1, ProcessInfo.processInfo.activeProcessorCount - 2)
        
        serverProcess!.arguments = [
            "--model", modelPath,
            "--threads", "\(threads)",
            "--ctx-size", "\(contextLength)",
            "--port", port,
            "--n-gpu-layers", "99",
            "--host", host
        ]
        
        print("DEBUG: LlamaCpp - Server command: \(serverExecutable) \(serverProcess!.arguments!.joined(separator: " "))")
        print("DEBUG: LlamaCpp - Library path: \(libraryPath)")
        
        // Capture output for debugging
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        serverProcess!.standardOutput = outputPipe
        serverProcess!.standardError = errorPipe
        
        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
                print("DEBUG: llama-server stdout: \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
        }
        
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
                print("DEBUG: llama-server stderr: \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
        }
        
        do {
            try serverProcess!.run()
            print("DEBUG: LlamaCpp - Process started successfully, PID: \(serverProcess!.processIdentifier)")
        } catch {
            print("DEBUG: LlamaCpp - Failed to start process: \(error)")
            throw AIBackendError.modelLoadFailed("Failed to start server process: \(error.localizedDescription)")
        }
        
        // Start watchdog
        startWatchdog(serverPID: serverProcess!.processIdentifier)
        
        print("DEBUG: LlamaCpp - Process started, waiting for server to be ready...")
        
        // Wait for server to be ready
        try await waitForServerReady()
        
        print("DEBUG: LlamaCpp - Server started successfully on port \(port)")
    }
    
    private func startWatchdog(serverPID: Int32) {
        print("DEBUG: LlamaCpp - Starting watchdog for server PID \(serverPID)")
        
        watchdogProcess = Process()
        watchdogProcess!.executableURL = URL(fileURLWithPath: "/bin/bash")
        watchdogProcess!.arguments = ["-c", """
            # Integrated watchdog script
            while true; do
                if ! kill -0 \(serverPID) 2>/dev/null; then
                    echo "DEBUG: Watchdog - Server process \(serverPID) is dead, exiting"
                    exit 0
                fi
                
                # Check if parent process (this app) is still alive
                if ! kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; then
                    echo "DEBUG: Watchdog - Parent process dead, killing server"
                    kill -TERM \(serverPID) 2>/dev/null
                    sleep 2
                    kill -KILL \(serverPID) 2>/dev/null
                    exit 0
                fi
                
                sleep 5
            done
            """]
        
        let watchdogPipe = Pipe()
        watchdogProcess!.standardOutput = watchdogPipe
        watchdogProcess!.standardError = watchdogPipe
        
        watchdogPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
                print("DEBUG: watchdog: \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
        }
        
        do {
            try watchdogProcess!.run()
            print("DEBUG: LlamaCpp - Watchdog started with PID: \(watchdogProcess!.processIdentifier)")
        } catch {
            print("DEBUG: LlamaCpp - Failed to start watchdog: \(error)")
        }
    }
    
    nonisolated private func stopServer() {
        if let process = serverProcess, process.isRunning {
            print("DEBUG: LlamaCpp - Stopping server")
            
            // Clean up pipe handlers
            if let stdout = process.standardOutput as? Pipe {
                stdout.fileHandleForReading.readabilityHandler = nil
            }
            if let stderr = process.standardError as? Pipe {
                stderr.fileHandleForReading.readabilityHandler = nil
            }
            
            process.terminate()
            
            DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                if process.isRunning {
                    process.terminate()
                    print("DEBUG: LlamaCpp - Force terminated server process")
                }
            }
        }
        
        if let watchdog = watchdogProcess, watchdog.isRunning {
            print("DEBUG: LlamaCpp - Stopping watchdog")
            watchdog.terminate()
        }
        
        serverProcess = nil
        watchdogProcess = nil
    }
    
    private func waitForServerReady() async throws {
        let healthURL = URL(string: "http://\(host):\(port)/v1/models")!
        print("DEBUG: LlamaCpp - Waiting for server at: \(healthURL)")
        
        var timeout = 120 // 2 minutes for large model loading
        let tickInterval = 2
        
        while timeout > 0 {
            print("DEBUG: LlamaCpp - Health check attempt, timeout remaining: \(timeout)s")
            
            // Check if process is still running
            guard let process = serverProcess, process.isRunning else {
                print("DEBUG: LlamaCpp - Server process terminated unexpectedly")
                throw AIBackendError.modelLoadFailed("Server process terminated unexpectedly")
            }
            
            do {
                let config = URLSessionConfiguration.default
                config.timeoutIntervalForRequest = 3
                
                let (data, response) = try await URLSession(configuration: config).data(from: healthURL)
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("DEBUG: LlamaCpp - Health check response: \(httpResponse.statusCode)")
                    
                    if httpResponse.statusCode == 200 {
                        // Parse response to check if models are available
                        if let responseString = String(data: data, encoding: .utf8) {
                            print("DEBUG: LlamaCpp - Models response: \(responseString)")
                            
                            // If we get a valid JSON response with models, server is ready
                            if responseString.contains("\"data\"") || responseString.contains("\"models\"") {
                                print("DEBUG: LlamaCpp - Server is ready!")
                                return
                            }
                        }
                    } else if httpResponse.statusCode == 503 {
                        // Server is loading
                        print("DEBUG: LlamaCpp - Server loading...")
                        timeout = max(timeout, 60) // Extend timeout when loading
                    }
                }
            } catch {
                print("DEBUG: LlamaCpp - Health check failed: \(error.localizedDescription)")
            }
            
            try await Task.sleep(for: .seconds(tickInterval))
            timeout -= tickInterval
        }
        
        throw AIBackendError.modelLoadFailed("Server failed to become ready within timeout")
    }
    
    private func performChat(
        messages: [OpenAIChatMessage],
        temperature: Double?,
        progressHandler: @escaping (String) -> Void
    ) async throws -> String {
        let url = URL(string: "http://\(host):\(port)/v1/chat/completions")!
        
        let requestBody = OpenAIChatRequest(
            model: "model", // llama-server ignores this when only one model is loaded
            messages: messages,
            temperature: temperature ?? 0.7,
            stream: true
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")
        
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            throw AIBackendError.chatFailed("Failed to encode request: \(error.localizedDescription)")
        }
        
        print("DEBUG: LlamaCpp - Sending chat request to \(url)")
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300 // 5 minutes for generation
        let session = URLSession(configuration: config)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIBackendError.chatFailed("Invalid response type")
            }
            
            print("DEBUG: LlamaCpp - HTTP response: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("DEBUG: LlamaCpp - Error response: \(errorBody)")
                throw AIBackendError.chatFailed("Server responded with \(httpResponse.statusCode): \(errorBody)")
            }
            
            // Handle streaming response
            if let responseString = String(data: data, encoding: .utf8) {
                print("DEBUG: LlamaCpp - Processing streaming response...")
                return try parseStreamingResponse(responseString, progressHandler: progressHandler)
            } else {
                throw AIBackendError.chatFailed("Invalid response encoding")
            }
            
        } catch {
            print("DEBUG: LlamaCpp - Request failed: \(error)")
            throw AIBackendError.chatFailed("Request failed: \(error.localizedDescription)")
        }
    }
    
    private func parseStreamingResponse(_ responseString: String, progressHandler: @escaping (String) -> Void) throws -> String {
        var fullResponse = ""
        let lines = responseString.components(separatedBy: .newlines)
        
        for line in lines {
            if line.hasPrefix("data: ") {
                let jsonString = String(line.dropFirst(6))
                
                if jsonString.trimmingCharacters(in: .whitespacesAndNewlines) == "[DONE]" {
                    break
                }
                
                if let data = jsonString.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let delta = firstChoice["delta"] as? [String: Any],
                   let content = delta["content"] as? String {
                    
                    fullResponse += content
                    progressHandler(content)
                }
            }
        }
        
        return fullResponse
    }
    
    private func friendlyModelName(for filePath: String) -> String {
        let fileName = URL(fileURLWithPath: filePath).lastPathComponent
        
        let modelMappings: [String: String] = [
            "Qwen3-0.6B-Q4_0.gguf": "Flash",
            "gemma-3-1b-it-Q4_0.gguf": "Scout",
            "Qwen3-1.7B-Q4_0.gguf": "Runner",
            "granite-3.3-2b-instruct-Q4_0.gguf": "Focus",
            "gemma-3-4b-it-Q4_0.gguf": "Sage",
            "granite-3.3-8b-instruct-Q4_0.gguf": "Deep Thought"
        ]
        
        if let friendlyName = modelMappings[fileName] {
            return friendlyName
        }
        
        let lowercaseFileName = fileName.lowercased()
        for (pattern, friendlyName) in modelMappings {
            if lowercaseFileName.contains(pattern.lowercased()) {
                return friendlyName
            }
        }
        
        return fileName.replacingOccurrences(of: ".gguf", with: "")
    }
    
    deinit {
        stopServer()
    }
}

// MARK: - OpenAI API Structures

private struct OpenAIChatMessage: Codable {
    let role: String
    let content: String
}

private struct OpenAIChatRequest: Codable {
    let model: String
    let messages: [OpenAIChatMessage]
    let temperature: Double
    let stream: Bool
} 
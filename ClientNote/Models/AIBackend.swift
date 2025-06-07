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
        print("DEBUG: FreeChatBackend - listModels() called")
        
        // Return all available models, not just the currently loaded one
        var availableModels: [String] = []
        
        // First, add the currently loaded model if any
        if let modelPath = currentModelPath {
            let friendlyName = friendlyModelName(for: modelPath)
            availableModels.append(friendlyName)
            print("DEBUG: Added currently loaded model: \(friendlyName)")
        }
        
        // Then scan for other available models in the app's sandboxed directories
        let downloadPaths = [
            // Standard Application Support path (primary location)
            getModelDownloadPath(),
            // Alternative app-specific Application Support path
            getAlternativeModelPath()
        ].compactMap { $0 }
        
        print("DEBUG: Scanning \(downloadPaths.count) directories for models")
        
        for downloadPath in downloadPaths {
            print("DEBUG: Scanning directory: \(downloadPath.path)")
            print("DEBUG: Directory exists: \(FileManager.default.fileExists(atPath: downloadPath.path))")
            
            do {
                let contents = try FileManager.default.contentsOfDirectory(at: downloadPath, 
                                                                         includingPropertiesForKeys: nil)
                
                print("DEBUG: Found \(contents.count) items in \(downloadPath.path)")
                
                for fileURL in contents {
                    let fileName = fileURL.lastPathComponent
                    let fileExtension = fileURL.pathExtension
                    print("DEBUG: Found file: \(fileName) (extension: \(fileExtension))")
                    
                    if fileExtension == "gguf" {
                        let friendlyName = friendlyModelName(for: fileURL.path)
                        print("DEBUG: Found GGUF model: \(fileName) -> \(friendlyName)")
                        
                        // Avoid duplicates
                        if !availableModels.contains(friendlyName) {
                            availableModels.append(friendlyName)
                            print("DEBUG: Added model to list: \(friendlyName)")
                        } else {
                            print("DEBUG: Skipped duplicate model: \(friendlyName)")
                        }
                    }
                }
            } catch {
                // Directory doesn't exist or can't be read - that's okay
                print("DEBUG: Could not scan directory \(downloadPath.path): \(error)")
            }
        }
        
        print("DEBUG: Total models found: \(availableModels.count)")
        print("DEBUG: Available models: \(availableModels)")
        
        // If no models found anywhere, return empty array
        return availableModels
    }
    
    /// Get the standard model download path
    private func getModelDownloadPath() -> URL {
        let appSupportPaths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupportPath = appSupportPaths.first!
        let appName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "ClientNote"
        return appSupportPath
            .appendingPathComponent(appName, isDirectory: true)
            .appendingPathComponent("LlamaKitModels", isDirectory: true)
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
        // Priority 1: Try bundled llama-bin directory (our preferred location)
        if let resourcePath = Bundle.main.resourcePath {
            let llamaBinPath = URL(fileURLWithPath: resourcePath).appendingPathComponent("llama-bin/llama-server")
            if FileManager.default.fileExists(atPath: llamaBinPath.path) {
                print("DEBUG: FreeChatBackend - Found bundled llama-server at: \(llamaBinPath.path)")
                return llamaBinPath
            }
        }
        
        // Priority 2: Try main bundle Contents/Resources directly (where it actually is)
        let bundleResourcesPath = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Resources/llama-server")
        if FileManager.default.fileExists(atPath: bundleResourcesPath.path) {
            print("DEBUG: FreeChatBackend - Found llama-server directly in Resources at: \(bundleResourcesPath.path)")
            return bundleResourcesPath
        }
        
        // Priority 3: Try main bundle Contents/Resources/llama-bin (fallback)
        let bundleLlamaBinPath = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Resources/llama-bin/llama-server")
        if FileManager.default.fileExists(atPath: bundleLlamaBinPath.path) {
            print("DEBUG: FreeChatBackend - Found llama-server in bundle llama-bin at: \(bundleLlamaBinPath.path)")
            return bundleLlamaBinPath
        }
        
        // Priority 4: Try auxiliary executable
        if let bundledPath = Bundle.main.url(forAuxiliaryExecutable: "llama-server") {
            if FileManager.default.fileExists(atPath: bundledPath.path) {
                print("DEBUG: FreeChatBackend - Found auxiliary llama-server at: \(bundledPath.path)")
                return bundledPath
            }
        }
        
        // Priority 5: Try as resource
        if let bundledPath = Bundle.main.url(forResource: "llama-server", withExtension: nil) {
            if FileManager.default.fileExists(atPath: bundledPath.path) {
                print("DEBUG: FreeChatBackend - Found resource llama-server at: \(bundledPath.path)")
                return bundledPath
            }
        }
        
        // Priority 6: Try bundle root
        let bundleURL = Bundle.main.bundleURL.appendingPathComponent("llama-server")
        if FileManager.default.fileExists(atPath: bundleURL.path) {
            print("DEBUG: FreeChatBackend - Found llama-server in bundle root at: \(bundleURL.path)")
            return bundleURL
        }
        
        // Priority 7: Try system paths (may not work in sandbox)
        let systemPaths = [
            "/usr/local/bin/llama-server",
            "/opt/homebrew/bin/llama-server"
        ]
        
        for path in systemPaths {
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: url.path) {
                print("DEBUG: FreeChatBackend - Found system llama-server at: \(url.path)")
                return url
            }
        }
        
        print("DEBUG: FreeChatBackend - llama-server executable not found anywhere")
        print("DEBUG: FreeChatBackend - Checked locations:")
        print("DEBUG:   - Bundle Resources: \(Bundle.main.resourcePath ?? "nil")/llama-bin/llama-server")
        print("DEBUG:   - Bundle Contents: \(Bundle.main.bundleURL.path)/Contents/Resources/llama-bin/llama-server")
        print("DEBUG:   - System paths: \(systemPaths)")
        
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
        var isInThinkBlock = false
        var thinkBuffer = ""
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
                    
                    // Process content character by character to handle think tags that span chunks
                    var processedContent = ""
                    
                    for char in content {
                        if !isInThinkBlock {
                            // Check if we're starting a think block
                            thinkBuffer += String(char)
                            
                            if thinkBuffer.hasSuffix("<think>") {
                                // Start of think block found - remove <think> from processed content
                                processedContent = String(processedContent.dropLast(6)) // Remove "<think" part
                                isInThinkBlock = true
                                thinkBuffer = ""
                            } else if thinkBuffer.count > 6 {
                                // No think tag starting, add the oldest char to processed content
                                let oldestChar = thinkBuffer.removeFirst()
                                processedContent += String(oldestChar)
                            }
                        } else {
                            // We're inside a think block, check for end
                            thinkBuffer += String(char)
                            
                            if thinkBuffer.hasSuffix("</think>") {
                                // End of think block found
                                isInThinkBlock = false
                                thinkBuffer = ""
                            } else if thinkBuffer.count > 8 {
                                // Keep only the last 8 characters to detect </think>
                                thinkBuffer = String(thinkBuffer.suffix(8))
                            }
                        }
                    }
                    
                    // Add any remaining buffer content that's not part of a think tag
                    if !isInThinkBlock && !thinkBuffer.isEmpty && !thinkBuffer.contains("<") {
                        processedContent += thinkBuffer
                        thinkBuffer = ""
                    }
                    
                    // Only add and stream non-think content
                    if !processedContent.isEmpty {
                        fullResponse += processedContent
                        progressHandler(processedContent)
                    }
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
            
            // Filter out think tags from single response
            let filteredContent = filterThinkTags(from: content)
            progressHandler(filteredContent)
            return filteredContent
        } else {
            throw AIBackendError.chatFailed("Failed to parse response JSON")
        }
    }
    
    /// Filters out <think>...</think> blocks from content
    private func filterThinkTags(from content: String) -> String {
        // Use regex to remove think blocks
        let pattern = "<think>.*?</think>"
        let regex = try! NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
        let range = NSRange(location: 0, length: content.utf16.count)
        let filteredContent = regex.stringByReplacingMatches(in: content, options: [], range: range, withTemplate: "")
        
        // Clean up any extra whitespace that might be left
        return filteredContent.trimmingCharacters(in: .whitespacesAndNewlines)
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
    
    /// Get alternative model path within app's sandbox
    private func getAlternativeModelPath() -> URL {
        let appSupportPaths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupportPath = appSupportPaths.first!
        let appName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "ClientNote"
        let modelsPath = appSupportPath
            .appendingPathComponent(appName, isDirectory: true)
            .appendingPathComponent("Models", isDirectory: true)
        
        // Create the directory if it doesn't exist to prevent scan errors
        try? FileManager.default.createDirectory(at: modelsPath, withIntermediateDirectories: true, attributes: nil)
        
        return modelsPath
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
    
    /// Get the standard model download path
    private func getModelDownloadPath() -> URL {
        let appSupportPaths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupportPath = appSupportPaths.first!
        let appName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "ClientNote"
        return appSupportPath
            .appendingPathComponent(appName, isDirectory: true)
            .appendingPathComponent("LlamaKitModels", isDirectory: true)
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

// MARK: - Singleton AI Backend Manager

@MainActor
@Observable
class AIBackendManager {
    // CRITICAL: Use singleton pattern to prevent multiple instances
    static let shared = AIBackendManager()
    
    var currentBackend: (any AIBackendProtocol)?
    var selectedBackendType: AIBackend = Defaults[.selectedAIBackend]
    
    // Track initialization state to prevent duplicate initialization
    private var isInitializing = false
    private var initializationTask: Task<Void, Error>?
    
    // Preview environment detection
    private var isPreviewEnvironment: Bool {
        // Check for Xcode preview environment indicators
        let environment = ProcessInfo.processInfo.environment
        
        // More specific detection - only consider it a preview if we have the preview dylib
        // AND we're specifically running for previews (not just running from Xcode)
        let hasPreviewDylib = environment["DYLD_INSERT_LIBRARIES"]?.contains("__preview.dylib") == true
        let isRunningForPreviews = environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        
        // Additional preview indicators that are more specific
        let hasPreviewProcess = ProcessInfo.processInfo.processName.contains("PreviewsAgent") ||
                               ProcessInfo.processInfo.processName.contains("PreviewHost")
        
        return hasPreviewDylib && (isRunningForPreviews || hasPreviewProcess)
    }
    
    // Private initializer to enforce singleton
    private init() {
        print("DEBUG: AIBackendManager.shared - Creating singleton instance")
        
        // Don't initialize backend during preview - prevents crashes
        guard !isPreviewEnvironment else {
            print("DEBUG: AIBackendManager - Preview environment detected, skipping backend initialization")
            return
        }
        
        // Initialize backend on startup
        Task {
            do {
                try await initializeBackend(selectedBackendType)
            } catch {
                print("DEBUG: AIBackendManager - Failed to initialize backend: \(error)")
            }
        }
    }
    
    func initializeBackend(_ backendType: AIBackend) async throws {
        // Skip initialization in preview environment
        guard !isPreviewEnvironment else {
            print("DEBUG: AIBackendManager - Skipping backend initialization in preview environment")
            return
        }
        
        // Prevent concurrent initialization
        if isInitializing {
            print("DEBUG: AIBackendManager - Backend initialization already in progress, waiting...")
            try await initializationTask?.value
            return
        }
        
        // Check if we already have the right backend type running
        if let backend = currentBackend,
           selectedBackendType == backendType,
           backend.isReady {
            print("DEBUG: AIBackendManager - Backend already initialized and ready, skipping")
            return
        }
        
        isInitializing = true
        
        initializationTask = Task {
            defer { 
                isInitializing = false 
                initializationTask = nil
            }
            
            selectedBackendType = backendType
            
            print("DEBUG: AIBackendManager - Initializing backend type: \(backendType)")
            
            switch backendType {
            case .llamaCpp:
                // Only create new backend if we don't have one or it's the wrong type
                if !(currentBackend is LlamaCppBackend) {
                    print("DEBUG: AIBackendManager - Creating new LlamaCppBackend")
                    let backend = LlamaCppBackend()
                    try await backend.initialize()
                    currentBackend = backend
                } else {
                    print("DEBUG: AIBackendManager - Reusing existing LlamaCppBackend")
                }
                
            case .ollamaKit:
                if !(currentBackend is OllamaKitBackend) {
                    print("DEBUG: AIBackendManager - Creating new OllamaKitBackend")
                    let host = Defaults[.defaultHost]
                    let backend = OllamaKitBackend(host: host)
                    try await backend.initialize()
                    currentBackend = backend
                } else {
                    print("DEBUG: AIBackendManager - Reusing existing OllamaKitBackend")
                }
            }
            
            // Store the selection
            Defaults[.selectedAIBackend] = backendType
        }
        
        try await initializationTask?.value
    }
    
    func loadModelForLlamaCpp(_ modelPath: String) async throws {
        // Skip in preview environment
        guard !isPreviewEnvironment else {
            print("DEBUG: AIBackendManager - Skipping model loading in preview environment")
            return
        }
        
        guard selectedBackendType == .llamaCpp else {
            throw AIBackendError.invalidBackend("LlamaCpp not selected")
        }
        
        // Ensure we have a LlamaCpp backend
        if !(currentBackend is LlamaCppBackend) {
            try await initializeBackend(.llamaCpp)
        }
        
        guard let llamaCppBackend = currentBackend as? LlamaCppBackend else {
            throw AIBackendError.backendNotReady("LlamaCpp backend not available")
        }
        
        print("DEBUG: AIBackendManager - Loading model: \(modelPath)")
        try await llamaCppBackend.loadModel(at: modelPath)
        
        // Update the stored model path
        Defaults[.llamaKitModelPath] = modelPath
        
        print("DEBUG: AIBackendManager - Successfully loaded LlamaCpp model: \(modelPath)")
    }
    
    func updateOllamaHost(_ host: String) {
        // Skip in preview environment
        guard !isPreviewEnvironment else {
            print("DEBUG: AIBackendManager - Skipping host update in preview environment")
            return
        }
        
        guard selectedBackendType == .ollamaKit,
              let backend = currentBackend as? OllamaKitBackend else {
            return
        }
        
        backend.updateHost(host)
    }
    
    // MARK: - Helper Methods for Views
    
    /// Get the current backend, ensuring it's initialized
    func getBackend() async throws -> any AIBackendProtocol {
        // Return mock backend in preview environment
        guard !isPreviewEnvironment else {
            return MockBackend()
        }
        
        if let backend = currentBackend, backend.isReady {
            return backend
        }
        
        // Backend not ready, try to initialize
        try await initializeBackend(selectedBackendType)
        
        guard let backend = currentBackend else {
            throw AIBackendError.backendNotReady("No backend available after initialization")
        }
        
        return backend
    }
    
    /// Check if backend is ready without initializing
    var isBackendReady: Bool {
        // Return false in preview environment
        guard !isPreviewEnvironment else {
            return false
        }
        
        return currentBackend?.isReady ?? false
    }
    
    /// Get current backend status
    var backendStatus: String {
        // Return preview status in preview environment
        guard !isPreviewEnvironment else {
            return "Preview Mode"
        }
        
        return currentBackend?.status ?? "No backend"
    }
}

// MARK: - Mock Backend for Previews

/// Mock backend implementation for preview environments
private class MockBackend: AIBackendProtocol {
    @Published var isReady: Bool = true
    @Published var status: String = "Mock Backend"
    
    func initialize() async throws {
        // No-op for mock
    }
    
    func loadModel(at path: String) async throws {
        // No-op for mock
    }
    
    func listModels() async throws -> [String] {
        return ["Preview Model"]
    }
    
    func chat(request: AIChatRequest, onPartialResponse: @escaping (String) -> Void) async throws -> String {
        return "Mock response for preview"
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

// MARK: - Llama.cpp Configuration and Server Management

struct LlamaModelConfig {
    let modelPath: String
    let contextSize: Int
    let gpuLayers: Int
    let threadCount: Int
    
    // Auto-detect optimal settings based on model metadata
    static func autoDetect(for modelPath: String) -> LlamaModelConfig {
        // Parse model metadata to determine optimal settings
        // For now, use heuristics based on model size
        let modelName = URL(fileURLWithPath: modelPath).lastPathComponent
        
        var contextSize = 8192  // Safe default
        var gpuLayers = 20      // Conservative GPU usage
        
        // Model-specific optimizations
        if modelName.contains("Qwen3") {
            contextSize = 32768  // Use 32K instead of full 40K for stability
            if modelName.contains("0.6B") {
                gpuLayers = 28   // Offload all layers for small model
            } else if modelName.contains("1.7B") {
                gpuLayers = 26
            }
        } else if modelName.contains("gemma-3-1b") {
            contextSize = 16384
            gpuLayers = 18
        } else if modelName.contains("gemma-3-4b") {
            contextSize = 16384
            gpuLayers = 26
        } else if modelName.contains("granite-3.3-2b") {
            contextSize = 32768  // Granite supports large context
            gpuLayers = 20
        } else if modelName.contains("granite-3.3-8b") {
            contextSize = 32768
            gpuLayers = 32
        } else if modelName.contains("7B") || modelName.contains("8B") {
            contextSize = 16384
            gpuLayers = 24
        } else if modelName.contains("13B") {
            contextSize = 8192
            gpuLayers = 20
        }
        
        // Thread optimization for Apple Silicon
        let threadCount = Self.calculateOptimalThreads()
        
        return LlamaModelConfig(
            modelPath: modelPath,
            contextSize: contextSize,
            gpuLayers: gpuLayers,
            threadCount: threadCount
        )
    }
    
    private static func calculateOptimalThreads() -> Int {
        let totalCores = ProcessInfo.processInfo.processorCount
        
        // Apple Silicon core detection heuristic
        var performanceCores: Int
        switch totalCores {
        case 8:  // M1, M2 base
            performanceCores = 4
        case 10: // M1 Pro, M2 Pro
            performanceCores = 8
        case 12: // M2 Pro variant
            performanceCores = 8
        case 14: // M3 Pro
            performanceCores = 10
        case 16: // M1 Max
            performanceCores = 10
        case 20: // M1 Ultra
            performanceCores = 16
        case 24: // M2 Ultra
            performanceCores = 16
        default:
            // Conservative estimate: 2/3 are performance cores
            performanceCores = (totalCores * 2) / 3
        }
        
        // Leave 1 core for system/UI responsiveness
        return max(1, performanceCores - 1)
    }
}

@MainActor
class LlamaCppBackend: AIBackendProtocol {
    @Published var isReady: Bool = false
    @Published var status: String = "Not initialized"
    
    nonisolated(unsafe) private var serverProcess: Process?
    nonisolated(unsafe) private var watchdogProcess: Process?
    private var currentModelPath: String?
    private var currentConfig: LlamaModelConfig?
    private let host = "127.0.0.1"
    private let port = "8080" // Standard llama-server port
    private var serverExecutablePath: String?
    private var libPath: String?
    private var isStarting = false // Prevent concurrent starts
    
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
        var modelPath = Defaults[.llamaKitModelPath]
        
        // MIGRATION: Replace old Q8_0 models with Q4_0 equivalents
        if !modelPath.isEmpty {
            let fileName = URL(fileURLWithPath: modelPath).lastPathComponent
            let migratedPath = migrateToQ4Model(currentPath: modelPath, currentFileName: fileName)
            if migratedPath != modelPath {
                print("DEBUG: LlamaCpp - Migrating from Q8_0 to Q4_0 model")
                print("DEBUG: LlamaCpp - Old: \(fileName)")
                print("DEBUG: LlamaCpp - New: \(URL(fileURLWithPath: migratedPath).lastPathComponent)")
                modelPath = migratedPath
                Defaults[.llamaKitModelPath] = modelPath
            }
        }
        
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
    
    /// Migrates old Q8_0 model paths to Q4_0 equivalents
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
            print("DEBUG: LlamaCpp - Found Q4_0 replacement at: \(newPath)")
            return newPath
        } else {
            print("DEBUG: LlamaCpp - Q4_0 replacement not found, keeping original: \(currentPath)")
            return currentPath
        }
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
        
        // Prevent concurrent starts
        guard !isStarting else {
            throw AIBackendError.modelLoadFailed("Server startup already in progress")
        }
        isStarting = true
        
        defer {
            isStarting = false
        }
        
        // Auto-detect optimal configuration for this model
        let config = LlamaModelConfig.autoDetect(for: path)
        print("DEBUG: LlamaCpp - Auto-detected config: ctx=\(config.contextSize), gpu_layers=\(config.gpuLayers), threads=\(config.threadCount)")
        
        // Stop any existing server and watchdog
        await stopServer()
        
        // Start the server with optimized configuration
        try await startServer(config: config)
        
        currentModelPath = path
        currentConfig = config
        status = "Model loaded: \(friendlyModelName(for: path))"
        isReady = true
        
        print("DEBUG: LlamaCpp - Model loaded successfully with optimized settings")
    }
    
    func listModels() async throws -> [String] {
        print("DEBUG: LlamaCpp - listModels() called")
        
        // Return all available models, not just the currently loaded one
        var availableModels: [String] = []
        
        // First, add the currently loaded model if any
        if let modelPath = currentModelPath {
            let friendlyName = friendlyModelName(for: modelPath)
            availableModels.append(friendlyName)
            print("DEBUG: LlamaCpp - Added currently loaded model: \(friendlyName)")
        }
        
        // Scan bundled models first, then user directories
        let downloadPaths = [
            getBundledModelsPath(),      // Check bundled models first
            getModelDownloadPath(),      // User's downloaded models
            getAlternativeModelPath()    // Alternative user models location
        ]
        
        print("DEBUG: LlamaCpp - Scanning \(downloadPaths.count) directories for models")
        
        for downloadPath in downloadPaths {
            print("DEBUG: LlamaCpp - Scanning directory: \(downloadPath.path)")
            print("DEBUG: LlamaCpp - Directory exists: \(FileManager.default.fileExists(atPath: downloadPath.path))")
            
            do {
                let contents = try FileManager.default.contentsOfDirectory(at: downloadPath, 
                                                                         includingPropertiesForKeys: nil)
                
                print("DEBUG: LlamaCpp - Found \(contents.count) items in \(downloadPath.path)")
                
                for fileURL in contents {
                    let fileName = fileURL.lastPathComponent
                    let fileExtension = fileURL.pathExtension
                    print("DEBUG: LlamaCpp - Found file: \(fileName) (extension: \(fileExtension))")
                    
                    if fileExtension == "gguf" {
                        let friendlyName = friendlyModelName(for: fileURL.path)
                        print("DEBUG: LlamaCpp - Found GGUF model: \(fileName) -> \(friendlyName)")
                        
                        // Avoid duplicates
                        if !availableModels.contains(friendlyName) {
                            availableModels.append(friendlyName)
                            print("DEBUG: LlamaCpp - Added model to list: \(friendlyName)")
                        } else {
                            print("DEBUG: LlamaCpp - Skipped duplicate model: \(friendlyName)")
                        }
                    }
                }
            } catch {
                print("DEBUG: LlamaCpp - Could not scan directory \(downloadPath.path): \(error)")
            }
        }
        
        print("DEBUG: LlamaCpp - Total models found: \(availableModels.count)")
        print("DEBUG: LlamaCpp - Available models: \(availableModels)")
        
        // If no models found anywhere, return empty array
        return availableModels
    }
    
    /// Get alternative model path within app's sandbox
    private func getAlternativeModelPath() -> URL {
        let appSupportPaths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupportPath = appSupportPaths.first!
        let appName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "ClientNote"
        let modelsPath = appSupportPath
            .appendingPathComponent(appName, isDirectory: true)
            .appendingPathComponent("Models", isDirectory: true)
        
        // Create the directory if it doesn't exist to prevent scan errors
        try? FileManager.default.createDirectory(at: modelsPath, withIntermediateDirectories: true, attributes: nil)
        
        return modelsPath
    }
    
    /// Get bundled models path within app bundle
    private func getBundledModelsPath() -> URL {
        guard let resourcePath = Bundle.main.resourcePath else {
            print("DEBUG: LlamaCpp - Warning: Could not get bundle resource path")
            return URL(fileURLWithPath: "/tmp") // Fallback that won't have models
        }
        
        let bundledModelsPath = URL(fileURLWithPath: resourcePath)
            .appendingPathComponent("Models", isDirectory: true)
        
        print("DEBUG: LlamaCpp - Bundled models path: \(bundledModelsPath.path)")
        return bundledModelsPath
    }
    
    /// Get the standard model download path
    private func getModelDownloadPath() -> URL {
        let appSupportPaths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupportPath = appSupportPaths.first!
        let appName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "ClientNote"
        return appSupportPath
            .appendingPathComponent(appName, isDirectory: true)
            .appendingPathComponent("LlamaKitModels", isDirectory: true)
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
    
    private func startServer(config: LlamaModelConfig) async throws {
        guard serverProcess?.isRunning != true else { return }
        
        print("DEBUG: LlamaCpp - Starting llama-server with optimized config")
        
        guard let serverExecutable = serverExecutablePath,
              let libraryPath = libPath else {
            throw AIBackendError.modelLoadFailed("llama-server executable path not configured")
        }
        
        serverProcess = Process()
        serverProcess!.executableURL = URL(fileURLWithPath: serverExecutable)
        
        // Enhanced environment cleanup
        var environment = ProcessInfo.processInfo.environment
        environment["DYLD_LIBRARY_PATH"] = libraryPath
        
        // Remove all Xcode injection variables
        let xcodePrefixes = ["DYLD_INSERT_LIBRARIES", "__XCODE_", "__XPC_DYLD_"]
        for key in environment.keys {
            if xcodePrefixes.contains(where: { key.hasPrefix($0) }) {
                environment[key] = ""
            }
        }
        
        // Clean specific variables that cause issues
        environment["DYLD_INSERT_LIBRARIES"] = ""
        environment["__XCODE_BUILT_PRODUCTS_DIR_PATHS"] = ""
        environment["__XPC_DYLD_INSERT_LIBRARIES"] = ""
        environment["__XPC_DYLD_FRAMEWORK_PATH"] = ""
        environment["__XPC_DYLD_LIBRARY_PATH"] = ""
        
        serverProcess!.environment = environment
        
        // Build optimized arguments without unsupported flags
        var arguments = [
            "--model", config.modelPath,
            "--threads", "\(config.threadCount)",
            "--ctx-size", "\(config.contextSize)",
            "--port", port,
            "--n-gpu-layers", "\(config.gpuLayers)",
            "--host", host,
            "--no-warmup"  // Skip warmup for faster startup
        ]
        
        // Add flash attention if supported (newer builds)
        if supportsFlashAttention() {
            arguments.append("--flash-attn")
        }
        
        serverProcess!.arguments = arguments
        
        print("DEBUG: LlamaCpp - Server command: \(serverExecutable) \(arguments.joined(separator: " "))")
        print("DEBUG: LlamaCpp - Library path: \(libraryPath)")
        print("DEBUG: LlamaCpp - Context size: \(config.contextSize), GPU layers: \(config.gpuLayers), Threads: \(config.threadCount)")
        
        // Setup enhanced I/O handling
        setupProcessOutput(for: serverProcess!)
        
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
        
        // Wait for server to be ready with enhanced timeout
        try await waitForServerReady()
        
        print("DEBUG: LlamaCpp - Server started successfully on port \(port)")
    }
    
    private func setupProcessOutput(for process: Process) {
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // Enhanced output parsing
        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty,
                  let output = String(data: data, encoding: .utf8) else { return }
            
            Task { @MainActor in
                self.parseServerOutput(output)
            }
        }
        
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty,
                  let output = String(data: data, encoding: .utf8) else { return }
            
            Task { @MainActor in
                self.parseServerError(output)
            }
        }
    }
    
    private func parseServerOutput(_ output: String) {
        // Extract useful metrics from server output
        if output.contains("n_ctx_per_seq") {
            print("DEBUG: llama-server context info: \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
        } else if output.contains("model loaded") || output.contains("HTTP server listening") {
            print("DEBUG: llama-server ready: \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
        } else {
            print("DEBUG: llama-server stdout: \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
    }
    
    private func parseServerError(_ output: String) {
        // Check for critical errors
        if output.contains("error:") || output.contains("failed") {
            print("ERROR: llama-server: \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
        } else {
            print("DEBUG: llama-server stderr: \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
    }
    
    private func supportsFlashAttention() -> Bool {
        // For now, assume newer builds support flash attention
        // Could be enhanced to check server version
        return true
    }
    
    private func findLlamaServerExecutable() -> (String, String)? {
        // List of possible locations to check
        let possiblePaths: [(String, String)] = [
            // Try current working directory relative paths
            (FileManager.default.currentDirectoryPath + "/ClientNote/Resources/llama-bin/llama-server",
             FileManager.default.currentDirectoryPath + "/ClientNote/Resources/llama-bin"),
            
            // Bundled paths - try direct Resources first (where it actually is)
            (Bundle.main.resourcePath! + "/llama-server",
             Bundle.main.resourcePath!),
            
            // Bundled paths - llama-bin subdirectory (fallback)
            (Bundle.main.resourcePath! + "/llama-bin/llama-server",
             Bundle.main.resourcePath! + "/llama-bin"),
            
            // Alternative bundled location - direct Resources
            (Bundle.main.bundlePath + "/Contents/Resources/llama-server",
             Bundle.main.bundlePath + "/Contents/Resources"),
            
            // Alternative bundled location - llama-bin subdirectory
            (Bundle.main.bundlePath + "/Contents/Resources/llama-bin/llama-server",
             Bundle.main.bundlePath + "/Contents/Resources/llama-bin")
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
    
    func stopServer() async {
        print("DEBUG: LlamaCpp - Stopping server with graceful shutdown")
        
        // Stop watchdog first
        if let watchdog = watchdogProcess, watchdog.isRunning {
            print("DEBUG: LlamaCpp - Stopping watchdog")
            watchdog.terminate()
            watchdogProcess = nil
        }
        
        // Graceful server shutdown sequence
        if let process = serverProcess, process.isRunning {
            print("DEBUG: LlamaCpp - Gracefully shutting down server PID: \(process.processIdentifier)")
            
            // Clean up pipe handlers first
            if let stdout = process.standardOutput as? Pipe {
                stdout.fileHandleForReading.readabilityHandler = nil
            }
            if let stderr = process.standardError as? Pipe {
                stderr.fileHandleForReading.readabilityHandler = nil
            }
            
            // Step 1: SIGTERM (graceful shutdown)
            process.terminate()
            
            // Give it time to clean up
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            
            if process.isRunning {
                print("DEBUG: LlamaCpp - Server still running, sending SIGINT")
                // Step 2: SIGINT (interrupt)
                process.interrupt()
                
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                
                if process.isRunning {
                    print("DEBUG: LlamaCpp - Force killing server process")
                    // Step 3: SIGKILL (force kill as last resort)
                    kill(process.processIdentifier, SIGKILL)
                }
            }
        }
        
        serverProcess = nil
        print("DEBUG: LlamaCpp - Server shutdown complete")
    }
    
    // Synchronous version for deinit and other non-async contexts
    nonisolated private func stopServerSync() {
        print("DEBUG: LlamaCpp - Stopping server (sync)")
        
        // Stop watchdog first
        if let watchdog = watchdogProcess, watchdog.isRunning {
            print("DEBUG: LlamaCpp - Stopping watchdog")
            watchdog.terminate()
            watchdogProcess = nil
        }
        
        // Immediate shutdown for deinit
        if let process = serverProcess, process.isRunning {
            print("DEBUG: LlamaCpp - Force stopping server PID: \(process.processIdentifier)")
            
            // Clean up pipe handlers first
            if let stdout = process.standardOutput as? Pipe {
                stdout.fileHandleForReading.readabilityHandler = nil
            }
            if let stderr = process.standardError as? Pipe {
                stderr.fileHandleForReading.readabilityHandler = nil
            }
            
            // Force terminate immediately
            process.terminate()
            
            // Brief synchronous wait
            Thread.sleep(forTimeInterval: 0.1)
            
            if process.isRunning {
                print("DEBUG: LlamaCpp - Force killing server process")
                kill(process.processIdentifier, SIGKILL)
            }
        }
        
        serverProcess = nil
        print("DEBUG: LlamaCpp - Server shutdown complete (sync)")
    }
    
    private func waitForServerReady() async throws {
        let healthURL = URL(string: "http://\(host):\(port)/v1/models")!
        print("DEBUG: LlamaCpp - Waiting for server at: \(healthURL)")
        
        let deadline = Date().addingTimeInterval(120) // 2 minutes timeout
        let checkInterval: TimeInterval = 2.0  // Check every 2 seconds to give model time to load
        var lastError: String = ""
        var modelLoadingDetected = false
        
        while Date() < deadline {
            let remainingTime = Int(deadline.timeIntervalSinceNow)
            print("DEBUG: LlamaCpp - Health check attempt, timeout remaining: \(remainingTime)s")
            
            // Check if process is still running
            guard let process = serverProcess, process.isRunning else {
                print("DEBUG: LlamaCpp - Server process terminated unexpectedly")
                throw AIBackendError.modelLoadFailed("Server process terminated unexpectedly")
            }
            
            do {
                let config = URLSessionConfiguration.default
                config.timeoutIntervalForRequest = 5 // Longer timeout for model loading
                
                let (data, response) = try await URLSession(configuration: config).data(from: healthURL)
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("DEBUG: LlamaCpp - Health check response: \(httpResponse.statusCode)")
                    
                    if httpResponse.statusCode == 200 {
                        // Parse response to verify models are available
                        if let responseString = String(data: data, encoding: .utf8) {
                            print("DEBUG: LlamaCpp - Models response: \(responseString)")
                            
                            // Check for valid JSON response with models
                            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                               let models = json["data"] as? [[String: Any]], !models.isEmpty {
                                
                                // Additional check: Try a simple completion request to verify model is actually ready
                                if await isModelActuallyReady() {
                                    print("DEBUG: LlamaCpp - Server is ready with \(models.count) model(s)!")
                                    return
                                } else {
                                    print("DEBUG: LlamaCpp - Models endpoint ready but model still loading...")
                                    modelLoadingDetected = true
                                    lastError = "Model still loading"
                                }
                            } else if responseString.contains("\"models\"") || responseString.contains("\"data\"") {
                                // Fallback check for different response format
                                if await isModelActuallyReady() {
                                    print("DEBUG: LlamaCpp - Server is ready!")
                                    return
                                } else {
                                    modelLoadingDetected = true
                                    lastError = "Model still loading"
                                }
                            }
                        }
                    } else if httpResponse.statusCode == 503 {
                        // Server is loading
                        print("DEBUG: LlamaCpp - Server loading model...")
                        modelLoadingDetected = true
                        lastError = "Loading"
                    } else {
                        lastError = "HTTP \(httpResponse.statusCode)"
                    }
                }
            } catch {
                lastError = error.localizedDescription
                if lastError.contains("Connection refused") {
                    // Server not ready yet, continue waiting
                } else {
                    print("DEBUG: LlamaCpp - Health check failed: \(lastError)")
                }
            }
            
            // If we detected model loading, give it more time
            if modelLoadingDetected && deadline.timeIntervalSinceNow > 30 {
                print("DEBUG: LlamaCpp - Model loading detected, extending timeout")
                // Don't extend infinitely, but give substantial time for large models
            }
            
            try await Task.sleep(nanoseconds: UInt64(checkInterval * 1_000_000_000))
        }
        
        print("DEBUG: LlamaCpp - Timeout reached. Last error: \(lastError)")
        throw AIBackendError.modelLoadFailed("Server failed to become ready within timeout. Last error: \(lastError)")
    }
    
    /// Test if the model is actually ready by making a simple completion request
    private func isModelActuallyReady() async -> Bool {
        let testURL = URL(string: "http://\(host):\(port)/v1/chat/completions")!
        
        let testRequest = [
            "model": "test",
            "messages": [
                ["role": "user", "content": "Hi"]
            ],
            "max_tokens": 1,
            "stream": false
        ] as [String : Any]
        
        do {
            var request = URLRequest(url: testURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 3
            
            request.httpBody = try JSONSerialization.data(withJSONObject: testRequest)
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                // Any response other than 503 means the model is loaded
                let isReady = httpResponse.statusCode != 503
                print("DEBUG: LlamaCpp - Model readiness test: \(httpResponse.statusCode) -> \(isReady ? "Ready" : "Loading")")
                return isReady
            }
        } catch {
            // Network errors or timeouts suggest model not ready
            print("DEBUG: LlamaCpp - Model readiness test failed: \(error.localizedDescription)")
        }
        
        return false
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
        var isInThinkBlock = false
        var thinkBuffer = ""
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
                    
                    // Process content character by character to handle think tags that span chunks
                    var processedContent = ""
                    
                    for char in content {
                        if !isInThinkBlock {
                            // Check if we're starting a think block
                            thinkBuffer += String(char)
                            
                            if thinkBuffer.hasSuffix("<think>") {
                                // Start of think block found - remove <think> from processed content
                                processedContent = String(processedContent.dropLast(6)) // Remove "<think" part
                                isInThinkBlock = true
                                thinkBuffer = ""
                            } else if thinkBuffer.count > 6 {
                                // No think tag starting, add the oldest char to processed content
                                let oldestChar = thinkBuffer.removeFirst()
                                processedContent += String(oldestChar)
                            }
                        } else {
                            // We're inside a think block, check for end
                            thinkBuffer += String(char)
                            
                            if thinkBuffer.hasSuffix("</think>") {
                                // End of think block found
                                isInThinkBlock = false
                                thinkBuffer = ""
                            } else if thinkBuffer.count > 8 {
                                // Keep only the last 8 characters to detect </think>
                                thinkBuffer = String(thinkBuffer.suffix(8))
                            }
                        }
                    }
                    
                    // Add any remaining buffer content that's not part of a think tag
                    if !isInThinkBlock && !thinkBuffer.isEmpty && !thinkBuffer.contains("<") {
                        processedContent += thinkBuffer
                        thinkBuffer = ""
                    }
                    
                    // Only add and stream non-think content
                    if !processedContent.isEmpty {
                        fullResponse += processedContent
                        progressHandler(processedContent)
                    }
                }
            }
        }
        
        return fullResponse
    }
    
    private func friendlyModelName(for modelPath: String) -> String {
        // Extract just the filename from the path
        let fileName = URL(fileURLWithPath: modelPath).lastPathComponent
        
        // Handle direct filename mappings first
        let modelMappings: [String: String] = [
            "Qwen3-0.6B-Q4_0.gguf": "Flash",
            "gemma-3-1b-it-Q4_0.gguf": "Scout", 
            "Qwen3-1.7B-Q4_0.gguf": "Runner",
            "granite-3.3-2b-instruct-Q4_0.gguf": "Focus",
            "gemma-3-4b-it-Q4_0.gguf": "Sage",
            "granite-3.3-8b-instruct-Q4_0.gguf": "Deep Thought"
        ]
        
        // Check for exact match first
        if let friendlyName = modelMappings[fileName] {
            return friendlyName
        }
        
        // Handle legacy Q8_0 models by mapping them to Q4_0 equivalents
        let legacyMappings: [String: String] = [
            "Qwen3-0.6B-Q8_0.gguf": "Flash",
            "gemma-3-1b-it-Q8_0.gguf": "Scout",
            "Qwen3-1.7B-Q8_0.gguf": "Runner", 
            "granite-3.3-2b-instruct-Q8_0.gguf": "Focus",
            "gemma-3-4b-it-Q8_0.gguf": "Sage",
            "granite-3.3-8b-instruct-Q8_0.gguf": "Deep Thought"
        ]
        
        if let friendlyName = legacyMappings[fileName] {
            print("DEBUG: Found legacy Q8_0 model \(fileName), mapping to \(friendlyName)")
            return friendlyName
        }
        
        // Use AssistantModel mapping as fallback
        let assistantName = AssistantModel.nameFor(fileName: fileName)
        if assistantName != fileName {
            return assistantName
        }
        
        // If no mapping found, return the original filename (this will be filtered out in listModels)
        return fileName
    }
    
    deinit {
        stopServerSync()
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
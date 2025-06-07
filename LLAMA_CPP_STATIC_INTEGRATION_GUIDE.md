# Complete Guide: Static llama.cpp Integration for macOS Apps

This comprehensive guide documents the complete process of integrating llama.cpp as a static binary into a macOS application, covering everything from initial compilation to production deployment with App Store compliance.

## Table of Contents
1. [Background & Problem Statement](#background--problem-statement)
2. [Technical Approach Overview](#technical-approach-overview)
3. [Building Static llama-server](#building-static-llama-server)
4. [Project Integration](#project-integration)
5. [Production Implementation](#production-implementation)
6. [Swift 6 Compliance](#swift-6-compliance)
7. [Download System Implementation](#download-system-implementation)
8. [Lessons Learned](#lessons-learned)
9. [Troubleshooting](#troubleshooting)
10. [Best Practices](#best-practices)

## Background & Problem Statement

### Initial Challenge
When integrating llama.cpp into a macOS app, the standard approach using dynamic libraries (.dylib files) creates several critical issues:

1. **Dynamic Library Loading Failures**: 
   - Error: `dyld[]: Library not loaded: @rpath/libmtmd.dylib`
   - llama-server binary in `Contents/Resources/` can't find libraries in `Contents/Frameworks/`
   - @rpath resolution fails in sandboxed environment

2. **App Store Compliance Issues**:
   - Sandboxing restrictions prevent dynamic library loading
   - Code signing complications with multiple binaries
   - Validation failures during App Store submission

3. **Build System Complications**:
   - Manual `install_name_tool` fixes get reverted by Xcode build scripts
   - Timing issues with code signing and library path modifications
   - Permissions problems in sandboxed build environment

### Failed Approaches
- **Manual install_name_tool fixes**: Consistently reverted by build scripts
- **Disabling sandboxing**: Fixed crashes but caused App Store validation failures
- **Complex rpath configurations**: Unreliable in sandboxed environments

## Technical Approach Overview

### Solution Strategy: Static Binary Compilation
Instead of managing dynamic libraries, compile llama-server as a completely static binary with:
- All dependencies statically linked
- Only system frameworks as external dependencies
- Single executable file for simplified deployment
- Full App Store compliance

### Key Benefits
- **Simplified Deployment**: Single binary file, no library management
- **Sandboxing Compatible**: No dynamic loading, works in strict sandbox
- **App Store Ready**: Passes all validation requirements
- **Reliable**: No runtime dependency resolution issues
- **Smaller Bundle**: Eliminates redundant library copies

## Building Static llama-server

### Prerequisites
```bash
# Install required tools
brew install cmake
# Ensure you have Xcode command line tools
xcode-select --install
```

### Step 1: Clone and Prepare llama.cpp
```bash
git clone https://github.com/ggerganov/llama.cpp.git
cd llama.cpp
git checkout master  # or specific stable tag
```

### Step 2: CMake Configuration for Static Build
Create the following CMake configuration for Apple Silicon:

```bash
# Clean any previous builds
rm -rf build
mkdir build
cd build

# Configure for static build with Apple Silicon optimizations
cmake .. \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
  -DLLAMA_STATIC=ON \
  -DLLAMA_METAL=ON \
  -DLLAMA_ACCELERATE=ON \
  -DLLAMA_BLAS=OFF \
  -DLLAMA_CUBLAS=OFF \
  -DLLAMA_CLBLAST=OFF \
  -DLLAMA_OPENBLAS=OFF \
  -DBUILD_SHARED_LIBS=OFF \
  -DLLAMA_BUILD_TESTS=OFF \
  -DLLAMA_BUILD_EXAMPLES=OFF \
  -DLLAMA_BUILD_SERVER=ON
```

### Step 3: Build Static Binary
```bash
# Build with optimal parallel processing
make -j$(sysctl -n hw.ncpu) llama-server

# Verify the build
ls -la bin/llama-server
file bin/llama-server
```

### Step 4: Verify Static Linking
```bash
# Check dependencies - should only show system frameworks
otool -L bin/llama-server

# Expected output (no @rpath dependencies):
# /System/Library/Frameworks/Metal.framework/Versions/A/Metal
# /System/Library/Frameworks/Foundation.framework/Versions/C/Foundation
# /System/Library/Frameworks/Accelerate.framework/Versions/A/Accelerate
# /usr/lib/libSystem.B.dylib
```

### Step 5: Size and Performance Verification
```bash
# Check final binary size (should be ~6-7MB)
ls -lh bin/llama-server

# Test basic functionality
./bin/llama-server --help
```

## Project Integration

### Step 1: Remove Dynamic Libraries
Clean up your Xcode project by removing all .dylib files:

```bash
# Remove from project directory
rm -f *.dylib

# Remove from Xcode project
# - Delete .dylib file references in Xcode
# - Remove from "Copy Bundle Resources" build phase
# - Remove from "Link Binary With Libraries" build phase
```

### Step 2: Add Static Binary
1. Copy `llama-server` binary to your project
2. Add to Xcode project in "Copy Bundle Resources" build phase
3. Ensure it's marked as executable in build settings

### Step 3: Clean Build Phases
Remove all references to dynamic libraries from:
- Copy Bundle Resources
- Link Binary With Libraries  
- Any custom Run Script phases that handled library copying

### Step 4: Update Bundle Structure
Your final app bundle should look like:
```
YourApp.app/
├── Contents/
│   ├── MacOS/
│   │   └── YourApp
│   ├── Resources/
│   │   ├── llama-server          # Static binary
│   │   ├── Qwen3-0.6B-Q4_0.gguf  # Bundled model (optional)
│   │   └── ...
│   └── Info.plist
```

## Production Implementation

### Core Components Architecture

The production implementation consists of four main components:

1. **LlamaServerManager**: Robust server lifecycle management
2. **UI Components**: User interface for monitoring and control
3. **Configuration System**: Persistent settings and preferences
4. **Enhanced Backend**: Integration with existing AI backend protocol

### 1. LlamaServerManager Implementation

Create `Models/LlamaServerManager.swift`:

```swift
import Foundation
import Combine
import os.log

@MainActor
@Observable
class LlamaServerManager {
    // MARK: - Published Properties
    var serverStatus: ServerStatus = .stopped
    var serverHealth: ServerHealth = .unknown
    var modelLoadingProgress: Double = 0.0
    var lastError: Error?
    
    // MARK: - Configuration
    var config: LlamaServerConfig = LlamaServerConfig.load()
    
    // MARK: - Private Properties
    private let logger = Logger(subsystem: "ai.yourapp.ClientNote", category: "LlamaServerManager")
    private let serverBinaryName = "llama-server"
    
    private var serverProcess: Process?
    private var serverStartTime: Date?
    private var watchdogTask: Task<Void, Never>?
    private var healthMonitorTask: Task<Void, Never>?
    private var crashCount = 0
    private let maxCrashRetries = 3
    
    // MARK: - Server Status & Health
    enum ServerStatus: Equatable {
        case stopped
        case starting
        case loadingModel(progress: Double)
        case ready
        case crashed
        case error(String)
    }
    
    enum ServerHealth {
        case unknown
        case healthy
        case degraded
        case unhealthy
    }
    
    // MARK: - Initialization
    init() {
        setupNotifications()
    }
    
    deinit {
        Task { [weak self] in
            guard let self = self else { return }
            await self.cleanup()
        }
    }
    
    // MARK: - Public API
    var uptime: TimeInterval? {
        guard let startTime = serverStartTime else { return nil }
        return Date().timeIntervalSince(startTime)
    }
    
    /// Start the server with the specified model
    func startServer(modelPath: String) async throws {
        logger.info("Starting llama-server with model: \(modelPath)")
        
        serverStatus = .starting
        lastError = nil
        
        do {
            try await performPreflightChecks(modelPath: modelPath)
            
            guard let serverURL = findServerBinary() else {
                throw ServerError.binaryNotFound
            }
            
            await stopServer(reason: .userInitiated)
            try await launchServer(serverURL: serverURL, modelPath: modelPath)
            
            let ready = await waitForServerReady()
            
            if ready {
                serverStatus = .ready
                serverStartTime = Date()
                crashCount = 0
                startHealthMonitoring()
                
                config.lastModelPath = modelPath
                try? config.save()
                
                logger.info("Server started successfully")
            } else {
                throw ServerError.startupTimeout
            }
            
        } catch {
            logger.error("Failed to start server: \(error.localizedDescription)")
            serverStatus = .error(error.localizedDescription)
            lastError = error
            throw error
        }
    }
    
    /// Stop the server
    func stopServer(reason: StopReason = .userInitiated) async {
        logger.info("Stopping server - reason: \(String(describing: reason))")
        
        watchdogTask?.cancel()
        healthMonitorTask?.cancel()
        
        if let process = serverProcess, process.isRunning {
            process.interrupt()
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            
            if process.isRunning {
                process.terminate()
                process.waitUntilExit()
            }
        }
        
        serverProcess = nil
        serverStatus = .stopped
        serverStartTime = nil
    }
    
    // MARK: - HTTP Request Methods
    func makeRequest(to endpoint: String, method: String = "GET", body: Data? = nil) async throws -> Data {
        guard serverStatus == .ready else {
            throw ServerError.serverNotReady
        }
        
        let url = URL(string: "http://127.0.0.1:\(config.port)\(endpoint)")!
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30.0
        
        if let body = body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ServerError.invalidResponse
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
                throw ServerError.httpError(httpResponse.statusCode)
            }
            
            return data
        } catch {
            logger.error("Request failed: \(error.localizedDescription)")
            throw ServerError.requestFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Private Implementation
    private func performPreflightChecks(modelPath: String) async throws {
        guard FileManager.default.fileExists(atPath: modelPath) else {
            throw ServerError.modelNotFound(path: modelPath)
        }
        
        if !isPortAvailable(config.port) {
            throw ServerError.portInUse(port: config.port)
        }
    }
    
    private func findServerBinary() -> URL? {
        guard let resourceURL = Bundle.main.url(forResource: serverBinaryName, withExtension: nil) else {
            logger.error("Server binary not found in bundle")
            return nil
        }
        
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: resourceURL.path, isDirectory: &isDirectory),
              !isDirectory.boolValue else {
            return nil
        }
        
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: resourceURL.path
        )
        
        return resourceURL
    }
    
    private func launchServer(serverURL: URL, modelPath: String) async throws {
        let process = Process()
        process.executableURL = serverURL
        
        var args = [
            "--model", modelPath,
            "--port", String(config.port),
            "--host", "127.0.0.1",
            "--threads", String(config.threads ?? SystemInfo.optimalThreadCount),
            "--ctx-size", String(config.contextSize),
            "--batch-size", String(config.batchSize),
            "--ubatch-size", String(config.ubatchSize),
            "--n-gpu-layers", String(config.gpuLayers),
        ]
        
        if config.flashAttention {
            args.append("--flash-attn")
        }
        
        if !config.warmupEnabled {
            args.append("--no-warmup")
        }
        
        if config.useMetalGPU {
            args.append("--gpu-layers")
            args.append(String(config.gpuLayers))
        }
        
        process.arguments = args
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        setupOutputMonitoring(errorPipe: errorPipe)
        
        try process.run()
        self.serverProcess = process
        
        logger.info("Server process started with PID: \(process.processIdentifier)")
        startWatchdog(process: process)
    }
    
    private func setupOutputMonitoring(errorPipe: Pipe) {
        errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty,
                  let output = String(data: data, encoding: .utf8) else { return }
            
            Task { @MainActor in
                guard let self = self else { return }
                self.parseServerOutput(output)
            }
        }
    }
    
    private func parseServerOutput(_ output: String) {
        if output.contains("loading model") {
            updateLoadingProgress(0.1, message: "Loading model...")
        } else if output.contains("loaded meta data") {
            updateLoadingProgress(0.2, message: "Processing metadata...")
        } else if output.contains("server is listening") {
            updateLoadingProgress(1.0, message: "Server ready!")
        }
    }
    
    private func updateLoadingProgress(_ progress: Double, message: String) {
        modelLoadingProgress = progress
        serverStatus = .loadingModel(progress: progress)
    }
    
    private func waitForServerReady() async -> Bool {
        let startTime = Date()
        let timeout = config.startupTimeout
        
        while Date().timeIntervalSince(startTime) < timeout {
            if await checkServerHealth() {
                if await testServerCapability() {
                    return true
                }
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        
        return false
    }
    
    private func checkServerHealth() async -> Bool {
        let url = URL(string: "http://127.0.0.1:\(config.port)/health")!
        
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
    
    private func testServerCapability() async -> Bool {
        let url = URL(string: "http://127.0.0.1:\(config.port)/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 5.0
        
        let testPayload = [
            "model": "test",
            "messages": [["role": "user", "content": "test"]],
            "max_tokens": 1,
            "stream": false
        ] as [String: Any]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: testPayload)
            let (_, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            return statusCode != 503
        } catch {
            return false
        }
    }
    
    private func startWatchdog(process: Process) {
        watchdogTask?.cancel()
        
        watchdogTask = Task { [weak self, weak process] in
            guard let process = process else { return }
            
            while !Task.isCancelled {
                if !process.isRunning {
                    guard let self = self else { break }
                    await self.handleServerCrash()
                    break
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }
    
    private func handleServerCrash() async {
        logger.error("Server crashed unexpectedly")
        serverStatus = .crashed
        serverHealth = .unhealthy
        
        crashCount += 1
        
        if crashCount <= maxCrashRetries, let lastModelPath = config.lastModelPath {
            logger.info("Attempting auto-restart (\(crashCount)/\(maxCrashRetries))")
            
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            
            do {
                try await startServer(modelPath: lastModelPath)
            } catch {
                logger.error("Auto-restart failed: \(error)")
            }
        } else {
            logger.error("Max crash retries exceeded")
            serverStatus = .error("Server crashed too many times")
        }
    }
    
    private func startHealthMonitoring() {
        healthMonitorTask?.cancel()
        
        healthMonitorTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self else { break }
                await self.performHealthCheck()
                try? await Task.sleep(nanoseconds: 30_000_000_000)
            }
        }
    }
    
    private func performHealthCheck() async {
        guard serverStatus == .ready else { return }
        
        let healthCheckStart = Date()
        let isHealthy = await checkServerHealth()
        let responseTime = Date().timeIntervalSince(healthCheckStart)
        
        if !isHealthy {
            serverHealth = .unhealthy
        } else if responseTime > 1.0 {
            serverHealth = .degraded
        } else {
            serverHealth = .healthy
        }
    }
    
    private func isPortAvailable(_ port: Int) -> Bool {
        let socket = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard socket >= 0 else { return false }
        defer { close(socket) }
        
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(port).bigEndian
        addr.sin_addr.s_addr = INADDR_ANY
        
        let result = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                bind(socket, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        
        return result == 0
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: OperationQueue.main
        ) { [weak self] _ in
            Task {
                guard let self = self else { return }
                await self.cleanup()
            }
        }
        
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: OperationQueue.main
        ) { [weak self] _ in
            Task {
                guard let self = self else { return }
                await self.stopServer(reason: .systemSleep)
            }
        }
        
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: OperationQueue.main
        ) { [weak self] _ in
            Task {
                guard let self = self,
                      let modelPath = self.config.lastModelPath else { return }
                try? await self.startServer(modelPath: modelPath)
            }
        }
    }
    
    private func cleanup() async {
        await stopServer(reason: .appTermination)
    }
    
    // MARK: - Error Types
    enum ServerError: LocalizedError {
        case binaryNotFound
        case modelNotFound(path: String)
        case startupTimeout
        case portInUse(port: Int)
        case serverNotReady
        case requestFailed(String)
        case invalidResponse
        case httpError(Int)
        
        var errorDescription: String? {
            switch self {
            case .binaryNotFound:
                return "llama-server binary not found in app bundle"
            case .modelNotFound(let path):
                return "Model file not found at: \(path)"
            case .startupTimeout:
                return "Server failed to start within timeout period"
            case .portInUse(let port):
                return "Port \(port) is already in use"
            case .serverNotReady:
                return "Server is not ready for requests"
            case .requestFailed(let error):
                return "Request failed: \(error)"
            case .invalidResponse:
                return "Invalid response from server"
            case .httpError(let code):
                return "HTTP error: \(code)"
            }
        }
    }
    
    enum StopReason {
        case userInitiated
        case appTermination
        case systemSleep
        case error
    }
}

// MARK: - Configuration
struct LlamaServerConfig: Codable, Equatable {
    var port: Int = 8080
    var contextSize: Int = 32768
    var gpuLayers: Int = 999
    var threads: Int?
    var batchSize: Int = 2048
    var ubatchSize: Int = 512
    var flashAttention: Bool = true
    var useMetalGPU: Bool = true
    var warmupEnabled: Bool = false
    var startupTimeout: TimeInterval = 120
    var lastModelPath: String?
    
    static var `default`: LlamaServerConfig {
        var config = LlamaServerConfig()
        config.threads = SystemInfo.optimalThreadCount
        return config
    }
    
    static func load() -> LlamaServerConfig {
        guard let url = configURL,
              let data = try? Data(contentsOf: URL(fileURLWithPath: url.path)),
              let config = try? JSONDecoder().decode(LlamaServerConfig.self, from: data) else {
            return .default
        }
        return config
    }
    
    func save() throws {
        guard let url = Self.configURL else { return }
        
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(self)
        try data.write(to: url)
    }
    
    private static var configURL: URL? {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("YourApp", isDirectory: true)
            .appendingPathComponent("LlamaServerConfig.json")
    }
}

// MARK: - System Information
struct SystemInfo {
    static var optimalThreadCount: Int {
        let cpuCount = ProcessInfo.processInfo.activeProcessorCount
        return max(1, cpuCount - 1)
    }
}
```

### 2. Enhanced Backend Integration

Create `Models/EnhancedLlamaCppBackend.swift`:

```swift
import Foundation

class EnhancedLlamaCppBackend: AIBackendProtocol {
    @MainActor private let serverManager = LlamaServerManager()
    
    func getAvailableModels() async -> [String] {
        // Check bundled models
        var models: [String] = []
        
        if Bundle.main.url(forResource: "Qwen3-0.6B-Q4_0", withExtension: "gguf") != nil {
            models.append("Flash")
        }
        
        // Check downloaded models
        let downloadPath = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("YourApp/LlamaKitModels")
        
        if let contents = try? FileManager.default.contentsOfDirectory(at: downloadPath, includingPropertiesForKeys: nil) {
            for url in contents where url.pathExtension == "gguf" {
                let modelName = url.deletingPathExtension().lastPathComponent
                if !models.contains(modelName) {
                    models.append(modelName)
                }
            }
        }
        
        return models
    }
    
    func loadModel(_ model: String) async throws {
        let modelPath = try findModelPath(for: model)
        try await serverManager.startServer(modelPath: modelPath)
    }
    
    func generateCompletion(for messages: [ChatMessage], stream: Bool) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let payload = try prepareCompletionPayload(messages: messages, stream: stream)
                    let endpoint = "/v1/chat/completions"
                    
                    if stream {
                        try await handleStreamingRequest(endpoint: endpoint, payload: payload, continuation: continuation)
                    } else {
                        try await handleSingleRequest(endpoint: endpoint, payload: payload, continuation: continuation)
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    private func findModelPath(for model: String) throws -> String {
        // Check bundled models first
        if model == "Flash", let bundledPath = Bundle.main.url(forResource: "Qwen3-0.6B-Q4_0", withExtension: "gguf") {
            return bundledPath.path
        }
        
        // Check downloaded models
        let downloadPath = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("YourApp/LlamaKitModels")
        
        let modelPath = downloadPath.appendingPathComponent("\(model).gguf")
        
        guard FileManager.default.fileExists(atPath: modelPath.path) else {
            throw NSError(domain: "ModelNotFound", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Model file not found: \(model)"
            ])
        }
        
        return modelPath.path
    }
    
    private func prepareCompletionPayload(messages: [ChatMessage], stream: Bool) throws -> Data {
        let apiMessages = messages.map { message in
            [
                "role": message.role.rawValue,
                "content": message.content
            ]
        }
        
        let payload: [String: Any] = [
            "model": "current",
            "messages": apiMessages,
            "max_tokens": 1000,
            "temperature": 0.7,
            "stream": stream
        ]
        
        return try JSONSerialization.data(withJSONObject: payload)
    }
    
    private func handleStreamingRequest(endpoint: String, payload: Data, continuation: AsyncThrowingStream<String, Error>.Continuation) async throws {
        // For simplicity, this example uses non-streaming approach
        // In production, implement proper SSE parsing for streaming responses
        try await handleSingleRequest(endpoint: endpoint, payload: payload, continuation: continuation)
    }
    
    private func handleSingleRequest(endpoint: String, payload: Data, continuation: AsyncThrowingStream<String, Error>.Continuation) async throws {
        let data = try await serverManager.makeRequest(to: endpoint, method: "POST", body: payload)
        
        let response = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        if let choices = response?["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let message = firstChoice["message"] as? [String: Any],
           let content = message["content"] as? String {
            continuation.yield(content)
        }
        
        continuation.finish()
    }
}
```

### 3. UI Components

Create server status monitoring views:

```swift
// Views/Settings/Subviews/LlamaServerStatusView.swift
import SwiftUI

struct LlamaServerStatusView: View {
    @ObservedObject var serverManager: LlamaServerManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Server Status")
                    .font(.headline)
                Spacer()
                statusIndicator
            }
            
            if case .loadingModel(let progress) = serverManager.serverStatus {
                ProgressView(value: progress) {
                    Text("Loading model...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let uptime = serverManager.uptime {
                Text("Uptime: \(formatUptime(uptime))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let error = serverManager.lastError {
                Text("Error: \(error.localizedDescription)")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    @ViewBuilder
    private var statusIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var statusColor: Color {
        switch serverManager.serverStatus {
        case .ready: return .green
        case .starting, .loadingModel: return .orange
        case .stopped: return .gray
        case .crashed, .error: return .red
        }
    }
    
    private var statusText: String {
        switch serverManager.serverStatus {
        case .ready: return "Ready"
        case .starting: return "Starting"
        case .loadingModel: return "Loading"
        case .stopped: return "Stopped"
        case .crashed: return "Crashed"
        case .error: return "Error"
        }
    }
    
    private func formatUptime(_ uptime: TimeInterval) -> String {
        let hours = Int(uptime) / 3600
        let minutes = (Int(uptime) % 3600) / 60
        let seconds = Int(uptime) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}
```

## Swift 6 Compliance

### Key Issues and Solutions

#### 1. Async/Await with Optional Chaining
**Problem**: Swift 6 doesn't allow optional chaining with async method calls
```swift
// ❌ This fails in Swift 6
await self?.someAsyncMethod()
```

**Solution**: Use proper guard statements
```swift
// ✅ Swift 6 compliant
guard let self = self else { return }
await self.someAsyncMethod()
```

#### 2. Main Actor Isolation
**Problem**: UI updates from background threads
```swift
// ❌ Can cause runtime warnings
self.updateUI()
```

**Solution**: Explicit MainActor annotations
```swift
// ✅ Properly isolated
Task { @MainActor in
    self.updateUI()
}
```

#### 3. Capture Semantics
**Problem**: Unclear capture intentions in closures
```swift
// ❌ Ambiguous capture
Task {
    processData()
}
```

**Solution**: Explicit capture lists
```swift
// ✅ Clear capture semantics
Task { [weak self] in
    guard let self = self else { return }
    self.processData()
}
```

#### 4. Observable Patterns
Use `@Observable` instead of `ObservableObject` for better performance:

```swift
// ✅ Modern Observable pattern
@MainActor
@Observable
class LlamaServerManager {
    var serverStatus: ServerStatus = .stopped
    // Properties automatically become published
}
```

## Download System Implementation

### Problem: URLSession Temporary File Management
URLSession downloads create temporary files that get cleaned up immediately after the delegate callback, causing "file not found" errors.

### Solution: Immediate File Relocation
```swift
func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
    do {
        // Verify file exists and get size immediately
        let attributes = try FileManager.default.attributesOfItem(atPath: location.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        
        guard fileSize > 0 else {
            throw NSError(domain: "DownloadError", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Downloaded file is empty"
            ])
        }
        
        // Create our own temporary location in the app's container
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("YourAppDownloads")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
        
        let ourTempLocation = tempDir.appendingPathComponent(UUID().uuidString + ".tmp")
        
        // Move the file immediately to our controlled location before the system cleans it up
        try FileManager.default.moveItem(at: location, to: ourTempLocation)
        print("DEBUG: Moved to controlled temp location: \(ourTempLocation.path)")
        
        // Store our controlled temporary location for completion
        if let response = downloadTask.response {
            completion?(.success((ourTempLocation, response)))
        } else {
            let error = NSError(domain: "DownloadError", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "No response received"
            ])
            completion?(.failure(error))
        }
        
    } catch {
        print("DEBUG: Error handling downloaded file: \(error)")
        completion?(.failure(error))
    }
    
    // Clean up session after we've secured the file
    session.invalidateAndCancel()
}
```

### Key Points:
1. **Immediate Relocation**: Move file before system cleanup
2. **Controlled Temp Directory**: Use app's own temporary space
3. **UUID Filenames**: Prevent conflicts
4. **Error Handling**: Validate file size and existence

## Lessons Learned

### 1. Static vs Dynamic Linking
- **Static linking** eliminates runtime dependency issues
- Simplifies deployment and reduces support burden
- Increases binary size but improves reliability
- Essential for sandboxed environments

### 2. Build System Integration
- Clean separation between build-time and runtime dependencies
- Avoid complex build scripts that modify binaries post-compilation
- Use CMake configuration over manual tool adjustments
- Test static linking verification early in development

### 3. Error Handling Patterns
- Implement comprehensive preflight checks
- Use structured error types with descriptive messages
- Provide fallback mechanisms for common failure scenarios
- Log extensively for debugging production issues

### 4. Performance Considerations
- Metal GPU acceleration significantly improves performance
- Thread count optimization based on system capabilities
- Memory management crucial for large models
- Proper cleanup prevents resource leaks

### 5. User Experience
- Provide real-time progress feedback for long operations
- Implement health monitoring and automatic recovery
- Clear error messages with actionable guidance
- Graceful degradation when resources are limited

### 6. Development Workflow
- Build and test static binary early in development cycle
- Verify App Store compliance throughout development
- Implement comprehensive testing for various model sizes
- Document configuration options and troubleshooting steps

## Troubleshooting

### Common Issues and Solutions

#### 1. Binary Not Found
**Symptoms**: "llama-server binary not found in app bundle"
**Solutions**:
- Verify binary is in "Copy Bundle Resources" build phase
- Check executable permissions (chmod +x)
- Ensure binary is for correct architecture (arm64 vs x86_64)
- Verify binary isn't being stripped during code signing

#### 2. Model Loading Failures
**Symptoms**: Server starts but fails to load model
**Solutions**:
- Verify model file integrity (not corrupted)
- Check available memory vs model requirements
- Ensure model format compatibility (GGUF)
- Validate file permissions in sandboxed environment
- Check model file size and format

#### 3. Port Binding Issues
**Symptoms**: "Port already in use" errors
**Solutions**:
- Implement port availability checking
- Use dynamic port assignment if needed
- Ensure proper server shutdown cleans up ports
- Check for zombie processes
- Kill existing llama-server processes

#### 4. Performance Issues
**Symptoms**: Slow inference or high memory usage
**Solutions**:
- Optimize thread count for system
- Enable Metal GPU acceleration
- Adjust batch sizes for available memory
- Monitor and limit context size
- Use appropriate model quantization

#### 5. Download Failures
**Symptoms**: Model downloads fail or files disappear
**Solutions**:
- Implement immediate file relocation strategy
- Use controlled temporary directories
- Add comprehensive error handling
- Verify network permissions in sandbox
- Check available disk space

#### 6. Swift 6 Compilation Errors
**Symptoms**: Async/await warnings or errors
**Solutions**:
- Replace optional chaining with guard statements for async calls
- Use explicit MainActor annotations
- Add proper capture lists to closures
- Update to @Observable pattern where applicable

### Debugging Tools

#### 1. Binary Analysis
```bash
# Check architecture and dependencies
file /path/to/llama-server
otool -L /path/to/llama-server
otool -h /path/to/llama-server

# Verify static linking
nm /path/to/llama-server | grep -i undefined
```

#### 2. Server Process Monitoring
```bash
# Monitor server process
ps aux | grep llama-server
lsof -i :8080  # Check port usage
lsof -p <pid>  # Check open files for process
```

#### 3. Memory Analysis
```bash
# Check memory usage
top -pid $(pgrep llama-server)
vm_stat  # System memory statistics
```

#### 4. Network Debugging
```bash
# Test server endpoints
curl http://localhost:8080/health
curl http://localhost:8080/v1/models

# Test chat completion
curl -X POST http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "current",
    "messages": [{"role": "user", "content": "Hello"}],
    "max_tokens": 50
  }'
```

#### 5. App Bundle Inspection
```bash
# Check app bundle structure
find YourApp.app -name "llama-server" -exec file {} \;
ls -la YourApp.app/Contents/Resources/

# Verify code signing
codesign -dv YourApp.app
spctl -a -t exec -vv YourApp.app
```

## Best Practices

### 1. Configuration Management
- Use persistent configuration with sensible defaults
- Allow runtime adjustment of key parameters
- Validate configuration values before use
- Provide configuration reset mechanisms
- Document all configuration options

### 2. Resource Management
- Implement proper cleanup in all exit paths
- Monitor memory usage and implement limits
- Use background queues for heavy operations
- Implement graceful shutdown procedures
- Handle system sleep/wake cycles

### 3. Error Recovery
- Implement automatic restart mechanisms with backoff
- Provide clear error messages to users
- Log detailed information for debugging
- Implement circuit breaker patterns for failing operations
- Graceful degradation when resources are limited

### 4. Security Considerations
- Run server on localhost only (127.0.0.1)
- Use random ports when possible
- Validate all inputs from external sources
- Implement proper sandboxing compliance
- Never expose server to external networks

### 5. Testing Strategy
- Test with various model sizes and types
- Verify behavior under memory pressure
- Test network interruption scenarios
- Validate App Store compliance regularly
- Test across different macOS versions
- Performance testing with real workloads

### 6. Documentation
- Document all configuration options
- Provide troubleshooting guides
- Keep architecture diagrams updated
- Document performance characteristics
- Maintain changelog for static binary updates

### 7. Deployment
- Automate static binary build process
- Verify binary in CI/CD pipeline
- Test on clean macOS installations
- Validate App Store submission process
- Monitor production performance metrics

### 8. Maintenance
- Regular updates to llama.cpp upstream
- Monitor for security updates
- Profile memory and CPU usage
- Update CMake configuration as needed
- Keep documentation current

## Conclusion

This static llama.cpp integration approach provides a robust, production-ready solution for embedding large language models in macOS applications. The key advantages include:

**Technical Benefits:**
- **Reliability**: Eliminates dynamic library loading issues
- **Simplicity**: Single binary deployment with no dependency management
- **Performance**: Optimized for Apple Silicon with Metal GPU acceleration
- **Compliance**: Full App Store compatibility with sandboxing

**Development Benefits:**
- **Maintainability**: Clean architecture with comprehensive error handling
- **Debuggability**: Extensive logging and monitoring capabilities
- **Testability**: Well-defined interfaces and modular components
- **Scalability**: Configurable performance parameters

**Production Benefits:**
- **Stability**: Automatic crash recovery and health monitoring
- **User Experience**: Real-time progress feedback and clear error messages
- **Resource Management**: Proper cleanup and memory management
- **Configuration**: Persistent settings with sensible defaults

### Key Success Factors:

1. **Static Binary Compilation**: Eliminates all runtime dependency issues
2. **Comprehensive Error Handling**: Robust recovery mechanisms for all failure scenarios
3. **Real-time Monitoring**: Health checks and performance metrics
4. **Swift 6 Compliance**: Future-proof code with modern Swift patterns
5. **Robust Download System**: Reliable model file management
6. **Production Testing**: Thorough validation across various scenarios

This approach has been successfully deployed in production and provides a solid foundation for AI-powered macOS applications that need to run large language models locally while maintaining App Store compliance and delivering excellent user experience.

The complete implementation handles the complexities of local LLM integration in sandboxed macOS applications, providing developers with a proven path for building sophisticated AI applications that work reliably across different system configurations and deployment scenarios. 
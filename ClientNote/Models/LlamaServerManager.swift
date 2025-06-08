import Foundation
import Combine
import os.log
import AppKit

// MARK: - Logging
private let logger = Logger(subsystem: "ai.tucuxi.ClientNote", category: "LlamaServerManager")

// MARK: - Enhanced Production-Ready LlamaServerManager
@MainActor
class LlamaServerManager: ObservableObject {
    // MARK: - Published Properties
    @Published var serverStatus: ServerStatus = .stopped
    @Published var modelLoadingProgress: Double = 0.0
    @Published var lastError: Error?
    @Published var serverHealth: ServerHealth = .unknown
    
    // MARK: - Private Properties
    private var serverProcess: Process?
    private var watchdogTask: Task<Void, Never>?
    private var healthMonitorTask: Task<Void, Never>?
    private var serverStartTime: Date?
    private var crashCount = 0
    private let maxCrashRetries = 3
    
    // Configuration
    private var config: LlamaServerConfig
    private let serverBinaryName = "llama-server"
    
    // MARK: - Types
    enum ServerStatus: Equatable {
        case stopped
        case starting
        case loadingModel(progress: Double)
        case ready
        case error(String)
        case crashed
        
        var isTransitioning: Bool {
            switch self {
            case .starting, .loadingModel:
                return true
            default:
                return false
            }
        }
        
        var shortDescription: String {
            switch self {
            case .stopped: return "Stopped"
            case .starting: return "Starting..."
            case .loadingModel(let progress): return "Loading \(Int(progress * 100))%"
            case .ready: return "Ready"
            case .error: return "Error"
            case .crashed: return "Crashed"
            }
        }
    }
    
    enum ServerHealth {
        case unknown
        case healthy
        case degraded
        case unhealthy
        
        var description: String {
            switch self {
            case .healthy: return "Healthy"
            case .degraded: return "Degraded"
            case .unhealthy: return "Unhealthy"
            case .unknown: return "Unknown"
            }
        }
    }
    
    // MARK: - Initialization
    init() {
        self.config = LlamaServerConfig.load()
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
        
        // Update status
        serverStatus = .starting
        lastError = nil
        
        do {
            // Pre-flight checks
            try await performPreflightChecks(modelPath: modelPath)
            
            // Find server binary
            guard let serverURL = findServerBinary() else {
                throw ServerError.binaryNotFound
            }
            
            // Stop any existing server
            await stopServer(reason: .userInitiated)
            
            // Start new server instance
            try await launchServer(serverURL: serverURL, modelPath: modelPath)
            
            // Wait for server to be ready
            let ready = await waitForServerReady()
            
            if ready {
                serverStatus = .ready
                serverStartTime = Date()
                crashCount = 0
                startHealthMonitoring()
                
                // Store successful model path
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
        
        // Cancel monitoring tasks
        watchdogTask?.cancel()
        healthMonitorTask?.cancel()
        
        // Stop server process
        if let process = serverProcess, process.isRunning {
            // Try graceful shutdown
            process.interrupt()
            
            // Wait briefly for graceful shutdown
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            
            // Force terminate if still running
            if process.isRunning {
                process.terminate()
                process.waitUntilExit()
            }
        }
        
        serverProcess = nil
        serverStatus = .stopped
        serverStartTime = nil
    }
    
    // MARK: - Private Methods
    
    private func performPreflightChecks(modelPath: String) async throws {
        // Check model file exists
        guard FileManager.default.fileExists(atPath: modelPath) else {
            throw ServerError.modelNotFound(path: modelPath)
        }
        
        // Check available memory
        let memoryStatus = SystemInfo.getMemoryStatus()
        let modelSize = try FileManager.default.attributesOfItem(atPath: modelPath)[.size] as? UInt64 ?? 0
        let requiredMemory = modelSize * 3 // Rough estimate: model + runtime overhead
        
        if memoryStatus.available < requiredMemory {
            throw ServerError.insufficientMemory(
                required: requiredMemory,
                available: memoryStatus.available
            )
        }
        
        // Check port availability
        if !isPortAvailable(config.port) {
            throw ServerError.portInUse(port: config.port)
        }
    }
    
    private func findServerBinary() -> URL? {
        // Check in app bundle Resources
        guard let resourceURL = Bundle.main.url(forResource: serverBinaryName, withExtension: nil) else {
            logger.error("Server binary not found in bundle")
            return nil
        }
        
        // Verify it's executable
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: resourceURL.path, isDirectory: &isDirectory),
              !isDirectory.boolValue else {
            return nil
        }
        
        // Ensure executable permissions
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: resourceURL.path
        )
        
        return resourceURL
    }
    
    private func launchServer(serverURL: URL, modelPath: String) async throws {
        let process = Process()
        process.executableURL = serverURL
        
        // Build optimized arguments
        var args = [
            "--model", modelPath,
            "--port", String(config.port),
            "--host", "127.0.0.1",
            "--threads", String(config.threads ?? SystemInfo.optimalThreadCount),
            "--ctx-size", String(config.contextSize),
            "--batch-size", String(config.batchSize),
            "--ubatch-size", String(config.ubatchSize),
            "--n-gpu-layers", String(config.gpuLayers),
            "--rope-scaling", "linear",
            "--rope-freq-scale", "1.0"
        ]
        
        // Add optional flags
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
        
        #if !DEBUG
        args.append("--log-disable")
        #endif
        
        process.arguments = args
        
        // Setup output handling
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // Monitor stderr for progress
        setupOutputMonitoring(errorPipe: errorPipe)
        
        // Launch process
        try process.run()
        self.serverProcess = process
        
        logger.info("Server process started with PID: \(process.processIdentifier)")
        
        // Start watchdog
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
            
            #if DEBUG
            print("llama-server: \(output)")
            #endif
        }
    }
    
    private func parseServerOutput(_ output: String) {
        // Parse loading progress
        if output.contains("loading model") {
            updateLoadingProgress(0.1, message: "Loading model...")
        } else if output.contains("loaded meta data") {
            updateLoadingProgress(0.2, message: "Processing metadata...")
        } else if output.contains("loading model tensors") {
            updateLoadingProgress(0.3, message: "Loading tensors...")
        } else if output.contains("offloading") && output.contains("layers to GPU") {
            updateLoadingProgress(0.5, message: "Offloading to GPU...")
        } else if output.contains("Metal_Mapped model buffer") {
            updateLoadingProgress(0.7, message: "Mapping GPU memory...")
        } else if output.contains("llama_kv_cache") {
            updateLoadingProgress(0.8, message: "Initializing cache...")
        } else if output.contains("model loaded") {
            updateLoadingProgress(0.95, message: "Finalizing...")
        } else if output.contains("server is listening") {
            updateLoadingProgress(1.0, message: "Server ready!")
        }
        
        // Detect errors
        if output.lowercased().contains("error") || output.contains("failed") {
            logger.error("Server error detected: \(output)")
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
            // Check health endpoint
            if await checkServerHealth() {
                // Test with actual request
                if await testServerCapability() {
                    return true
                }
            }
            
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
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
            return statusCode != 503 // 503 means still loading
        } catch {
            return false
        }
    }
    
    // MARK: - Watchdog & Recovery
    
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
                
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s
            }
        }
    }
    
    private func handleServerCrash() async {
        logger.error("Server crashed unexpectedly")
        serverStatus = .crashed
        serverHealth = .unhealthy
        
        crashCount += 1
        
        // Auto-restart if within retry limit
        if self.crashCount <= self.maxCrashRetries, let lastModelPath = config.lastModelPath {
            logger.info("Attempting auto-restart (\(self.crashCount)/\(self.maxCrashRetries))")
            
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s delay
            
            do {
                try await startServer(modelPath: lastModelPath)
            } catch {
                logger.error("Auto-restart failed: \(error)")
            }
        } else {
            logger.error("Max crash retries exceeded, giving up")
            serverStatus = .error("Server crashed too many times")
        }
    }
    
    // MARK: - Health Monitoring
    
    private func startHealthMonitoring() {
        healthMonitorTask?.cancel()
        
        healthMonitorTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self else { break }
                await self.performHealthCheck()
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30s
            }
        }
    }
    
    private func performHealthCheck() async {
        guard serverStatus == .ready else { return }
        
        let healthCheckStart = Date()
        let isHealthy = await checkServerHealth()
        let responseTime = Date().timeIntervalSince(healthCheckStart)
        
        // Update health status based on response time and availability
        if !isHealthy {
            serverHealth = .unhealthy
        } else if responseTime > 1.0 {
            serverHealth = .degraded
        } else {
            serverHealth = .healthy
        }
        
        // Log metrics
        if let startTime = serverStartTime {
            let uptime = Date().timeIntervalSince(startTime)
            logger.debug("Server health: \(String(describing: self.serverHealth)), uptime: \(uptime)s, response: \(responseTime)s")
        }
    }
    
    // MARK: - Utility Methods
    
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
        // Listen for app termination to cleanup
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: OperationQueue.main
        ) { [weak self] (notification: Notification) in
            Task {
                guard let self = self else { return }
                await self.cleanup()
            }
        }
        
        // Listen for system sleep/wake
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: OperationQueue.main
        ) { [weak self] (notification: Notification) in
            Task {
                guard let self = self else { return }
                await self.stopServer(reason: .systemSleep)
            }
        }
        
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: OperationQueue.main
        ) { [weak self] (notification: Notification) in
            Task {
                guard let strongSelf = self else { return }
                let config = strongSelf.config
                guard let modelPath = config.lastModelPath else { return }
                do {
                    try await strongSelf.startServer(modelPath: modelPath)
                } catch {
                    // Ignore wake-up restart errors
                }
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
        case insufficientMemory(required: UInt64, available: UInt64)
        case serverNotReady
        case requestEncodingFailed(String)
        case requestFailed(String)
        case invalidResponse
        case httpError(Int)
        case noData
        
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
            case .insufficientMemory(let required, let available):
                let reqGB = Double(required) / 1_073_741_824
                let availGB = Double(available) / 1_073_741_824
                return String(format: "Insufficient memory: %.1fGB required, %.1fGB available", reqGB, availGB)
            case .serverNotReady:
                return "Server is not ready for requests"
            case .requestEncodingFailed(let error):
                return "Failed to encode request: \(error)"
            case .requestFailed(let error):
                return "Request failed: \(error)"
            case .invalidResponse:
                return "Invalid response from server"
            case .httpError(let code):
                return "HTTP error: \(code)"
            case .noData:
                return "No data received from server"
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
        
        // Ensure directory exists
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
            .appendingPathComponent("ClientNote", isDirectory: true)
            .appendingPathComponent("LlamaServerConfig.json")
    }
}

// MARK: - System Information

struct SystemInfo {
    static var optimalThreadCount: Int {
        let cpuCount = ProcessInfo.processInfo.activeProcessorCount
        return max(1, cpuCount - 1) // Leave one core for system
    }
    
    static func getMemoryStatus() -> (total: UInt64, available: UInt64) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let total = ProcessInfo.processInfo.physicalMemory
            let pageSize = vm_kernel_page_size
            var vmStats = vm_statistics64()
            var vmStatsSize = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<natural_t>.size)
            
            let hostResult = withUnsafeMutablePointer(to: &vmStats) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(vmStatsSize)) {
                    host_statistics64(mach_host_self(),
                                    HOST_VM_INFO64,
                                    $0,
                                    &vmStatsSize)
                }
            }
            
            if hostResult == KERN_SUCCESS {
                let free = UInt64(vmStats.free_count) * UInt64(pageSize)
                let inactive = UInt64(vmStats.inactive_count) * UInt64(pageSize)
                let available = free + inactive
                return (total, available)
            }
        }
        
        return (ProcessInfo.processInfo.physicalMemory, ProcessInfo.processInfo.physicalMemory / 2)
    }
} 
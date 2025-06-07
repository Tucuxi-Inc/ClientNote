import SwiftUI
import AppKit

// MARK: - Main Server Control View
struct LlamaServerControlView: View {
    @StateObject private var serverManager = LlamaServerManager()
    @State private var selectedModelPath: String?
    @State private var showingModelPicker = false
    @State private var showingError = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Status Card
            ServerStatusCard(serverManager: serverManager)
            
            // Controls
            HStack(spacing: 12) {
                Button(action: selectModel) {
                    Label("Select Model", systemImage: "doc.fill")
                }
                .buttonStyle(.bordered)
                .disabled(serverManager.serverStatus.isTransitioning)
                
                if serverManager.serverStatus == .stopped {
                    Button(action: startServer) {
                        Label("Start Server", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedModelPath == nil)
                } else {
                    Button(action: stopServer) {
                        Label("Stop Server", systemImage: "stop.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            
            // Model Info
            if let modelPath = selectedModelPath {
                ModelInfoView(modelPath: modelPath)
            }
            
            // Error Display
            if let error = serverManager.lastError {
                ErrorBanner(error: error) {
                    serverManager.lastError = nil
                }
            }
        }
        .padding()
        .fileImporter(
            isPresented: $showingModelPicker,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                selectedModelPath = urls.first?.path
            case .failure(let error):
                serverManager.lastError = error
            }
        }
    }
    
    private func selectModel() {
        showingModelPicker = true
    }
    
    private func startServer() {
        guard let modelPath = selectedModelPath else { return }
        
        Task {
            do {
                try await serverManager.startServer(modelPath: modelPath)
            } catch {
                // Error will be displayed via @Published property
            }
        }
    }
    
    private func stopServer() {
        Task {
            await serverManager.stopServer()
        }
    }
}

// MARK: - Server Status Card
struct ServerStatusCard: View {
    @ObservedObject var serverManager: LlamaServerManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                StatusIndicator(status: serverManager.serverStatus)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(statusTitle)
                        .font(.headline)
                    
                    Text(statusDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if serverManager.serverHealth != .unknown {
                    HealthIndicator(health: serverManager.serverHealth)
                }
            }
            
            // Progress Bar
            if case .loadingModel(let progress) = serverManager.serverStatus {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                    
                    Text("\(Int(progress * 100))% complete")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.controlBackgroundColor)))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: 1)
        )
    }
    
    private var statusTitle: String {
        switch serverManager.serverStatus {
        case .stopped: return "Server Stopped"
        case .starting: return "Starting Server..."
        case .loadingModel: return "Loading Model..."
        case .ready: return "Server Ready"
        case .error(let message): return "Error: \(message)"
        case .crashed: return "Server Crashed"
        }
    }
    
    private var statusDescription: String {
        switch serverManager.serverStatus {
        case .stopped: return "Click Start Server to begin"
        case .starting: return "Initializing llama-server process"
        case .loadingModel(let progress): return loadingMessage(for: progress)
        case .ready: return "Server is running and ready for requests"
        case .error: return "Check the error message above"
        case .crashed: return "Server stopped unexpectedly"
        }
    }
    
    private func loadingMessage(for progress: Double) -> String {
        switch progress {
        case 0..<0.2: return "Reading model file..."
        case 0.2..<0.4: return "Processing model metadata..."
        case 0.4..<0.6: return "Loading model weights..."
        case 0.6..<0.8: return "Initializing GPU acceleration..."
        case 0.8..<1.0: return "Finalizing setup..."
        default: return "Almost ready..."
        }
    }
    
    private var borderColor: Color {
        switch serverManager.serverStatus {
        case .ready: return .green.opacity(0.5)
        case .error, .crashed: return .red.opacity(0.5)
        case .starting, .loadingModel: return .blue.opacity(0.5)
        case .stopped: return .gray.opacity(0.3)
        }
    }
}

// MARK: - Status Indicator
struct StatusIndicator: View {
    let status: LlamaServerManager.ServerStatus
    
    var body: some View {
        Circle()
            .fill(indicatorColor)
            .frame(width: 12, height: 12)
            .overlay(
                Circle()
                    .stroke(indicatorColor.opacity(0.3), lineWidth: 4)
                    .scaleEffect(status.isTransitioning ? 1.5 : 1.0)
                    .opacity(status.isTransitioning ? 0 : 1)
                    .animation(
                        status.isTransitioning ?
                            .easeInOut(duration: 1).repeatForever(autoreverses: false) : .default,
                        value: status
                    )
            )
    }
    
    private var indicatorColor: Color {
        switch status {
        case .stopped: return .gray
        case .starting, .loadingModel: return .blue
        case .ready: return .green
        case .error, .crashed: return .red
        }
    }
}

// MARK: - Health Indicator
struct HealthIndicator: View {
    let health: LlamaServerManager.ServerHealth
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .foregroundColor(healthColor)
                .font(.caption)
            
            Text(health.description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(healthColor.opacity(0.1))
        )
    }
    
    private var iconName: String {
        switch health {
        case .healthy: return "checkmark.circle.fill"
        case .degraded: return "exclamationmark.triangle.fill"
        case .unhealthy: return "xmark.circle.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }
    
    private var healthColor: Color {
        switch health {
        case .healthy: return .green
        case .degraded: return .orange
        case .unhealthy: return .red
        case .unknown: return .gray
        }
    }
}

// MARK: - Model Info View
struct ModelInfoView: View {
    let modelPath: String
    @State private var modelInfo: ModelInfo?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Selected Model", systemImage: "doc.text.fill")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(URL(fileURLWithPath: modelPath).lastPathComponent)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
            
            if let info = modelInfo {
                HStack(spacing: 16) {
                    Label("\(info.sizeString)", systemImage: "externaldrive.fill")
                    Label("\(info.quantization)", systemImage: "square.stack.3d.up.fill")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))
        .onAppear {
            loadModelInfo()
        }
    }
    
    private func loadModelInfo() {
        Task {
            modelInfo = await ModelInfo.load(from: modelPath)
        }
    }
}

// MARK: - Error Banner
struct ErrorBanner: View {
    let error: Error
    let onDismiss: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Error")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(2)
            }
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.red)
        )
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - Memory Status View
struct MemoryStatusView: View {
    @StateObject private var memoryMonitor = MemoryMonitor()
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(memoryMonitor.memoryPressure.color))
                .frame(width: 8, height: 8)
            
            Text("Memory: \(availableString) available")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var availableString: String {
        ByteCountFormatter.string(fromByteCount: Int64(memoryMonitor.availableMemory), countStyle: .memory)
    }
}

// MARK: - Server Status Button for Toolbar
struct ServerStatusButton: View {
    @ObservedObject var serverManager: LlamaServerManager
    @State private var showingServerControl = false
    
    var body: some View {
        Button(action: { showingServerControl.toggle() }) {
            HStack(spacing: 4) {
                StatusIndicator(status: serverManager.serverStatus)
                Text(serverManager.serverStatus.shortDescription)
                    .font(.caption)
            }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingServerControl) {
            LlamaServerControlView()
                .frame(width: 400, height: 300)
        }
    }
}

// MARK: - Model Info Helper

struct ModelInfo {
    let size: Int64
    let quantization: String
    
    var sizeString: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    static func load(from path: String) async -> ModelInfo? {
        await Task.detached {
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
                  let size = attributes[.size] as? Int64 else {
                return nil
            }
            
            // Parse quantization from filename
            let filename = URL(fileURLWithPath: path).lastPathComponent
            let quantization = parseQuantization(from: filename)
            
            return ModelInfo(size: size, quantization: quantization)
        }.value
    }
    
    private static func parseQuantization(from filename: String) -> String {
        let patterns = ["Q4_0", "Q4_1", "Q5_0", "Q5_1", "Q8_0", "F16", "F32"]
        
        for pattern in patterns {
            if filename.contains(pattern) {
                return pattern
            }
        }
        
        return "Unknown"
    }
}

// MARK: - Memory Monitor

class MemoryMonitor: ObservableObject {
    @Published var totalMemory: UInt64 = 0
    @Published var availableMemory: UInt64 = 0
    @Published var memoryPressure: MemoryPressure = .normal
    
    private var timer: Timer?
    
    enum MemoryPressure {
        case normal
        case warning
        case critical
        
        var color: NSColor {
            switch self {
            case .normal: return .systemGreen
            case .warning: return .systemOrange
            case .critical: return .systemRed
            }
        }
    }
    
    init() {
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    func startMonitoring() {
        updateMemoryStatus()
        
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            self.updateMemoryStatus()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateMemoryStatus() {
        let status = SystemInfo.getMemoryStatus()
        
        DispatchQueue.main.async {
            self.totalMemory = status.total
            self.availableMemory = status.available
            
            let percentUsed = Double(status.total - status.available) / Double(status.total)
            
            if percentUsed > 0.9 {
                self.memoryPressure = .critical
            } else if percentUsed > 0.75 {
                self.memoryPressure = .warning
            } else {
                self.memoryPressure = .normal
            }
        }
    }
    
    func canLoadModel(size: UInt64) -> Bool {
        // Require at least 2x model size in available memory
        return availableMemory > (size * 2)
    }
}

#Preview {
    LlamaServerControlView()
        .frame(width: 500, height: 400)
} 
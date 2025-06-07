import SwiftUI
import AppKit

struct LlamaServerPreferencesView: View {
    @AppStorage("llamaServerConfig") private var configData = Data()
    @State private var config = LlamaServerConfig.default
    @State private var hasChanges = false
    @State private var showingAdvanced = false
    
    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Server Settings") {
                    HStack {
                        Text("Port:")
                        Spacer()
                        TextField("Port", value: $config.port, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    
                    HStack {
                        Text("Context Size:")
                        Spacer()
                        TextField("Context", value: $config.contextSize, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                        Text("tokens")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    
                    HStack {
                        Text("Startup Timeout:")
                        Spacer()
                        TextField("Timeout", value: $config.startupTimeout, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                        Text("seconds")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                
                Section("GPU Acceleration") {
                    Toggle("Use Metal GPU", isOn: $config.useMetalGPU)
                    
                    HStack {
                        Text("GPU Layers:")
                        Spacer()
                        TextField("Layers", value: $config.gpuLayers, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                        Text("(999 = all)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .disabled(!config.useMetalGPU)
                    
                    Toggle("Enable Flash Attention", isOn: $config.flashAttention)
                        .disabled(!config.useMetalGPU)
                }
                
                Section("Performance") {
                    HStack {
                        Text("CPU Threads:")
                        Spacer()
                        
                        if let threads = config.threads {
                            Stepper(value: Binding(
                                get: { threads },
                                set: { config.threads = $0 }
                            ), in: 1...ProcessInfo.processInfo.activeProcessorCount) {
                                Text("\(threads)")
                                    .frame(width: 30, alignment: .trailing)
                            }
                        } else {
                            Button("Auto (\(SystemInfo.optimalThreadCount))") {
                                config.threads = SystemInfo.optimalThreadCount
                            }
                            .buttonStyle(.borderless)
                        }
                        
                        if config.threads != nil {
                            Button("Auto") {
                                config.threads = nil
                            }
                            .buttonStyle(.borderless)
                            .font(.caption)
                        }
                    }
                    
                    Toggle("Enable Warmup", isOn: $config.warmupEnabled)
                }
                
                DisclosureGroup("Advanced Settings", isExpanded: $showingAdvanced) {
                    HStack {
                        Text("Batch Size:")
                        Spacer()
                        TextField("Batch", value: $config.batchSize, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                    }
                    
                    HStack {
                        Text("Micro Batch Size:")
                        Spacer()
                        TextField("Ubatch", value: $config.ubatchSize, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                    }
                }
                
                Section("System Information") {
                    SystemInfoCard()
                }
            }
            .formStyle(.grouped)
            
            // Footer with buttons
            HStack {
                Button("Reset to Defaults") {
                    config = .default
                    hasChanges = true
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Cancel") {
                    loadConfig()
                    hasChanges = false
                }
                .keyboardShortcut(.escape)
                
                Button("Save") {
                    saveConfig()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(!hasChanges)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 500, height: 600)
        .onAppear {
            loadConfig()
        }
        .onChange(of: config) {
            hasChanges = true
        }
    }
    
    private func loadConfig() {
        if !configData.isEmpty,
           let decoded = try? JSONDecoder().decode(LlamaServerConfig.self, from: configData) {
            config = decoded
        } else {
            config = LlamaServerConfig.load()
        }
        hasChanges = false
    }
    
    private func saveConfig() {
        do {
            let encoder = JSONEncoder()
            configData = try encoder.encode(config)
            try config.save()
            hasChanges = false
        } catch {
            print("Failed to save config: \(error)")
        }
    }
}

// MARK: - System Info Card

struct SystemInfoCard: View {
    @StateObject private var memoryMonitor = MemoryMonitor()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("System Information", systemImage: "info.circle")
                    .font(.caption.bold())
                Spacer()
            }
            
            Divider()
            
            HStack {
                Text("CPU Cores:")
                Spacer()
                Text("\(ProcessInfo.processInfo.activeProcessorCount)")
                    .foregroundColor(.secondary)
            }
            .font(.caption)
            
            HStack {
                Text("Memory:")
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(memoryTotalString)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(memoryMonitor.memoryPressure.color))
                            .frame(width: 6, height: 6)
                        Text(memoryAvailableString)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .font(.caption)
            
            HStack {
                Text("Architecture:")
                Spacer()
                Text(systemArchitecture)
                    .foregroundColor(.secondary)
            }
            .font(.caption)
            
            HStack {
                Text("macOS:")
                Spacer()
                Text(macOSVersion)
                    .foregroundColor(.secondary)
            }
            .font(.caption)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
        )
    }
    
    private var memoryTotalString: String {
        ByteCountFormatter.string(fromByteCount: Int64(memoryMonitor.totalMemory), countStyle: .memory)
    }
    
    private var memoryAvailableString: String {
        let available = ByteCountFormatter.string(fromByteCount: Int64(memoryMonitor.availableMemory), countStyle: .memory)
        return "\(available) available"
    }
    
    private var systemArchitecture: String {
        #if arch(arm64)
        return "Apple Silicon (ARM64)"
        #elseif arch(x86_64)
        return "Intel (x86_64)"
        #else
        return "Unknown"
        #endif
    }
    
    private var macOSVersion: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }
}

// MARK: - Configuration Help

struct ConfigurationHelpView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Configuration Help")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                helpItem(title: "Context Size", description: "Maximum tokens the model can process at once. Larger values use more memory.")
                helpItem(title: "GPU Layers", description: "Number of model layers to run on GPU. Set to 999 for all layers.")
                helpItem(title: "Flash Attention", description: "Enables optimized attention mechanism for better performance on supported models.")
                helpItem(title: "CPU Threads", description: "Number of CPU threads to use. Auto-detect chooses optimal value based on your system.")
                helpItem(title: "Batch Size", description: "Number of tokens processed together. Higher values improve throughput but use more memory.")
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 400, height: 300)
    }
    
    private func helpItem(title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.bold())
            Text(description)
                .font(.caption2)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    LlamaServerPreferencesView()
} 
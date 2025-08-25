import Defaults
import SwiftUI
import SwiftData

struct GeneralView: View {
    @Default(.defaultHost) private var defaultHost
    @Default(.defaultSystemPrompt) private var defaultSystemPrompt
    @Default(.selectedAIBackend) private var selectedAIBackend

    
    @Environment(ChatViewModel.self) private var chatViewModel
    @Environment(AIBackendManager.self) private var aiBackendManager
    
    @State private var serviceManager = AIServiceManager.shared
    @State private var openAIKey = ""
    @State private var showingKeyEntry = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isUpdateOllamaHostPresented = false
    @State private var isUpdateSystemPromptPresented = false
    @State private var showingDataPrivacy = false
    @State private var isOllamaInstalled = false

    
    var body: some View {
        Form {
            // AI Backend Selection Section
            Section {
                Box {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("AI Backend")
                            .font(.headline.weight(.semibold))
                        
                        ForEach(AIBackend.allCases, id: \.self) { backend in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Image(systemName: selectedAIBackend == backend ? "largecircle.fill.circle" : "circle")
                                            .foregroundColor(selectedAIBackend == backend ? Color.euniPrimary : Color.secondary)
                                        
                                        Text(backend.displayName)
                                            .font(.body.weight(.medium))
                                        
                                        // Show status indicator
                                        if selectedAIBackend == backend {
                                            if let currentBackend = aiBackendManager.currentBackend {
                                                if currentBackend.isReady {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundColor(.green)
                                                } else {
                                                    Image(systemName: "exclamationmark.triangle.fill")
                                                        .foregroundColor(.orange)
                                                }
                                            }
                                        }
                                    }
                                    
                                    Text(backend.description)
                                        .font(.caption)
                                        .foregroundColor(Color.euniSecondary)
                                        .padding(.leading, 24)
                                    
                                    // Show backend status
                                    if selectedAIBackend == backend {
                                        if backend == .ollamaKit {
                                            // Special handling for Ollama
                                            if isOllamaInstalled {
                                                Text("Free (Local) ready")
                                                    .font(.caption)
                                                    .foregroundColor(.green)
                                                    .padding(.leading, 24)
                                            } else {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text("Requires installation of Ollama.")
                                                        .font(.caption)
                                                        .foregroundColor(.red)
                                                        .padding(.leading, 24)
                                                    
                                                    Link("Download Ollama at https://ollama.com/download", 
                                                         destination: URL(string: "https://ollama.com/download")!)
                                                        .font(.caption)
                                                        .foregroundColor(.blue)
                                                        .padding(.leading, 24)
                                                }
                                            }
                                        } else if let currentBackend = aiBackendManager.currentBackend {
                                            // Other backends
                                            Text(currentBackend.status)
                                                .font(.caption)
                                                .foregroundColor(currentBackend.isReady ? .green : .orange)
                                                .padding(.leading, 24)
                                        }
                                    }
                                }
                                
                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectBackend(backend)
                            }
                            .customTooltip("Select \(backend.displayName) as your AI backend", delay: 0.3)
                        }
                        

                    }
                }
            } footer: {
                SectionFooter("Choose between Free Local AI or OpenAI.")
                    .padding(.bottom)
                    .foregroundColor(Color.euniSecondary)
            }
            
            // OpenAI Configuration Section
            Section {
                Box {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("OpenAI Configuration")
                            .font(.headline.weight(.semibold))
                        
                        if serviceManager.availableServices.contains(.openAIUser) {
                            HStack {
                                Image(systemName: "key.fill")
                                    .foregroundColor(.green)
                                Text("API key configured")
                                    .foregroundColor(Color.euniText)
                                Spacer()
                                Button("Remove") {
                                    Task {
                                        try? serviceManager.removeUserOpenAIKey()
                                    }
                                }
                                .foregroundColor(Color.euniPrimary)
                                .customTooltip("Remove your OpenAI API key from secure storage", delay: 0.4)
                            }
                        } else {
                            HStack {
                                Text("Add your OpenAI API key to use non-local inference")
                                    .font(.subheadline)
                                    .foregroundColor(Color.euniSecondary)
                                Spacer()
                                Button("Add Key") {
                                    showingKeyEntry = true
                                }
                                .foregroundColor(Color.euniPrimary)
                                .customTooltip("Add your OpenAI API key for cloud-based AI inference", delay: 0.4)
                            }
                        }
                    }
                }
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    SectionFooter("Your API key is stored securely in the macOS Keychain.")
                        .foregroundColor(Color.euniSecondary)
                    
                    Button("More about Data Privacy") {
                        showingDataPrivacy = true
                    }
                    .foregroundColor(.blue)
                    .font(.caption)
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.bottom)
            }
            
            Section {
                Box {
                    Text("Default Ollama Host")
                        .font(.headline.weight(.semibold))
                    
                    HStack {
                        Text(defaultHost)
                            .customTooltip("Current Ollama host: \(defaultHost)", delay: 0.4)
                            .lineLimit(1)
                            .foregroundColor(Color.euniSecondary)
                        
                        Spacer()
                        
                        Button("Change", action: { isUpdateOllamaHostPresented = true })
                            .foregroundColor(Color.euniPrimary)
                            .customTooltip("Change the Ollama server host address", delay: 0.4)
                    }
                }
            } footer: {
                SectionFooter("This host will be used for OllamaKit backend and new chats.")
                    .padding(.bottom)
                    .foregroundColor(Color.euniSecondary)
            }
            
            Section {
                Box {
                    Text("Default System Prompt")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(Color.euniText)
                    
                    HStack {
                        Text(defaultSystemPrompt)
                            .customTooltip("Current system prompt: \(defaultSystemPrompt)", delay: 0.4)
                            .lineLimit(1)
                            .foregroundColor(Color.euniSecondary)
                        
                        Spacer()
                        
                        Button("Change", action: { isUpdateSystemPromptPresented = true })
                            .foregroundColor(Color.euniPrimary)
                            .customTooltip("Update the default system prompt for AI conversations", delay: 0.4)
                    }
                }
            } footer: {
                SectionFooter("This prompt will be used for new chats.")
                    .foregroundColor(Color.euniSecondary)
            }

            Section {
                Box {
                    DefaultFontSizeField()
                }
            }
        }
        .sheet(isPresented: $isUpdateOllamaHostPresented) {
            UpdateOllamaHostSheet(host: defaultHost) { host in
                self.defaultHost = host
                // Update the OllamaKit backend if it's currently selected
                if selectedAIBackend == .ollamaKit {
                    aiBackendManager.updateOllamaHost(host)
                    chatViewModel.updateAIBackend()
                }
            }
        }
        .sheet(isPresented: $isUpdateSystemPromptPresented) {
            UpdateSystemPromptSheet(prompt: defaultSystemPrompt) { prompt in
                self.defaultSystemPrompt = prompt
            }
        }
        .sheet(isPresented: $showingKeyEntry) {
            OpenAIKeyEntryView(apiKey: $openAIKey) { key in
                Task {
                    do {
                        try serviceManager.saveUserOpenAIKey(key)
                        showingKeyEntry = false
                    } catch {
                        errorMessage = error.localizedDescription
                        showingError = true
                    }
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showingDataPrivacy) {
            DataPrivacyView()
        }

        .onAppear {
            // Ensure the backend is initialized when the view appears
            chatViewModel.updateAIBackend()
            
            // Check Ollama installation status
            checkOllamaInstallation()
        }
        .task {
            await serviceManager.initialize()
        }
    }
    
    private func selectBackend(_ backend: AIBackend) {
        guard selectedAIBackend != backend else { return }
        
        selectedAIBackend = backend
        
        // Update the AI service type to keep Mode selector in sync
        let serviceType: AIServiceType = backend == .ollamaKit ? .ollama : .openAIUser
        Defaults[.selectedAIServiceType] = serviceType
        
        // Update the AI service manager
        Task {
            await serviceManager.selectService(serviceType)
        }
        
        chatViewModel.updateAIBackend()
    }
    
    private func checkOllamaInstallation() {
        Task {
            let ollamaService = OllamaService()
            let isInstalled = await ollamaService.isAvailable()
            await MainActor.run {
                isOllamaInstalled = isInstalled
                Defaults[.isOllamaInstalled] = isInstalled
            }
        }
    }

}

struct OpenAIKeyEntryView: View {
    @Binding var apiKey: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add OpenAI API Key")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Your API key is stored securely in the macOS Keychain")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            SecureField("sk-...", text: $apiKey)
                .textFieldStyle(.roundedBorder)
                .frame(width: 400)
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                
                Button("Save") {
                    onSave(apiKey)
                }
                .keyboardShortcut(.return)
                .disabled(apiKey.isEmpty || !apiKey.starts(with: "sk-"))
            }
        }
        .padding(30)
        .frame(width: 500)
    }
}

#Preview("General Settings") {
    let aiBackendManager = AIBackendManager.shared
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Chat.self, Message.self, configurations: config)
    let chatViewModel = ChatViewModel(modelContext: container.mainContext, aiBackendManager: aiBackendManager)
    
    GeneralView()
        .environment(aiBackendManager)
        .environment(chatViewModel)
        .frame(width: 512)
        .padding()
}

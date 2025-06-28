import Defaults
import SwiftUI
import SwiftData

struct GeneralView: View {
    @Default(.defaultHost) private var defaultHost
    @Default(.defaultSystemPrompt) private var defaultSystemPrompt
    @Default(.selectedAIBackend) private var selectedAIBackend

    
    @Environment(ChatViewModel.self) private var chatViewModel
    @Environment(AIBackendManager.self) private var aiBackendManager
    
    @State private var isUpdateOllamaHostPresented = false
    @State private var isUpdateSystemPromptPresented = false

    
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
                                    if selectedAIBackend == backend, let currentBackend = aiBackendManager.currentBackend {
                                        Text(currentBackend.status)
                                            .font(.caption)
                                            .foregroundColor(currentBackend.isReady ? .green : .orange)
                                            .padding(.leading, 24)
                                    }
                                }
                                
                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectBackend(backend)
                            }
                        }
                        

                    }
                }
            } footer: {
                SectionFooter("Choose between local LlamaKit inference or remote OllamaKit server.")
                    .padding(.bottom)
                    .foregroundColor(Color.euniSecondary)
            }
            
            Section {
                Box {
                    Text("Default Ollama Host")
                        .font(.headline.weight(.semibold))
                    
                    HStack {
                        Text(defaultHost)
                            .help(defaultHost)
                            .lineLimit(1)
                            .foregroundColor(Color.euniSecondary)
                        
                        Spacer()
                        
                        Button("Change", action: { isUpdateOllamaHostPresented = true })
                            .foregroundColor(Color.euniPrimary)
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
                            .help(defaultSystemPrompt)
                            .lineLimit(1)
                            .foregroundColor(Color.euniSecondary)
                        
                        Spacer()
                        
                        Button("Change", action: { isUpdateSystemPromptPresented = true })
                            .foregroundColor(Color.euniPrimary)
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

        .onAppear {
            // Ensure the backend is initialized when the view appears
            chatViewModel.updateAIBackend()
        }
    }
    
    private func selectBackend(_ backend: AIBackend) {
        guard selectedAIBackend != backend else { return }
        
        selectedAIBackend = backend
        chatViewModel.updateAIBackend()
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

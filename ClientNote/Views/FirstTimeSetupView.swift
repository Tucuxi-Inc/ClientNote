import SwiftUI
import Defaults

struct FirstTimeSetupView: View {
    @Binding var isPresented: Bool
    @State private var selectedService: AIServiceOption? = nil
    @State private var showingAPIKeyEntry = false
    @State private var apiKey = ""
    @State private var isValidatingAPIKey = false
    @State private var errorMessage: String?
    @Environment(ChatViewModel.self) private var chatViewModel
    
    enum AIServiceOption {
        case openAI
        case ollama
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                Image("1_Eunitm-Client-Notes-Effortless-AI-Powered-Therapy-Documentation")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 400, maxHeight: 200)
                
                Text("Welcome to Client Notes")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Choose how you'd like to power your AI assistant")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 40)
            
            // Service Options
            VStack(spacing: 20) {
                // OpenAI Option
                ServiceOptionCard(
                    title: "Use with Cloud Based AI",
                    subtitle: "Your Own OpenAI API Key",
                    icon: "cloud.fill",
                    isSelected: selectedService == .openAI,
                    features: [
                        "Powered by GPT-4.1 Nano",
                        "Fast and reliable",
                        "Cloud-based processing",
                        "No local setup required"
                    ]
                ) {
                    selectedService = .openAI
                }
                
                // Ollama Option
                ServiceOptionCard(
                    title: "Use with Ollama",
                    subtitle: "Free - Processes client data only on Your Computer",
                    icon: "desktopcomputer",
                    isSelected: selectedService == .ollama,
                    features: [
                        "100% free to use",
                        "Privacy-focused (local processing)",
                        "Multiple model options",
                        "Requires Ollama app installation"
                    ]
                ) {
                    selectedService = .ollama
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            // Continue Button
            Button(action: handleContinue) {
                Text("Continue")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selectedService != nil ? Color.euniPrimary : Color.gray)
                    .cornerRadius(10)
            }
            .disabled(selectedService == nil)
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .frame(width: 800, height: 700)
        .background(Color.euniBackground)
        .sheet(isPresented: $showingAPIKeyEntry) {
            APIKeyEntryView(
                apiKey: $apiKey,
                isValidating: $isValidatingAPIKey,
                errorMessage: $errorMessage,
                onCancel: {
                    showingAPIKeyEntry = false
                    selectedService = nil
                },
                onSubmit: validateAndSaveAPIKey
            )
        }
    }
    
    private func handleContinue() {
        switch selectedService {
        case .openAI:
            showOpenAIOptions()
        case .ollama:
            completeSetup(with: .ollama)
        case .none:
            break
        }
    }
    
    private func showOpenAIOptions() {
        // Go directly to API key entry in free version
        showingAPIKeyEntry = true
    }
    
    private func validateAndSaveAPIKey() {
        isValidatingAPIKey = true
        errorMessage = nil
        
        Task {
            do {
                // Test the API key
                let service = OpenAIService(apiKey: apiKey)
                _ = try await service.listModels()
                
                // Save the API key
                KeychainManager.shared.openAIAPIKey = apiKey
                
                await MainActor.run {
                    completeSetup(with: .openAIUser)
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Invalid API key. Please check and try again."
                    isValidatingAPIKey = false
                }
            }
        }
    }
    
    private func completeSetup(with serviceType: AIServiceType) {
        // Save the selected service
        Defaults[.selectedAIServiceType] = serviceType
        
        // Set the appropriate backend based on service type
        if serviceType == .openAIUser {
            Defaults[.selectedAIBackend] = .openAI
        } else {
            Defaults[.selectedAIBackend] = .ollamaKit
        }
        
        // Mark first launch as complete
        Defaults[.defaultHasLaunched] = true
        
        // Initialize the service
        Task {
            await AIServiceManager.shared.selectService(serviceType)
            
            // Create initial chat
            await MainActor.run {
                if serviceType == .ollama {
                    // For Ollama, we'll need to check if models are available
                    chatViewModel.fetchModelsFromBackend()
                } else {
                    // For OpenAI, create chat with gpt-4.1-nano
                    chatViewModel.create(model: "gpt-4.1-nano")
                }
                
                // Dismiss the setup view
                isPresented = false
            }
        }
    }
}

struct ServiceOptionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let isSelected: Bool
    let features: [String]
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 20) {
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundColor(isSelected ? .white : .euniPrimary)
                    .frame(width: 60)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(isSelected ? .white : .primary)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    
                    HStack(spacing: 16) {
                        ForEach(features, id: \.self) { feature in
                            Label(feature, systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
                        }
                    }
                    .padding(.top, 4)
                }
                
                Spacer()
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.euniPrimary : Color.gray.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.euniPrimary : Color.gray.opacity(0.3), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct APIKeyEntryView: View {
    @Binding var apiKey: String
    @Binding var isValidating: Bool
    @Binding var errorMessage: String?
    let onCancel: () -> Void
    let onSubmit: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Enter Your OpenAI API Key")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Your API key will be securely stored in your Mac's keychain")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                SecureField("API Key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isValidating)
                
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    onCancel()
                }
                .disabled(isValidating)
                
                Button("Validate & Save") {
                    onSubmit()
                }
                .buttonStyle(.borderedProminent)
                .disabled(apiKey.isEmpty || isValidating)
                
                if isValidating {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            Link("Get an API key from OpenAI", 
                 destination: URL(string: "https://platform.openai.com/api-keys")!)
                .font(.caption)
        }
        .padding(30)
        .frame(width: 500)
    }
}

#Preview {
    FirstTimeSetupView(isPresented: .constant(true))
        // Preview placeholder - requires proper initialization
} 
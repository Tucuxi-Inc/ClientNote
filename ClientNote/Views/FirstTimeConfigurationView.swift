//
//  FirstTimeConfigurationView.swift
//  ClientNote
//
//  First-time AI configuration setup view
//

import SwiftUI
import Defaults

struct FirstTimeConfigurationView: View {
    let onConfigurationComplete: () -> Void
    
    @State private var selectedMode: AIBackend = .ollamaKit
    @State private var serviceManager = AIServiceManager.shared
    @State private var openAIKey = ""
    @State private var showingKeyEntry = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingUnconfiguredWarning = false
    @State private var isOllamaInstalled = false
    
    var body: some View {
        VStack(spacing: 30) {
            // Header
            VStack(spacing: 16) {
                Text("Configure Your AI")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(Color.euniText)
                
                Text("Choose how you'd like Euni Client Notes to process your therapy sessions")
                    .font(.body)
                    .foregroundColor(Color.euniSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
            
            // AI Mode Selection
            VStack(spacing: 20) {
                // Free Local AI Option
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Button(action: {
                            selectedMode = .ollamaKit
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: selectedMode == .ollamaKit ? "largecircle.fill.circle" : "circle")
                                    .foregroundColor(selectedMode == .ollamaKit ? Color.euniPrimary : Color.secondary)
                                    .font(.title2)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Use Free Local AI")
                                        .font(.headline)
                                        .foregroundColor(Color.euniText)
                                    
                                    if isOllamaInstalled {
                                        Text("Free (Local) ready")
                                            .font(.subheadline)
                                            .foregroundColor(.green)
                                    } else {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Requires installation of Ollama.")
                                                .font(.subheadline)
                                                .foregroundColor(.red)
                                            
                                            Link("Download Ollama at https://ollama.com/download", 
                                                 destination: URL(string: "https://ollama.com/download")!)
                                                .font(.subheadline)
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                                
                                Spacer()
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(selectedMode == .ollamaKit ? Color.euniPrimary : Color.secondary.opacity(0.3), lineWidth: 2)
                    )
                }
                
                // OpenAI Option
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Button(action: {
                            selectedMode = .openAI
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: selectedMode == .openAI ? "largecircle.fill.circle" : "circle")
                                    .foregroundColor(selectedMode == .openAI ? Color.euniPrimary : Color.secondary)
                                    .font(.title2)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Use your OpenAI API Key")
                                        .font(.headline)
                                        .foregroundColor(Color.euniText)
                                }
                                
                                Spacer()
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(selectedMode == .openAI ? Color.euniPrimary : Color.secondary.opacity(0.3), lineWidth: 2)
                    )
                    
                    // OpenAI Configuration (when selected)
                    if selectedMode == .openAI {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("OpenAI Configuration")
                                .font(.headline.weight(.semibold))
                                .padding(.top, 8)
                            
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
                                }
                            }
                            
                            Text("Your API key is stored securely in the macOS Keychain.")
                                .font(.caption)
                                .foregroundColor(Color.euniSecondary)
                        }
                        .padding(16)
                        .background(Color.euniBackground.opacity(0.5))
                        .cornerRadius(8)
                    }
                }
            }
            
            Spacer()
            
            // Continue Button
            Button(action: {
                handleContinue()
            }) {
                Text("Continue")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 12)
                    .background(Color.euniPrimary)
                    .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.euniBackground)
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
        .alert("Application Not Configured", isPresented: $showingUnconfiguredWarning) {
            Button("OK") {
                // Allow user to continue anyway
                completeConfiguration()
            }
        } message: {
            Text("Application not configured and will not generate notes until configured - go to \"ClientNote --> Settings\" to configure for OpenAI use by saving your OpenAI Developer API Key or install Ollama and then download and install an AI model using the controls in the right side-panel of the application.")
        }
        .onAppear {
            checkOllamaInstallation()
        }
        .task {
            await serviceManager.initialize()
        }
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
    
    private func handleContinue() {
        // Check if system is properly configured
        let hasOllama = isOllamaInstalled
        let hasOpenAIKey = serviceManager.availableServices.contains(.openAIUser)
        
        if !hasOllama && !hasOpenAIKey {
            // Show warning but allow to continue
            showingUnconfiguredWarning = true
        } else {
            // System is configured, proceed
            completeConfiguration()
        }
    }
    
    private func completeConfiguration() {
        // Set the selected backend
        Defaults[.selectedAIBackend] = selectedMode
        
        // Set service type based on selection and availability
        let serviceType: AIServiceType
        if selectedMode == .openAI && serviceManager.availableServices.contains(.openAIUser) {
            serviceType = .openAIUser
        } else {
            serviceType = .ollama
        }
        
        Defaults[.selectedAIServiceType] = serviceType
        
        // Update AI service
        Task {
            await serviceManager.selectService(serviceType)
        }
        
        // Mark first launch as complete
        Defaults[.defaultHasLaunched] = true
        
        // Complete configuration
        onConfigurationComplete()
    }
}


#Preview {
    FirstTimeConfigurationView {
        print("Configuration complete")
    }
}
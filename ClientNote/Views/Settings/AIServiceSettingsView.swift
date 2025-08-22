//
//  AIServiceSettingsView.swift
//  ClientNote
//
//  Settings for configuring AI services
//

import SwiftUI
import Defaults

struct AIServiceSettingsView: View {
    @State private var serviceManager = AIServiceManager.shared
    @State private var openAIKey = ""
    @State private var showingKeyEntry = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("AI Service Configuration")
                .font(.title2)
                .fontWeight(.semibold)
            
            // Service Status
            HStack {
                Image(systemName: serviceManager.isConfigured ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundColor(serviceManager.isConfigured ? .green : .orange)
                Text(serviceManager.status)
                    .font(.subheadline)
            }
            .padding(.bottom, 10)
            
            // Available Services
            GroupBox("Available Services") {
                VStack(alignment: .leading, spacing: 15) {
                    ForEach(AIServiceType.allCases, id: \.self) { serviceType in
                        ServiceRow(
                            serviceType: serviceType,
                            isAvailable: serviceManager.availableServices.contains(serviceType),
                            isSelected: serviceManager.currentService?.serviceType == serviceType,
                            onSelect: {
                                Task {
                                    await serviceManager.selectService(serviceType)
                                }
                            }
                        )
                    }
                }
                .padding(.vertical, 5)
            }
            
            // OpenAI API Key Management
            GroupBox("OpenAI Configuration") {
                VStack(alignment: .leading, spacing: 10) {
                    if serviceManager.availableServices.contains(.openAIUser) {
                        HStack {
                            Image(systemName: "key.fill")
                                .foregroundColor(.green)
                            Text("API key configured")
                            Spacer()
                            Button("Remove") {
                                Task {
                                    try? serviceManager.removeUserOpenAIKey()
                                }
                            }
                            .buttonStyle(.link)
                        }
                    } else {
                        HStack {
                            Text("Add your OpenAI API key to use non-local inference")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("Add Key") {
                                showingKeyEntry = true
                            }
                        }
                    }
                    
                    if serviceManager.availableServices.contains(.openAISubscription) {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Text("Euni purchase or active subscription - non-local inference available")
                                .font(.subheadline)
                        }
                    }
                }
                .padding(.vertical, 5)
            }
            
            // Ollama Status
            GroupBox("Ollama Status") {
                VStack(alignment: .leading, spacing: 10) {
                    if serviceManager.availableServices.contains(.ollama) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Ollama is running")
                            Spacer()
                            Link("Manage Models", destination: URL(string: "http://localhost:11434")!)
                                .font(.subheadline)
                        }
                    } else {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text("Ollama not detected")
                            Spacer()
                            Link("Download Ollama", destination: URL(string: "https://ollama.com/download")!)
                                .font(.subheadline)
                        }
                        
                        Text("Install Ollama to use local AI models on your Mac")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 5)
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 600, height: 500)
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
        .task {
            await serviceManager.initialize()
        }
    }
}

struct ServiceRow: View {
    let serviceType: AIServiceType
    let isAvailable: Bool
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: serviceType.icon)
                .foregroundColor(isAvailable ? .accentColor : .secondary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(serviceType.rawValue)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                Text(serviceType.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isAvailable {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                } else {
                    Button("Select") {
                        onSelect()
                    }
                    .buttonStyle(.link)
                }
            } else {
                Text(serviceType.requiresSubscription ? "Purchase or Subscription Required" : "No OpenAI Key Detected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .onTapGesture {
            if isAvailable && !isSelected {
                onSelect()
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

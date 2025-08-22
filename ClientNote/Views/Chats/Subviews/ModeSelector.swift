//
//  ModeSelector.swift
//  ClientNote
//
//  AI Mode picker dropdown with info button
//

import SwiftUI
import Defaults
import Combine

struct ModeSelector: View {
    @State private var aiServiceManager = AIServiceManager.shared
    @State private var showingInfoPopover = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Mode label with info button
            HStack(spacing: 4) {
                Text("Mode")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.euniSecondary)
                
                Button(action: {
                    showingInfoPopover = true
                }) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Show mode information")
                .popover(isPresented: $showingInfoPopover) {
                    ModeInfoPopover()
                }
            }
            
            // Mode picker
            Picker("", selection: Binding(
                get: { currentServiceType },
                set: { newServiceType in
                    Task {
                        await switchToMode(newServiceType)
                    }
                }
            )) {
                Text("Free")
                    .tag(AIServiceType.ollama)
                
                Text("OpenAI")
                    .tag(AIServiceType.openAIUser)
            }
            .pickerStyle(MenuPickerStyle())
            .frame(width: 100)
        }
    }
    
    private var currentServiceType: AIServiceType {
        return aiServiceManager.currentService?.serviceType ?? .ollama
    }
    
    private func switchToMode(_ serviceType: AIServiceType) async {
        // Switch the AI backend setting
        switch serviceType {
        case .ollama:
            Defaults[.selectedAIBackend] = .ollamaKit
        case .openAIUser:
            Defaults[.selectedAIBackend] = .openAI
        }
        
        // Update the AI service type (this is what the Assistant picker checks)
        Defaults[.selectedAIServiceType] = serviceType
        
        // Update the AI service
        await aiServiceManager.selectService(serviceType)
    }
}

struct ModeInfo: Equatable {
    let type: AIServiceType
    let displayName: String
    let icon: Image
    let color: Color
    let description: String
    let details: String
    
    static func == (lhs: ModeInfo, rhs: ModeInfo) -> Bool {
        lhs.type == rhs.type
    }
    
    static let free = ModeInfo(
        type: .ollama,
        displayName: "Free and Local Mode",
        icon: Image(systemName: "desktopcomputer"),
        color: .green,
        description: "Local AI Processing",
        details: "Install Ollama (free) and then choose and download a model (\"assistant\") in the right side panel. Free mode runs completely on your MacOS device. Your client data and notes are processed on and stay on your computer."
    )
    
    static let byoOpenAI = ModeInfo(
        type: .openAIUser,
        displayName: "Your OpenAI Account",
        icon: Image(systemName: "key.fill"),
        color: .blue,
        description: "Your OpenAI API Key",
        details: "Use your own OpenAI API Key (requires developer account and developer subscription and you may have additional usage costs). This mode will also utilize a cloud based model from OpenAI to generate your notes. Audio recordings remain on your device, but transcriptions and client data is sent securely to OpenAI for processing prompts and generating treatment plans, notes, etc. Data will be processed, retained and shared pursuant to your agreement with OpenAI. See \"Data Privacy\" for more details."
    )
}

struct ModeInfoPopover: View {
    @State private var showingDataPrivacy = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI Mode Information")
                .font(.title3)
                .fontWeight(.semibold)
            
            // Free Mode
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "desktopcomputer")
                        .foregroundColor(.green)
                        .font(.title3)
                    
                    Text("Free")
                        .font(.body)
                        .fontWeight(.semibold)
                }
                
                Text("Install Ollama (free) and then choose and download a model (\"assistant\") in the right side panel. Free mode runs completely on your MacOS device. Your client data and notes are processed on and stay on your computer.")
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Divider()
            
            // OpenAI Mode
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "key.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                    
                    Text("OpenAI")
                        .font(.body)
                        .fontWeight(.semibold)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Use your own OpenAI API Key (requires developer account and developer subscription and you may have additional usage costs). This mode will also utilize a cloud based model from OpenAI to generate your notes. Audio recordings remain on your device, but transcriptions and client data is sent securely to OpenAI for processing prompts and generating treatment plans, notes, etc. Data will be processed, retained and shared pursuant to your agreement with OpenAI.")
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Button("See Data Privacy for more details") {
                        showingDataPrivacy = true
                    }
                    .foregroundColor(.blue)
                    .font(.caption)
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(20)
        .frame(width: 350)
        .sheet(isPresented: $showingDataPrivacy) {
            DataPrivacyView()
        }
    }
}

#Preview {
    ModeSelector()
        .padding()
}

//
//  ModeSelector.swift
//  ClientNote
//
//  Simple mode display button that opens settings
//

import SwiftUI
import Defaults
import Combine

struct ModeSelector: View {
    private let aiServiceManager = AIServiceManager.shared
    private let iapManager = IAPManager.shared
    @State private var showingSettings = false
    
    var body: some View {
        Button(action: {
            showingSettings = true
        }) {
            HStack(spacing: 6) {
                currentMode.icon
                    .foregroundColor(currentMode.color)
                    .font(.system(size: 14))
                
                Text(currentMode.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .help("Change AI mode - tap to open settings")
        .sheet(isPresented: $showingSettings) {
            NavigationView {
                AIServiceSettingsView()
                    .navigationTitle("AI Service Settings")
            }
            .frame(width: 580, height: 600)
        }
    }
    
    private var currentMode: ModeInfo {
        guard let serviceType = aiServiceManager.currentService?.serviceType else {
            return .free
        }
        
        switch serviceType {
        case .openAISubscription:
            return .subscription
        case .openAIUser:
            return .byoOpenAI
        case .ollama:
            return .free
        }
    }
}

struct ModeInfo {
    let type: AIServiceType
    let displayName: String
    let icon: Image
    let color: Color
    let description: String
    let details: String
    
    static let free = ModeInfo(
        type: .ollama,
        displayName: "Free",
        icon: Image(systemName: "desktopcomputer"),
        color: .green,
        description: "Local AI Processing",
        details: "Install Ollama (free) and then choose and download a model (\"assistant\") in the right side panel. Free mode runs completely on your MacOS device. Your client data and notes are processed on and stay on your computer."
    )
    
    static let subscription = ModeInfo(
        type: .openAISubscription,
        displayName: "Euni Subscription or Purchase",
        icon: Image(systemName: "crown.fill"),
        color: .purple,
        description: "Cloud AI with Subscription or Purchase",
        details: "With a subscription or one-time purchase, you can also use a cloud based model from OpenAI to generate your notes. Audio recordings remain on your device, but transcriptions and client data is sent securely to OpenAI for processing prompts and generating treatment plans, notes, etc. See \"Data Privacy\" for more details."
    )
    
    static let byoOpenAI = ModeInfo(
        type: .openAIUser,
        displayName: "OpenAI Account",
        icon: Image(systemName: "key.fill"),
        color: .blue,
        description: "Your OpenAI API Key",
        details: "Use your own OpenAI API Key (requires developer account and developer subscription and you may have additional usage costs). This mode will also utilize a cloud based model from OpenAI to generate your notes. Audio recordings remain on your device, but transcriptions and client data is sent securely to OpenAI for processing prompts and generating treatment plans, notes, etc. Data will be processed, retained and shared pursuant to your agreement with OpenAI. See \"Data Privacy\" for more details."
    )
}

struct ModeInfoPopover: View {
    let mode: ModeInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                mode.icon
                    .foregroundColor(mode.color)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.displayName)
                        .font(.headline)
                    Text(mode.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Text(mode.details)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
            
            Button("Close") {
                // Popover will close automatically
            }
            .keyboardShortcut(.escape)
        }
        .padding(16)
        .frame(maxWidth: 400)
    }
}

#Preview {
    ModeSelector()
        .padding()
}

//
//  ClientNoteApp.swift
//  ClientNote
//
//  Created by Kevin Hermawan on 03/11/23.
//

import Defaults
import AppInfo
import SwiftUI
import SwiftData
import OllamaKit
import UserNotifications

@main
struct ClientNoteApp: App {
    @State private var appUpdater: AppUpdater
    @State private var showSplashScreen = true
    @State private var showTermsAndPrivacy = false
    @State private var showFirstTimeConfiguration = false
    
    @State private var chatViewModel: ChatViewModel
    @State private var messageViewModel: MessageViewModel
    @State private var codeHighlighter: CodeHighlighter
    @State private var aiBackendManager: AIBackendManager

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Chat.self, Message.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    init() {
        let modelContext = sharedModelContainer.mainContext
        
        // Initialize AppUpdater without Sparkle
        let appUpdater = AppUpdater()
        self._appUpdater = State(initialValue: appUpdater)
        
        // Use shared AI Backend Manager (singleton)
        let aiBackendManager = AIBackendManager.shared
        self._aiBackendManager = State(initialValue: aiBackendManager)
        
        // Create view models with circular references
        let chatViewModel = ChatViewModel(modelContext: modelContext, aiBackendManager: aiBackendManager)
        let messageViewModel = MessageViewModel(modelContext: modelContext, chatViewModel: chatViewModel)
        chatViewModel.setMessageViewModel(messageViewModel)
        
        self._chatViewModel = State(initialValue: chatViewModel)
        self._messageViewModel = State(initialValue: messageViewModel)

        // Always use light mode for code highlighting
        let codeHighlighter = CodeHighlighter(colorScheme: .light, fontSize: Defaults[.fontSize], enabled: Defaults[.experimentalCodeHighlighting])
        _codeHighlighter = State(initialValue: codeHighlighter)

        // Backend initialization is handled automatically by singleton
        // No need for manual initialization here

        // Only create initial chat if not first launch
        if Defaults[.defaultHasLaunched] {
            chatViewModel.create(model: Defaults[.defaultModel])
            if let activeChat = chatViewModel.selectedChats.first {
                chatViewModel.activeChat = activeChat
                messageViewModel.load(of: activeChat)
            }
        }

        // StoreKit code removed for free version
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                // Main app view - only show if everything is complete
                if !showSplashScreen && !showTermsAndPrivacy && !showFirstTimeConfiguration && 
                   Defaults[.hasAcceptedTermsAndPrivacy] && Defaults[.defaultHasLaunched] {
                    AccessControlView {
                        AppView()
                            .environment(chatViewModel)
                            .environment(messageViewModel)
                            .environment(codeHighlighter)
                            .environment(aiBackendManager)
                    }
                    .preferredColorScheme(ColorScheme.light)
                } else if showFirstTimeConfiguration {
                    // Show first-time configuration
                    FirstTimeConfigurationView {
                        showFirstTimeConfiguration = false
                    }
                    .transition(.opacity)
                    .zIndex(2)
                    .preferredColorScheme(ColorScheme.light)
                } else if !Defaults[.hasAcceptedTermsAndPrivacy] && !showSplashScreen {
                    // Show terms and privacy if not accepted and splash is done
                    TermsAndPrivacyView {
                        // When user accepts terms, check if we need configuration
                        showTermsAndPrivacy = false
                        if !Defaults[.defaultHasLaunched] {
                            showFirstTimeConfiguration = true
                        }
                    }
                    .transition(.opacity)
                    .zIndex(2)
                    .preferredColorScheme(ColorScheme.light)
                } else {
                    // Show a blocking view if terms not accepted
                    Color.euniBackground
                        .ignoresSafeArea()
                }
                
                if showSplashScreen {
                    SimpleSplashScreen(isPresented: $showSplashScreen, onSplashComplete: {
                        // After splash, check what to show next
                        if !Defaults[.hasAcceptedTermsAndPrivacy] {
                            showTermsAndPrivacy = true
                        } else if !Defaults[.defaultHasLaunched] {
                            showFirstTimeConfiguration = true
                        }
                    })
                        .environment(chatViewModel)
                        .environment(messageViewModel)
                        .environment(aiBackendManager)
                        .transition(.opacity)
                        .zIndex(3)
                        .preferredColorScheme(ColorScheme.light)
                }
            }
        }
        .modelContainer(sharedModelContainer)
        .keyboardShortcut(KeyboardShortcut("n", modifiers: [.command, .shift]))
        .commands {
            CommandGroup(replacing: .textEditing) {
                if chatViewModel.selectedChats.count > 0 {
                    SidebarContextMenu(chatViewModel: chatViewModel)
                }
            }
            
            CommandGroup(after: .appInfo) {
                // For Mac App Store, updates are handled automatically
                // This button is kept as a placeholder but will be disabled
                Button("Check for Updates...") {
                    // No action needed for Mac App Store
                }
                .disabled(true)
            }
            
            CommandGroup(replacing: .help) {
                if let helpURL = AppInfo.value(for: "HELP_URL"), let url = URL(string: helpURL) {
                    Link("ClientNote Help", destination: url)
                }
                
                Divider()
                
                // Required by Apple for subscription apps
                Link("Terms of Use", destination: URL(string: "https://bit.ly/TucuxiTermsoUse")!)
                
                Link("Privacy Policy", destination: URL(string: "https://bit.ly/TucuxiPrivacyPolicy")!)
            }

            CommandGroup(after: .textEditing) {
                Divider()
                Button("Increase font size", action: increaseFontSize)
                    .keyboardShortcut("+", modifiers: [.command], localization: .custom)

                Button("Decrease font size", action: decreaseFontSize)
                    .keyboardShortcut("-", modifiers: [.command], localization: .custom)
            }
        }
        
        Settings {
            SettingsView()
                .environment(chatViewModel)
                .environment(messageViewModel)
                .environment(codeHighlighter)
                .environment(aiBackendManager)
                .preferredColorScheme(.light)
        }
    }
    
    private func increaseFontSize() {
        let currentSize = Defaults[.fontSize]
        Defaults[.fontSize] = min(currentSize + 1, 24)
        codeHighlighter.fontSize = Defaults[.fontSize]
    }
    
    private func decreaseFontSize() {
        let currentSize = Defaults[.fontSize]
        Defaults[.fontSize] = max(currentSize - 1, 8)
        codeHighlighter.fontSize = Defaults[.fontSize]
    }
}

// Simple splash screen view
struct SimpleSplashScreen: View {
    @Binding var isPresented: Bool
    let onSplashComplete: () -> Void
    @Environment(ChatViewModel.self) private var chatViewModel
    @Environment(MessageViewModel.self) private var messageViewModel
    @Environment(AIBackendManager.self) private var aiBackendManager
    @State private var showingFirstTimeSetup = false
    @State private var isCheckingSetup = true
    @State private var currentImageIndex: Int = 0
    @State private var isShowingImageCycle: Bool = false
    
    private let splashImages = [
        "1_Eunitm-Client-Notes-Effortless-AI-Powered-Therapy-Documentation",
        "2_Rethink-Your-Clinical-Documentation",
        "3_Key-Features", 
        "4_Built-for-Clinicians-Who-Value-Control",
        "5_How-It-Works"
    ]
    
    init(isPresented: Binding<Bool>, onSplashComplete: @escaping () -> Void) {
        self._isPresented = isPresented
        self.onSplashComplete = onSplashComplete
    }
    
    var body: some View {
        ZStack {
            Color.euniBackground
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Display current image with transition
                Image(splashImages[currentImageIndex])
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 800, maxHeight: 800)
                    .transition(.opacity)
                    .id(currentImageIndex) // Force view update on index change
                
                if isCheckingSetup {
                    ProgressView("Loading...")
                        .progressViewStyle(.circular)
                } else if isShowingImageCycle {
                    VStack(spacing: 8) {
                        ProgressView("Starting up...")
                            .progressViewStyle(.circular)
                    }
                }
            }
            .padding()
        }
        .onAppear {
            checkFirstTimeSetup()
        }
        .sheet(isPresented: $showingFirstTimeSetup) {
            FirstTimeSetupView(isPresented: $showingFirstTimeSetup)
                .environment(chatViewModel)
                .interactiveDismissDisabled()
                .onDisappear {
                    // After setup is complete, start the image cycle
                    startImageCycleAndDismiss()
                }
        }
    }
    
    private func checkFirstTimeSetup() {
        isCheckingSetup = true
        
        Task {
            await MainActor.run {
                isCheckingSetup = false
                
                // Check if this is first launch
                if !Defaults[.defaultHasLaunched] {
                    showingFirstTimeSetup = true
                } else {
                    // Not first launch, start image cycle and dismiss
                    startImageCycleAndDismiss()
                }
            }
        }
    }
    
    private func startImageCycleAndDismiss() {
        isShowingImageCycle = true
        currentImageIndex = 0
        
        // Cycle through all 5 images with reasonable timing
        Task {
            for index in 0..<splashImages.count {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        currentImageIndex = index
                    }
                }
                
                // Wait 1.5 seconds between images (quick but readable)
                try? await Task.sleep(nanoseconds: 1_500_000_000)
            }
            
            // Dismiss after cycling through all images
            await MainActor.run {
                dismissSplashScreen()
            }
        }
    }
    
    private func dismissSplashScreen() {
        withAnimation(.easeOut(duration: 0.3)) {
            isPresented = false
        }
        // Call completion handler after splash is dismissed
        onSplashComplete()
    }
}

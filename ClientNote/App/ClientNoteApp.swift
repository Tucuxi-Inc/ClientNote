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
import StoreKit
import OllamaKit
import UserNotifications

@main
struct ClientNoteApp: App {
    @State private var appUpdater: AppUpdater
    @State private var showSplashScreen = true
    
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

        /*
        #if DEBUG
        // Set up StoreKit test environment programmatically
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" {
            Task {
                // Ensure we have the StoreKit configuration file loaded
                print("Setting up StoreKit test environment")
                
                // Force load products from the StoreKit configuration file
                let productIDs = ["ai.tucuxi.ClientNote.7DayTrial", "ai.tucuxi.ClientNote.fullUnlock"]
                print("Loading products with IDs: \(productIDs)")
                
                do {
                    let products = try await Product.products(for: productIDs)
                    print("Successfully loaded \(products.count) products:")
                    for product in products {
                        print("- \(product.id): \(product.displayName), price: \(product.displayPrice)")
                    }
                    
                    // Force a sync with App Store to ensure connection is working
                    print("Syncing with App Store...")
                    try await AppStore.sync()
                    print("App Store sync complete")
                } catch {
                    print("Error loading products: \(error)")
                }
                
                // Clear existing transactions for fresh testing
                if let result = await StoreKit.Transaction.latest(for: "ai.tucuxi.ClientNote.7DayTrial") {
                    if case .verified(let transaction) = result {
                        await transaction.finish()
                    }
                }
                
                if let result = await StoreKit.Transaction.latest(for: "ai.tucuxi.ClientNote.fullUnlock") {
                    if case .verified(let transaction) = result {
                        await transaction.finish()
                    }
                }
            }
        }
        #endif
        */
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                AccessControlView {
                    AppView()
                        .environment(chatViewModel)
                        .environment(messageViewModel)
                        .environment(codeHighlighter)
                        .environment(aiBackendManager)
                }
                .preferredColorScheme(ColorScheme.light)
                
                if showSplashScreen {
                    SimpleSplashScreen(isPresented: $showSplashScreen)
                        .environment(chatViewModel)
                        .environment(messageViewModel)
                        .environment(aiBackendManager)
                        .transition(.opacity)
                        .zIndex(1)
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
    
    init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
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
    }
}

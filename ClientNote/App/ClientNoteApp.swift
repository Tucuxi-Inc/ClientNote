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
        
        let chatViewModel = ChatViewModel(modelContext: modelContext)
        self._chatViewModel = State(initialValue: chatViewModel)
        
        let messageViewModel = MessageViewModel(modelContext: modelContext)
        self._messageViewModel = State(initialValue: messageViewModel)

        // Always use light mode for code highlighting
        let codeHighlighter = CodeHighlighter(colorScheme: .light, fontSize: Defaults[.fontSize], enabled: Defaults[.experimentalCodeHighlighting])
        _codeHighlighter = State(initialValue: codeHighlighter)

        chatViewModel.create(model: Defaults[.defaultModel])
        guard let activeChat = chatViewModel.selectedChats
            .first else { return }
        
        chatViewModel.activeChat = activeChat
        messageViewModel.load(of: activeChat)

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
                }
                .preferredColorScheme(ColorScheme.light)
                
                if showSplashScreen {
                    SimpleSplashScreen(isPresented: $showSplashScreen)
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
    @State private var isFirstLaunch = !UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
    
    // Regular launch image
    private let logoImage = "1_Eunitm-Client-Notes-Effortless-AI-Powered-Therapy-Documentation"
    
    var body: some View {
        ZStack {
            Color.euniBackground
                .ignoresSafeArea()
            
            if isFirstLaunch {
                // For first launch, show a simple welcome screen
                VStack(spacing: 20) {
                    Image(logoImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 800, maxHeight: 800)
                    
                    Text("Welcome to ClientNote")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(Color.euniText)
                    
                    Text("Your AI-powered therapy documentation assistant")
                        .font(.title2)
                        .foregroundColor(Color.euniSecondary)
                    
                    Button("Get Started") {
                        // Mark as launched
                        UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
                        withAnimation(.easeOut(duration: 0.3)) {
                            isPresented = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.euniPrimary)
                    .padding(.top, 20)
                }
                .padding()
            } else {
                // For regular launch, just show the logo
                Image(logoImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 800, maxHeight: 800)
                    .onAppear {
                        // Mark as launched (in case it wasn't already)
                        UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
                        
                        // Simple delay without timer
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                isPresented = false
                            }
                        }
                    }
            }
        }
    }
}

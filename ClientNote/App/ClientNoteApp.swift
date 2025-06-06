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

        // Only create initial chat if not first launch (Flash will be downloaded during first launch)
        // OR if using LlamaKit and no model is configured yet
        if Defaults[.defaultHasLaunched] {
            // Check if we need to set up LlamaKit model
            let selectedBackend = Defaults[.selectedAIBackend]
            if selectedBackend == .llamaCpp && Defaults[.llamaKitModelPath].isEmpty {
                // LlamaKit is selected but no model configured - user needs to download Flash
                print("DEBUG: LlamaKit selected but no model configured - showing splash for setup")
                // Don't create initial chat, let splash screen handle setup
            } else {
                chatViewModel.create(model: Defaults[.defaultModel])
                if let activeChat = chatViewModel.selectedChats.first {
                    chatViewModel.activeChat = activeChat
                    messageViewModel.load(of: activeChat)
                }
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
    @State private var isOllamaInstalled: Bool = false
    @State private var isCheckingBackend: Bool = true
    @State private var isDownloadingModel: Bool = false
    @State private var downloadProgress: Double = 0.0
    @State private var downloadStatus: String = ""
    @State private var ollamaKit: OllamaKit
    @State private var selectedBackend: AIBackend = Defaults[.selectedAIBackend]
    
    private let logoImage = "1_Eunitm-Client-Notes-Effortless-AI-Powered-Therapy-Documentation"
    
    init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
        let baseURL = URL(string: Defaults[.defaultHost])!
        self._ollamaKit = State(initialValue: OllamaKit(baseURL: baseURL))
    }
    
    var body: some View {
        ZStack {
            Color.euniBackground
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(logoImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 800, maxHeight: 800)
                
                if isCheckingBackend {
                    ProgressView("Initializing AI backend...")
                        .progressViewStyle(.circular)
                } else if selectedBackend == .ollamaKit && !isOllamaInstalled {
                    VStack(spacing: 16) {
                        Text("Ollama Required")
                            .font(.headline)
                        
                        Text("Please install Ollama to continue")
                            .foregroundColor(.secondary)
                        
                        Button("Download Ollama") {
                            if let url = URL(string: "https://ollama.com/download") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.euniPrimary)
                        
                        Button("Check Again") {
                            checkBackendInstallation()
                        }
                    }
                } else if isDownloadingModel {
                    VStack(spacing: 8) {
                        ProgressView("Downloading Flash Assistant...", value: downloadProgress, total: 1.0)
                        Text(downloadStatus)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Button("Get Started") {
                        // Show download if first launch OR if LlamaKit selected but no model configured
                        if !Defaults[.defaultHasLaunched] || (selectedBackend == .llamaCpp && Defaults[.llamaKitModelPath].isEmpty) {
                            downloadFlashAssistant()
                        } else {
                            dismissSplashScreen()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.euniPrimary)
                    .disabled(isDownloadingModel || (selectedBackend == .ollamaKit && !isOllamaInstalled))
                }
            }
            .padding()
        }
        .onAppear {
            selectedBackend = Defaults[.selectedAIBackend]
            checkBackendInstallation()
        }
    }
    
    private func checkBackendInstallation() {
        isCheckingBackend = true
        selectedBackend = Defaults[.selectedAIBackend]
        
        Task {
            if selectedBackend == .ollamaKit {
                // Check Ollama installation
                let isReachable = await ollamaKit.reachable()
                
                await MainActor.run {
                    isOllamaInstalled = isReachable
                    isCheckingBackend = false
                    
                    // If Ollama is installed and this is not first launch, dismiss splash screen
                    if isReachable && Defaults[.defaultHasLaunched] {
                        dismissSplashScreen()
                    }
                }
            } else {
                // Using LlamaKit - check if model is configured
                await MainActor.run {
                    isOllamaInstalled = true // Set to true to indicate backend is ready
                    isCheckingBackend = false
                    
                    // If this is not first launch AND a model is configured, dismiss splash screen
                    let hasModel = !Defaults[.llamaKitModelPath].isEmpty
                    if Defaults[.defaultHasLaunched] && hasModel {
                        dismissSplashScreen()
                    }
                    // Otherwise, splash screen will show "Get Started" button for model setup
                }
            }
        }
    }
    
    private func downloadFlashAssistant() {
        isDownloadingModel = true
        downloadProgress = 0.0
        downloadStatus = "Starting download..."
        
        Task {
            if selectedBackend == .ollamaKit {
                await pullFlashModelFromOllama()
            } else {
                await downloadFlashModelForLlamaKit()
            }
            
            await MainActor.run {
                isDownloadingModel = false
                if downloadStatus == "success" {
                    Task {
                        // Set appropriate default model based on backend
                        if selectedBackend == .ollamaKit {
                            Defaults[.defaultModel] = "qwen3:0.6b"
                            // Create initial chat with Flash for Ollama
                            chatViewModel.create(model: "qwen3:0.6b")
                        } else {
                            // For LlamaKit, set the model path and load it into the backend
                            if let flashModel = AssistantModel.all.first(where: { $0.name == "Flash" }),
                               let fileName = flashModel.llamaKitFileName {
                                let modelPath = getModelDownloadPath().appendingPathComponent(fileName).path
                                Defaults[.llamaKitModelPath] = modelPath
                                Defaults[.defaultModel] = fileName
                                
                                // Load the model into LlamaKit backend
                                do {
                                    print("DEBUG: Loading Flash model into LlamaKit backend: \(modelPath)")
                                    try await aiBackendManager.loadModelForLlamaCpp(modelPath)
                                    
                                    // Create initial chat with Flash for LlamaKit
                                    chatViewModel.create(model: fileName)
                                    if let activeChat = chatViewModel.selectedChats.first {
                                        chatViewModel.activeChat = activeChat
                                        messageViewModel.load(of: activeChat)
                                    }
                                    
                                    print("DEBUG: Successfully set up Flash model for first-time user")
                                } catch {
                                    print("DEBUG: Failed to load Flash model into backend: \(error)")
                                    downloadStatus = "Error: Failed to load model"
                                    return
                                }
                            }
                        }
                        
                        // Mark as launched
                        Defaults[.defaultHasLaunched] = true
                        // Dismiss splash screen
                        dismissSplashScreen()
                    }
                }
            }
        }
    }
    
    private func pullFlashModelFromOllama() async {
        guard let url = URL(string: "\(Defaults[.defaultHost])/api/pull") else {
            await MainActor.run {
                downloadStatus = "Error: Invalid Ollama host URL"
                isDownloadingModel = false
            }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let pullRequest: [String: Any] = ["model": "qwen3:0.6b", "stream": true]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: pullRequest)
            
            let (data, response) = try await URLSession.shared.bytes(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode >= 400 {
                    let errorMessage: String
                    switch httpResponse.statusCode {
                    case 404:
                        errorMessage = "Ollama service not found. Is Ollama running?"
                    case 500...599:
                        errorMessage = "Ollama server error (HTTP \(httpResponse.statusCode))"
                    default:
                        errorMessage = "HTTP error \(httpResponse.statusCode)"
                    }
                    
                    await MainActor.run {
                        downloadStatus = "Error: \(errorMessage)"
                        isDownloadingModel = false
                    }
                    return
                }
            }
            
            var buffer = Data()
            var completedSize: Int64 = 0
            var totalSize: Int64 = 1
            
            for try await byte in data {
                buffer.append(contentsOf: [byte])
                
                if byte == 10 {
                    if let responseString = String(data: buffer, encoding: .utf8),
                       let responseData = responseString.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] {
                        
                        if let status = json["status"] as? String {
                            await MainActor.run {
                                downloadStatus = status
                                
                                if status == "success" {
                                    downloadProgress = 1.0
                                }
                            }
                            
                            if let completed = json["completed"] as? Int64 {
                                completedSize = completed
                            }
                            
                            if let total = json["total"] as? Int64, total > 0 {
                                totalSize = total
                            }
                            
                            if completedSize > 0 && totalSize > 0 {
                                let progress = Double(completedSize) / Double(totalSize)
                                await MainActor.run {
                                    downloadProgress = min(progress, 0.99)
                                }
                            }
                        }
                        
                        if let errorMessage = json["error"] as? String {
                            await MainActor.run {
                                downloadStatus = "Error: \(errorMessage)"
                                isDownloadingModel = false
                            }
                            return
                        }
                    }
                    
                    buffer.removeAll()
                }
            }
        } catch let urlError as URLError {
            await MainActor.run {
                let errorMessage: String
                switch urlError.code {
                case .notConnectedToInternet:
                    errorMessage = "No internet connection"
                case .timedOut:
                    errorMessage = "Connection timed out"
                case .cannotConnectToHost:
                    errorMessage = "Cannot connect to Ollama. Is Ollama running?"
                default:
                    errorMessage = urlError.localizedDescription
                }
                
                downloadStatus = "Error: \(errorMessage)"
                isDownloadingModel = false
            }
        } catch {
            await MainActor.run {
                downloadStatus = "Error: \(error.localizedDescription)"
                isDownloadingModel = false
            }
        }
    }
    
    private func downloadFlashModelForLlamaKit() async {
        guard let flashModel = AssistantModel.all.first(where: { $0.name == "Flash" }),
              let downloadURL = flashModel.downloadURL,
              let fileName = flashModel.llamaKitFileName,
              let url = URL(string: downloadURL) else {
            await MainActor.run {
                downloadStatus = "Error: Invalid Flash model configuration"
                isDownloadingModel = false
            }
            return
        }
        
        let downloadPath = getModelDownloadPath()
        let destinationURL = downloadPath.appendingPathComponent(fileName)
        
        // Create models directory if it doesn't exist
        do {
            try FileManager.default.createDirectory(at: downloadPath, withIntermediateDirectories: true)
        } catch {
            await MainActor.run {
                downloadStatus = "Error: Could not create models directory"
                isDownloadingModel = false
            }
            return
        }
        
        // Check if model already exists
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            await MainActor.run {
                downloadProgress = 1.0
                downloadStatus = "success"
            }
            return
        }
        
        do {
            await MainActor.run {
                downloadStatus = "Downloading Flash model..."
            }
            
            let (tempURL, response) = try await URLSession.shared.download(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode >= 400 {
                    await MainActor.run {
                        downloadStatus = "Error: HTTP \(httpResponse.statusCode)"
                        isDownloadingModel = false
                    }
                    return
                }
            }
            
            // Move downloaded file to final location
            try FileManager.default.moveItem(at: tempURL, to: destinationURL)
            
            await MainActor.run {
                downloadProgress = 1.0
                downloadStatus = "success"
            }
            
        } catch {
            await MainActor.run {
                downloadStatus = "Error: \(error.localizedDescription)"
                isDownloadingModel = false
            }
        }
    }
    
    private func getModelDownloadPath() -> URL {
        // Use the app's Application Support directory (proper location for app-specific data)
        let appSupportPaths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupportPath = appSupportPaths.first!
        
        // Create app-specific subdirectory
        let appName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "ClientNote"
        return appSupportPath
            .appendingPathComponent(appName, isDirectory: true)
            .appendingPathComponent("LlamaKitModels", isDirectory: true)
    }
    
    private func dismissSplashScreen() {
        withAnimation(.easeOut(duration: 0.3)) {
            isPresented = false
        }
    }
}

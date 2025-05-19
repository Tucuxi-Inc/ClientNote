import SwiftUI
import Defaults
import OllamaKit

struct SplashScreen: View {
    @Environment(ChatViewModel.self) private var chatViewModel
    @Binding var isPresented: Bool
    @State private var isOllamaInstalled: Bool = false
    @State private var isCheckingOllama: Bool = true
    @State private var isDownloadingFlash: Bool = false
    @State private var downloadProgress: Double = 0.0
    @State private var downloadStatus: String = ""
    @State private var ollamaKit: OllamaKit
    
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
                
                if isCheckingOllama {
                    ProgressView("Checking Ollama installation...")
                        .progressViewStyle(.circular)
                } else if !isOllamaInstalled {
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
                            checkOllamaInstallation()
                        }
                    }
                } else if isDownloadingFlash {
                    VStack(spacing: 8) {
                        ProgressView("Downloading Flash Assistant...", value: downloadProgress, total: 1.0)
                        Text(downloadStatus)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Button("Get Started") {
                        if !Defaults[.defaultHasLaunched] {
                            downloadFlashAssistant()
                        } else {
                            dismissSplashScreen()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.euniPrimary)
                    .disabled(!isOllamaInstalled || isDownloadingFlash)
                }
            }
            .padding()
        }
        .onAppear {
            checkOllamaInstallation()
        }
    }
    
    private func checkOllamaInstallation() {
        isCheckingOllama = true
        
        Task {
            let isReachable = await ollamaKit.reachable()
            
            await MainActor.run {
                isOllamaInstalled = isReachable
                isCheckingOllama = false
                
                // If Ollama is installed and this is not first launch, dismiss splash screen
                if isReachable && Defaults[.defaultHasLaunched] {
                    dismissSplashScreen()
                }
            }
        }
    }
    
    private func downloadFlashAssistant() {
        isDownloadingFlash = true
        downloadProgress = 0.0
        downloadStatus = "Starting download..."
        
        Task {
            await pullFlashModel()
            await MainActor.run {
                isDownloadingFlash = false
                if downloadStatus == "success" {
                    // Set default model to Flash
                    Defaults[.defaultModel] = "qwen3:0.6b"
                    // Mark as launched
                    Defaults[.defaultHasLaunched] = true
                    // Create initial chat with Flash
                    chatViewModel.create(model: "qwen3:0.6b")
                    // Dismiss splash screen
                    dismissSplashScreen()
                }
            }
        }
    }
    
    private func pullFlashModel() async {
        guard let url = URL(string: "\(Defaults[.defaultHost])/api/pull") else {
            await MainActor.run {
                downloadStatus = "Error: Invalid Ollama host URL"
                isDownloadingFlash = false
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
                        isDownloadingFlash = false
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
                                isDownloadingFlash = false
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
                isDownloadingFlash = false
            }
        } catch {
            await MainActor.run {
                downloadStatus = "Error: \(error.localizedDescription)"
                isDownloadingFlash = false
            }
        }
    }
    
    private func dismissSplashScreen() {
        withAnimation(.easeOut(duration: 0.3)) {
            isPresented = false
        }
    }
}

#Preview {
    SplashScreen(isPresented: .constant(true))
        .environment(ChatViewModel(modelContext: try! ModelContainer(for: Chat.self, Message.self).mainContext))
        .environment(MessageViewModel(modelContext: try! ModelContainer(for: Chat.self, Message.self).mainContext))
}

// Extension to Defaults for tracking first launch
extension DefaultsKey {
    static let defaultHasLaunched = Key<Bool>("defaultHasLaunched", default: false)
} 
} 
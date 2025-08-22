//
//  AIBackendAdapter.swift
//  ClientNote
//
//  Bridges the old AIBackendProtocol with new AI Services
//

import Foundation
import Defaults

// MARK: - Chat Request Types (for backward compatibility)

struct AIChatRequest {
    let model: String
    let messages: [AIMessage]
    let temperature: Double?
    let topP: Double?
    let topK: Int?
    
    init(model: String, messages: [AIMessage], temperature: Double? = nil, topP: Double? = nil, topK: Int? = nil) {
        self.model = model
        self.messages = messages
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
    }
}

struct AIMessage {
    let role: AIMessageRole
    let content: String
}

enum AIMessageRole {
    case system
    case user
    case assistant
}

// MARK: - Protocols

// Keep the old protocol for compatibility
@MainActor
protocol AIBackendProtocol: ObservableObject {
    var isReady: Bool { get }
    var status: String { get }
    
    func initialize() async throws
    func loadModel(at path: String) async throws
    func listModels() async throws -> [String]
    func chat(request: AIChatRequest, onPartialResponse: @escaping (String) -> Void) async throws -> String
}

// Adapter to make new services work with old protocol
@MainActor
class AIServiceAdapter: AIBackendProtocol {
    @Published var isReady: Bool = false
    @Published var status: String = "Not initialized"
    
    private let service: AIService
    private var currentModel: String = "gpt-4.1-nano"
    
    init(service: AIService) {
        self.service = service
    }
    
    func initialize() async throws {
        status = "Checking \(service.serviceType.rawValue)..."
        
        if await service.isAvailable() {
            isReady = true
            status = "\(service.serviceType.rawValue) ready"
            
            // Set default model based on service type
            switch service.serviceType {
            case .ollama:
                // For Ollama, select the best compatible model
                do {
                    let models = try await service.listModels()
                    
                    // Preferred models in order - excluding problematic gpt-oss:20b
                    let preferredModels = [
                        "qwen3:0.6b",        // Baseline model that works well
                        "granite3.3:2b",     // Good balance
                        "qwen3:1.7b",        // Better than 0.6b
                        "granite3.3:8b",     // Most capable
                        "phi4-mini-reasoning:3.8b", // Reasoning model
                        "gemma3:4b",         // Better gemma
                        "gemma3:1b",         // Fallback gemma
                        "gemma3n:e4b"        // Last resort
                    ]
                    
                    // Find the best available model (excluding gpt-oss:20b)
                    currentModel = "qwen3:0.6b" // Default
                    for preferredModel in preferredModels {
                        if models.contains(preferredModel) {
                            currentModel = preferredModel
                            print("DEBUG: AIServiceAdapter - Selected preferred Ollama model: \(currentModel)")
                            break
                        }
                    }
                    
                    if currentModel == "qwen3:0.6b" && !models.contains("qwen3:0.6b") {
                        // If qwen3:0.6b isn't available, pick any model except gpt-oss:20b
                        let filteredModels = models.filter { !$0.contains("gpt-oss") }
                        if let fallbackModel = filteredModels.first {
                            currentModel = fallbackModel
                            print("DEBUG: AIServiceAdapter - Using fallback model: \(currentModel)")
                        }
                    }
                } catch {
                    currentModel = "qwen3:0.6b"
                    print("DEBUG: AIServiceAdapter - Error listing Ollama models, using default: \(error)")
                }
            case .openAIUser:
                currentModel = "gpt-4.1-nano"
            }
        } else {
            isReady = false
            status = "\(service.serviceType.rawValue) not available"
            throw AIBackendError.notReady
        }
    }
    
    func loadModel(at path: String) async throws {
        // For compatibility - new services don't need explicit model loading
        // Just update the current model name
        currentModel = URL(fileURLWithPath: path).lastPathComponent
        status = "Using model: \(currentModel)"
    }
    
    func listModels() async throws -> [String] {
        return try await service.listModels()
    }
    
    func chat(request: AIChatRequest, onPartialResponse: @escaping (String) -> Void) async throws -> String {
        // For Ollama, we need to handle streaming properly
        if service.serviceType == .ollama {
            // Build the full conversation context
            var conversationContext = ""
            for message in request.messages {
                switch message.role {
                case .system:
                    conversationContext += "System: \(message.content)\n\n"
                case .user:
                    conversationContext += "User: \(message.content)\n\n"
                case .assistant:
                    conversationContext += "Assistant: \(message.content)\n\n"
                }
            }
            
            // Use the model from the request if provided, otherwise use current model
            let modelToUse = request.model.isEmpty ? currentModel : request.model
            
            print("DEBUG: AIServiceAdapter.chat - Using Ollama with model: \(modelToUse)")
            
            // For now, get the full response and then stream it back
            // TODO: Implement proper streaming when OllamaService supports it
            let response = try await service.sendMessage(conversationContext, model: modelToUse)
            
            // Stream the response back in chunks for UI responsiveness
            let chunkSize = 10
            for i in stride(from: 0, to: response.count, by: chunkSize) {
                let endIndex = min(i + chunkSize, response.count)
                let chunk = String(response[response.index(response.startIndex, offsetBy: i)..<response.index(response.startIndex, offsetBy: endIndex)])
                onPartialResponse(chunk)
                
                // Small delay to simulate streaming
                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }
            
            return response
        } else {
            // For OpenAI services, use the existing logic
            let messages = request.messages.map { msg -> String in
                switch msg.role {
                case .system:
                    return "System: \(msg.content)"
                case .user:
                    return "User: \(msg.content)"
                case .assistant:
                    return "Assistant: \(msg.content)"
                }
            }.joined(separator: "\n")
            
            let response = try await service.sendMessage(messages, model: currentModel)
            onPartialResponse(response)
            return response
        }
    }
}

// Simplified backend manager that uses AIServiceManager
@MainActor
@Observable
final class AIBackendManager {
    static let shared = AIBackendManager()
    
    private(set) var currentBackend: (any AIBackendProtocol)?
    
    private let serviceManager: AIServiceManager = {
        print("DEBUG: AIBackendManager - About to access AIServiceManager.shared")
        let manager = AIServiceManager.shared
        print("DEBUG: AIBackendManager - Got AIServiceManager.shared: \(manager)")
        return manager
    }()
    private let keychainManager = KeychainManager.shared
    
    // For backward compatibility
    var selectedBackendType: AIBackend {
        // Check user preference first
        let userSelectedBackend = Defaults[.selectedAIBackend]
        
        // If user explicitly selected Ollama, return that
        if userSelectedBackend == .ollamaKit {
            return .ollamaKit
        }
        
        // Otherwise map service types to old backend types
        switch serviceManager.currentService?.serviceType {
        case .ollama:
            return .ollamaKit
        case .openAIUser:
            return .openAI
        case nil:
            return userSelectedBackend
        }
    }
    
    private init() {
        // Initialize with user's selected backend preference
        Task { @MainActor in
            let selectedBackend = Defaults[.selectedAIBackend]
            print("DEBUG: AIBackendManager init - User selected backend: \(selectedBackend.displayName)")
            
            do {
                try await initializeBackend(selectedBackend)
            } catch {
                print("DEBUG: AIBackendManager init - Failed to initialize \(selectedBackend.displayName): \(error)")
                // Try to initialize with current service if available
                if let service = serviceManager.currentService {
                    let adapter = AIServiceAdapter(service: service)
                    try? await adapter.initialize()
                    self.currentBackend = adapter
                }
            }
        }
    }
    
    func initializeBackend(_ type: AIBackend) async throws {
        print("DEBUG: AIBackendManager.initializeBackend - Initializing backend: \(type.displayName)")
        
        // Ensure company developer key is always stored in keychain
        await ensureCompanyKeyStored()
        
        // Initialize service manager to ensure it detects current subscription status
        print("DEBUG: AIBackendManager - Initializing service manager to detect subscription changes")
        await serviceManager.initialize()
        print("DEBUG: AIBackendManager - Service manager initialized. Available services: \(serviceManager.availableServices.map(\.rawValue))")
        
        // Map old backend types to new service types
        let serviceType: AIServiceType
        switch type {
        case .ollamaKit:
            serviceType = .ollama
        case .openAI:
            // Check if user has API key
            let hasUserKey = keychainManager.hasKey(keyType: .openAIUserKey)
            print("DEBUG: AIBackendManager - OpenAI backend selected. hasUserKey: \(hasUserKey)")
            
            if hasUserKey {
                print("DEBUG: AIBackendManager - Using user OpenAI key")
                serviceType = .openAIUser
            } else {
                // Default to Ollama if no OpenAI credentials
                print("DEBUG: AIBackendManager - No valid OpenAI credentials, falling back to Ollama")
                serviceType = .ollama
            }
        }
        
        print("DEBUG: AIBackendManager.initializeBackend - Selected service type: \(serviceType.rawValue)")
        
        // Select the service if not already selected
        if serviceManager.currentService?.serviceType != serviceType {
            await serviceManager.selectService(serviceType)
        }
        
        // Create and initialize the adapter for the selected service
        if let service = serviceManager.currentService {
            let adapter = AIServiceAdapter(service: service)
            try await adapter.initialize()
            self.currentBackend = adapter
            print("DEBUG: AIBackendManager.initializeBackend - Backend initialized successfully: \(adapter.status)")
        } else {
            print("DEBUG: AIBackendManager.initializeBackend - No service available for type: \(serviceType.rawValue)")
            throw AIBackendError.notReady
        }
    }
    
    func initializeBackend(_ type: AIServiceType) async throws {
        await serviceManager.selectService(type)
        
        // Create and initialize the adapter for the selected service
        if let service = serviceManager.currentService {
            let adapter = AIServiceAdapter(service: service)
            try await adapter.initialize()
            self.currentBackend = adapter
        }
    }
    
    func updateOllamaHost(_ host: String) {
        // For compatibility - new services handle their own configuration
        // This is a no-op for now
    }
    
    func reachable() async -> Bool {
        // Check the user's selected backend preference
        let selectedBackend = Defaults[.selectedAIBackend]
        
        if selectedBackend == .ollamaKit {
            // For Ollama, check if it's reachable
            let ollamaService = OllamaService()
            let isAvailable = await ollamaService.isAvailable()
            print("DEBUG: AIBackendManager.reachable - Ollama availability: \(isAvailable)")
            return isAvailable
        }
        
        // Check if the current service is available
        let serviceManager = AIServiceManager.shared
        if let currentService = serviceManager.currentService {
            return await currentService.isAvailable()
        }
        
        return false
    }
    
    private func ensureCompanyKeyStored() async {
        print("DEBUG: AIBackendManager - Ensuring company key is stored in keychain")
        
        // Check if company key is already stored
        if keychainManager.hasKey(keyType: .openAIDeveloperKey) {
            print("DEBUG: AIBackendManager - Company key already exists in keychain")
            return
        }
        
        // Store the company key
        do {
            let companyKey = CompanyAPIKeys.openAIKey
            print("DEBUG: AIBackendManager - Company key configured: \(CompanyAPIKeys.isConfigured)")
            print("DEBUG: AIBackendManager - Company key length: \(companyKey.count), starts with sk-: \(companyKey.hasPrefix("sk-"))")
            try keychainManager.save(key: companyKey, for: .openAIDeveloperKey)
            print("DEBUG: AIBackendManager - Successfully stored company key in keychain")
        } catch {
            print("DEBUG: AIBackendManager - Failed to store company key: \(error)")
        }
    }
    
}

// Keep old backend enum for compatibility
enum AIBackend: String, CaseIterable, Defaults.Serializable {
    case ollamaKit = "ollamaKit"
    case openAI = "openAI"
    
    var displayName: String {
        switch self {
        case .ollamaKit:
            return "Free Local AI"
        case .openAI:
            return "OpenAI"
        }
    }
    
    var description: String {
        switch self {
        case .ollamaKit:
            return "AI that runs on your computer"
        case .openAI:
            return "Use your own OpenAI Developer API key to use an OpenAI model running on OpenAI's servers"
        }
    }
}

// Keep old error types for compatibility
enum AIBackendError: LocalizedError {
    case notReady
    case modelLoadFailed(String)
    case chatFailed(String)
    case backendNotReady(String)
    
    var errorDescription: String? {
        switch self {
        case .notReady:
            return "AI backend is not ready"
        case .modelLoadFailed(let reason):
            return "Failed to load model: \(reason)"
        case .chatFailed(let reason):
            return "Chat failed: \(reason)"
        case .backendNotReady(let reason):
            return "Backend not ready: \(reason)"
        }
    }
} 
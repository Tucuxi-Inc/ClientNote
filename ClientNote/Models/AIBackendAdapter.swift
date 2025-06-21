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
                currentModel = "qwen3:0.6b"
            case .openAIUser, .openAISubscription:
                currentModel = "gpt-4.1-nano"
            }
        } else {
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
        // Convert old request format to simple string for new service
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
        
        // For now, just use the full response (streaming can be added later)
        let response = try await service.sendMessage(messages, model: currentModel)
        onPartialResponse(response)
        return response
    }
}

// Simplified backend manager that uses AIServiceManager
@MainActor
@Observable
final class AIBackendManager {
    static let shared = AIBackendManager()
    
    private(set) var currentBackend: (any AIBackendProtocol)?
    
    private let serviceManager = AIServiceManager.shared
    
    // For backward compatibility
    var selectedBackendType: AIBackend {
        // Map service types to old backend types
        switch serviceManager.currentService?.serviceType {
        case .ollama:
            return .ollamaKit
        case .openAIUser, .openAISubscription:
            return .openAI
        case nil:
            return .ollamaKit
        }
    }
    
    private init() {
        // Initialize with current service if available
        Task { @MainActor in
            if let service = serviceManager.currentService {
                let adapter = AIServiceAdapter(service: service)
                try? await adapter.initialize()
                self.currentBackend = adapter
            }
        }
    }
    
    func initializeBackend(_ type: AIBackend) async throws {
        // Map old backend types to new service types
        let serviceType: AIServiceType
        switch type {
        case .ollamaKit:
            serviceType = .ollama
        case .openAI:
            // Check if user has API key or subscription
            if !KeychainManager.shared.openAIAPIKey.isEmpty {
                serviceType = .openAIUser
            } else {
                serviceType = .openAISubscription
            }
        }
        
        await serviceManager.selectService(serviceType)
        
        // Create and initialize the adapter for the selected service
        if let service = serviceManager.currentService {
            let adapter = AIServiceAdapter(service: service)
            try await adapter.initialize()
            self.currentBackend = adapter
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
        // Check if the current service is available
        let serviceManager = AIServiceManager.shared
        if let currentService = serviceManager.currentService {
            return await currentService.isAvailable()
        }
        
        // Fallback: check if Ollama is available since that's what the splash screen cares about
        let ollamaService = OllamaService()
        return await ollamaService.isAvailable()
    }
}

// Keep old backend enum for compatibility
enum AIBackend: String, CaseIterable, Defaults.Serializable {
    case ollamaKit = "ollamaKit"
    case openAI = "openAI"
    
    var displayName: String {
        switch self {
        case .ollamaKit:
            return "Ollama"
        case .openAI:
            return "OpenAI"
        }
    }
    
    var description: String {
        switch self {
        case .ollamaKit:
            return "Connect to Ollama server for local or remote AI models"
        case .openAI:
            return "Use OpenAI's GPT models for AI-powered documentation"
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
//
//  AIService.swift
//  ClientNote
//
//  AI Service Protocol and Types
//

import Foundation
import Defaults

protocol AIService {
    func sendMessage(_ message: String, model: String) async throws -> String
    func listModels() async throws -> [String]
    func isAvailable() async -> Bool
    var serviceType: AIServiceType { get }
}

enum AIServiceType: String, CaseIterable {
    case ollama = "Free (Local)"
    case openAIUser = "OpenAI Account (Non-Local)"
    case openAISubscription = "Euni Subscription/Purchase (Non-Local)"
    
    var requiresSubscription: Bool {
        return self == .openAISubscription
    }
    
    var requiresAPIKey: Bool {
        return self == .openAIUser
    }
    
    var icon: String {
        switch self {
        case .ollama: return "desktopcomputer"
        case .openAIUser: return "key.fill"
        case .openAISubscription: return "star.fill"
        }
    }
    
    var description: String {
        switch self {
        case .ollama: return "Requires the free Ollama app"
        case .openAIUser: return "Requires an active OpenAI Account & valid developer API Key"
        case .openAISubscription: return "Requires a lifetime purchase or active subscription to Euni"
        }
    }
}

// MARK: - AI Service Manager

@MainActor
@Observable
final class AIServiceManager {
    static let shared = AIServiceManager()
    
    private(set) var currentService: (any AIService)?
    private(set) var availableServices: [AIServiceType] = []
    
    var isConfigured: Bool {
        return currentService != nil
    }
    
    var status: String {
        if let service = currentService {
            return "\(service.serviceType.rawValue) active"
        } else {
            return "No AI service configured"
        }
    }
    
    private init() {
        // Check available services on init
        Task {
            await checkAvailableServices()
        }
    }
    
    func checkAvailableServices() async {
        var available: [AIServiceType] = []
        
        // Check Ollama
        let ollamaService = OllamaService()
        if await ollamaService.isAvailable() {
            available.append(.ollama)
        }
        
        // Check OpenAI with user key
        if !KeychainManager.shared.openAIAPIKey.isEmpty {
            available.append(.openAIUser)
        }
        
        // Check subscription
        if Defaults[.hasActiveSubscription] || Defaults[.hasFullUnlock] {
            available.append(.openAISubscription)
        }
        
        await MainActor.run {
            self.availableServices = available
            
            // Auto-select first available service if none selected
            if currentService == nil && !available.isEmpty {
                Task {
                    await selectService(available[0])
                }
            }
        }
    }
    
    func selectService(_ type: AIServiceType) async {
        switch type {
        case .ollama:
            currentService = OllamaService()
        case .openAIUser:
            if !KeychainManager.shared.openAIAPIKey.isEmpty {
                currentService = OpenAIService(apiKey: KeychainManager.shared.openAIAPIKey)
            }
        case .openAISubscription:
            // Check subscription status
            let hasAccess = Defaults[.hasActiveSubscription] || Defaults[.hasFullUnlock]
            if hasAccess {
                // Use company API key for subscription users
                let apiKey = CompanyAPIKeys.openAIKey
                if !apiKey.isEmpty && CompanyAPIKeys.isConfigured {
                    currentService = OpenAIService(apiKey: apiKey, isSubscription: true)
                } else {
                    print("WARNING: Company API key not configured")
                }
            }
        }
        
        // Update the selected service type
        Defaults[.selectedAIServiceType] = type
    }
    
    func initialize() async {
        await checkAvailableServices()
    }
    
    func saveUserOpenAIKey(_ key: String) throws {
        KeychainManager.shared.openAIAPIKey = key
        Task {
            await checkAvailableServices()
        }
    }
    
    func removeUserOpenAIKey() throws {
        KeychainManager.shared.openAIAPIKey = ""
        Task {
            await checkAvailableServices()
        }
    }
}

// MARK: - Ollama Service

struct OllamaService: AIService {
    let serviceType = AIServiceType.ollama
    private let baseURL: URL
    
    init() {
        self.baseURL = URL(string: Defaults[.defaultHost])!
    }
    
    func isAvailable() async -> Bool {
        guard let url = URL(string: "\(baseURL.absoluteString)/api/tags") else { return false }
        
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
        } catch {
            // Ignore errors, just return false
        }
        
        return false
    }
    
    func listModels() async throws -> [String] {
        guard let url = URL(string: "\(baseURL.absoluteString)/api/tags") else {
            throw AIServiceError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(OllamaModelsResponse.self, from: data)
        return response.models.map { $0.name }
    }
    
    func sendMessage(_ message: String, model: String) async throws -> String {
        guard let url = URL(string: "\(baseURL.absoluteString)/api/chat") else {
            throw AIServiceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Parse the message to extract system and user parts
        let lines = message.split(separator: "\n", omittingEmptySubsequences: false)
        var messages: [[String: String]] = []
        
        var currentRole = "user"
        var currentContent = ""
        
        for line in lines {
            if line.hasPrefix("System: ") {
                if !currentContent.isEmpty {
                    messages.append(["role": currentRole, "content": currentContent.trimmingCharacters(in: .whitespacesAndNewlines)])
                }
                currentRole = "system"
                currentContent = String(line.dropFirst(8))
            } else if line.hasPrefix("User: ") {
                if !currentContent.isEmpty {
                    messages.append(["role": currentRole, "content": currentContent.trimmingCharacters(in: .whitespacesAndNewlines)])
                }
                currentRole = "user"
                currentContent = String(line.dropFirst(6))
            } else if line.hasPrefix("Assistant: ") {
                if !currentContent.isEmpty {
                    messages.append(["role": currentRole, "content": currentContent.trimmingCharacters(in: .whitespacesAndNewlines)])
                }
                currentRole = "assistant"
                currentContent = String(line.dropFirst(11))
            } else {
                currentContent += "\n" + line
            }
        }
        
        // Add the last message
        if !currentContent.isEmpty {
            messages.append(["role": currentRole, "content": currentContent.trimmingCharacters(in: .whitespacesAndNewlines)])
        }
        
        // If no structured messages were found, treat the whole thing as a user message
        if messages.isEmpty {
            messages = [["role": "user", "content": message]]
        }
        
        let body = OllamaChatRequest(model: model, messages: messages, stream: false)
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(OllamaChatResponse.self, from: data)
        
        return response.message.content
    }
}

// MARK: - OpenAI Service

struct OpenAIService: AIService {
    let serviceType: AIServiceType
    private let apiKey: String
    private let baseURL = URL(string: "https://api.openai.com/v1")!
    
    init(apiKey: String, isSubscription: Bool = false) {
        self.apiKey = apiKey
        self.serviceType = isSubscription ? .openAISubscription : .openAIUser
    }
    
    func isAvailable() async -> Bool {
        // For OpenAI, we just check if we have an API key
        return !apiKey.isEmpty
    }
    
    func listModels() async throws -> [String] {
        // Only return gpt-4.1-nano for OpenAI
        return ["gpt-4.1-nano"]
    }
    
    func sendMessage(_ message: String, model: String) async throws -> String {
        guard let url = URL(string: "\(baseURL.absoluteString)/chat/completions") else {
            throw AIServiceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": message]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let message = firstChoice["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content
        }
        
        throw AIServiceError.invalidResponse
    }
}

// MARK: - Supporting Types

enum AIServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid service URL"
        case .invalidResponse:
            return "Invalid response from service"
        case .unauthorized:
            return "Unauthorized - check your API key"
        }
    }
}

// Ollama API Types
struct OllamaModelsResponse: Codable {
    let models: [OllamaModel]
}

struct OllamaModel: Codable {
    let name: String
}

struct OllamaChatRequest: Codable {
    let model: String
    let messages: [[String: String]]
    let stream: Bool
}

struct OllamaChatResponse: Codable {
    let message: OllamaMessage
}

struct OllamaMessage: Codable {
    let content: String
} 

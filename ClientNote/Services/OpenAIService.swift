//
//  OpenAIService.swift
//  ClientNote
//
//  OpenAI Service Implementation
//

import Foundation

class OpenAIService: AIService {
    private let apiKey: String
    private let isUserKey: Bool
    private let baseURL = "https://api.openai.com/v1"
    let serviceType: AIServiceType
    
    init(apiKey: String, isUserKey: Bool) {
        self.apiKey = apiKey
        self.isUserKey = isUserKey
        self.serviceType = isUserKey ? .openAIUser : .openAISubscription
    }
    
    func isAvailable() async -> Bool {
        // Validate API key with a simple request
        do {
            _ = try await listModels()
            return true
        } catch {
            return false
        }
    }
    
    func sendMessage(_ message: String, model: String) async throws -> String {
        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": message]],
            "temperature": 0.7,
            "stream": false
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OpenAIError.invalidResponse
        }
        
        let responseObj = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        
        return responseObj.choices.first?.message.content ?? ""
    }
    
    func listModels() async throws -> [String] {
        let url = URL(string: "\(baseURL)/models")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OpenAIError.invalidResponse
        }
        
        let modelsResponse = try JSONDecoder().decode(ModelsResponse.self, from: data)
        
        // Filter for chat models
        return modelsResponse.data
            .filter { $0.id.contains("gpt") }
            .map { $0.id }
            .sorted()
    }
}

// MARK: - Response Models

struct OpenAIResponse: Codable {
    let choices: [Choice]
    
    struct Choice: Codable {
        let message: Message
    }
    
    struct Message: Codable {
        let content: String
    }
}

struct ModelsResponse: Codable {
    let data: [Model]
    
    struct Model: Codable {
        let id: String
    }
}

enum OpenAIError: LocalizedError {
    case invalidResponse
    case invalidAPIKey
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from OpenAI API"
        case .invalidAPIKey:
            return "Invalid API key"
        }
    }
} 
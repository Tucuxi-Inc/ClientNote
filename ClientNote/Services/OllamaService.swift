//
//  OllamaService.swift
//  ClientNote
//
//  Ollama Service Implementation using OllamaKit
//

import Foundation
import OllamaKit

@MainActor
class OllamaService: AIService {
    private let ollamaKit: OllamaKit
    let serviceType = AIServiceType.ollama
    private let host: String
    
    init(host: String = "http://localhost:11434") {
        self.host = host
        self.ollamaKit = OllamaKit(baseURL: URL(string: host)!)
        print("DEBUG: OllamaService initialized with host: \(host)")
    }
    
    func isAvailable() async -> Bool {
        // Check if Ollama is running
        do {
            let models = try await listModels()
            print("DEBUG: OllamaService.isAvailable - Found \(models.count) models")
            return !models.isEmpty
        } catch {
            print("DEBUG: OllamaService.isAvailable - Error: \(error)")
            // Check if Ollama app is installed
            return isOllamaInstalled()
        }
    }
    
    private func isOllamaInstalled() -> Bool {
        let ollamaPath = "/Applications/Ollama.app"
        let exists = FileManager.default.fileExists(atPath: ollamaPath)
        print("DEBUG: OllamaService - Ollama app installed: \(exists)")
        return exists
    }
    
    func sendMessage(_ message: String, model: String) async throws -> String {
        print("DEBUG: OllamaService.sendMessage - Model: \(model)")
        
        // Parse the message to extract system and user parts
        let lines = message.split(separator: "\n", omittingEmptySubsequences: false)
        var messages: [OKChatRequestData.Message] = []
        
        var currentRole: OKChatRequestData.Message.Role = .user
        var currentContent = ""
        
        for line in lines {
            if line.hasPrefix("System: ") {
                if !currentContent.isEmpty {
                    messages.append(OKChatRequestData.Message(role: currentRole, content: currentContent.trimmingCharacters(in: .whitespacesAndNewlines)))
                }
                currentRole = .system
                currentContent = String(line.dropFirst(8))
            } else if line.hasPrefix("User: ") {
                if !currentContent.isEmpty {
                    messages.append(OKChatRequestData.Message(role: currentRole, content: currentContent.trimmingCharacters(in: .whitespacesAndNewlines)))
                }
                currentRole = .user
                currentContent = String(line.dropFirst(6))
            } else if line.hasPrefix("Assistant: ") {
                if !currentContent.isEmpty {
                    messages.append(OKChatRequestData.Message(role: currentRole, content: currentContent.trimmingCharacters(in: .whitespacesAndNewlines)))
                }
                currentRole = .assistant
                currentContent = String(line.dropFirst(11))
            } else {
                currentContent += "\n" + line
            }
        }
        
        // Add the last message
        if !currentContent.isEmpty {
            messages.append(OKChatRequestData.Message(role: currentRole, content: currentContent.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        
        // If no structured messages were found, treat the whole thing as a user message
        if messages.isEmpty {
            messages = [OKChatRequestData.Message(role: .user, content: message)]
        }
        
        print("DEBUG: OllamaService.sendMessage - Sending \(messages.count) messages")
        
        let chatData = OKChatRequestData(
            model: model,
            messages: messages
        )
        
        var fullResponse = ""
        
        do {
            for try await chunk in ollamaKit.chat(data: chatData) {
                if let content = chunk.message?.content {
                    fullResponse += content
                }
                
                if chunk.done {
                    break
                }
            }
            
            print("DEBUG: OllamaService.sendMessage - Response length: \(fullResponse.count)")
            return fullResponse
        } catch {
            print("DEBUG: OllamaService.sendMessage - Error: \(error)")
            throw error
        }
    }
    
    func listModels() async throws -> [String] {
        do {
            let response = try await ollamaKit.models()
            let modelNames = response.models.map { $0.name }
            print("DEBUG: OllamaService.listModels - Found models: \(modelNames)")
            return modelNames
        } catch {
            print("DEBUG: OllamaService.listModels - Error: \(error)")
            throw error
        }
    }
} 
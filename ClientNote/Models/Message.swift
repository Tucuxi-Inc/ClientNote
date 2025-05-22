//
//  Message.swift
//
//
//  Created by Kevin Hermawan on 13/07/24.
//

import OllamaKit
import Foundation
import SwiftData

@Model
final class Message: Identifiable {
    @Attribute(.unique) var id: UUID = UUID()
    
    var prompt: String
    var response: String?
    var createdAt: Date = Date.now
    
    @Relationship
    var chat: Chat?
    
    init(prompt: String) {
        self.prompt = prompt
    }
    
    @Transient var model: String {
        self.chat?.model ?? ""
    }

    @Transient var displayPrompt: String {
        // Filter out analysis prompts and duplicates
        let analysisMarkers = [
            "Consider these common patterns of client engagement",
            "Please analyze the client's engagement and responsiveness",
            "Analyze the following therapy session transcript"
        ]
        
        // If the prompt contains any of the analysis markers, find the actual content
        if analysisMarkers.contains(where: { prompt.contains($0) }) {
            if let sessionStart = prompt.range(of: "Session Transcript:") {
                let content = String(prompt[sessionStart.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                // Only return content if it's not already shown in a previous message
                if let chat = chat,
                   let messageIndex = chat.messages.firstIndex(where: { $0.id == id }),
                   messageIndex > 0 {
                    let previousMessages = chat.messages[..<messageIndex]
                    if previousMessages.contains(where: { $0.prompt.contains(content) }) {
                        return ""  // Skip if content already shown
                    }
                }
                return content
            }
            return ""  // If no transcript found, don't show the analysis prompt
        }
        
        // For non-analysis prompts, check for duplicates
        if let chat = chat,
           let messageIndex = chat.messages.firstIndex(where: { $0.id == id }),
           messageIndex > 0 {
            let previousMessages = chat.messages[..<messageIndex]
            if previousMessages.contains(where: { $0.prompt == prompt }) {
                return ""  // Skip if exact prompt already shown
            }
        }
        
        return prompt
    }

    var responseText: String {
        var response = self.response ?? ""

        // identify <think> phase of model and remove it
        if let start = response.ranges(of: "<think>").first?.lowerBound {
            if let end = response.ranges(of: "</think>").first?.upperBound {
                response.removeSubrange(start...end)
            }
        }

        // return trimmed text
        return response.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension Message {
    func toOKChatRequestData(messages: [Message], modelPrompt: String? = nil) -> OKChatRequestData {
        var requestMessages = [OKChatRequestData.Message]()
        
        for message in messages {
            // For the current message, use the modelPrompt if provided
            if message.id == self.id, let modelPrompt = modelPrompt {
                let userMessage = OKChatRequestData.Message(role: .user, content: modelPrompt)
                requestMessages.append(userMessage)
            } else {
                let userMessage = OKChatRequestData.Message(role: .user, content: message.prompt)
                requestMessages.append(userMessage)
            }
            
            let assistantMessage = OKChatRequestData.Message(role: .assistant, content: message.response ?? "")
            requestMessages.append(assistantMessage)
        }
        
        if let systemPrompt = self.chat?.systemPrompt {
            let systemMessage = OKChatRequestData.Message(role: .system, content: systemPrompt)
            
            requestMessages.insert(systemMessage, at: 0)
        }
        
        let options = OKCompletionOptions(
            temperature: self.chat?.temperature,
            topK: self.chat?.topK,
            topP: self.chat?.topP
        )
        
        var data = OKChatRequestData(model: self.model, messages: requestMessages)
        data.options = options
        
        return data
    }
}

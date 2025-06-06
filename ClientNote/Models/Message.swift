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
        // Only filter out internal analysis prompts that shouldn't be shown to users
        // Since we now use a proper two-pass system, most prompts should be displayed
        
        let internalAnalysisMarkers = [
            "You are a clinical documentation assistant generating a structured",
            "FIRST PASS ANALYSIS RESULTS:",
            "THERAPEUTIC MODALITIES AND INTERVENTIONS:",
            "CLIENT ENGAGEMENT AND RESPONSIVENESS:",
            "Consider these common psychotherapy modalities and their typical interventions:",
            "Please analyze the session and:",
            "Consider these common patterns of client engagement"
        ]
        
        // Hide only clearly internal analysis prompts
        if internalAnalysisMarkers.contains(where: { prompt.contains($0) }) {
            return ""
        }
        
        // For all other prompts, display them normally
        // This includes user input from EasyNote forms and chat entries
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

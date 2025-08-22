//
//  Defaults+Keys.swift
//
//
//  Created by Kevin Hermawan on 13/07/24.
//

import Defaults
import Foundation
import AppKit.NSFont

// Make AIServiceType conform to Defaults.Serializable
extension AIServiceType: Defaults.Serializable {}

extension Defaults.Keys {
    static let defaultChatName = Key<String>("defaultChatName", default: "New Chat")
    static let defaultModel = Key<String>("defaultModel", default: "qwen3:0.6b")
    static let defaultHost = Key<String>("defaultHost", default: "http://localhost:11434")
    static let defaultHasLaunched = Key<Bool>("defaultHasLaunched", default: false)
    static let fontSize = Key<Double>("fontSize", default: NSFont.systemFontSize)
    static let defaultSystemPrompt = Key<String>("defaultSystemPrompt", default: """
        You are a helpful AI assistant engaging in a general brainstorming conversation. Your role is to:

        1. Help explore ideas and concepts openly
        2. Provide relevant information and insights
        3. Ask clarifying questions when needed
        4. Maintain a balanced and objective perspective
        5. Support creative thinking and problem-solving

        Focus on:
        - Understanding the specific topic or question at hand
        - Providing clear and well-structured responses
        - Being adaptable to different types of inquiries
        - Maintaining a helpful and constructive tone

        Avoid making assumptions about the context. If the user hasn't specified a particular framework or approach, keep responses general and adaptable.
        """)
    static let defaultTemperature = Key<Double>("defaultTemperature", default: 0.7)
    static let defaultTopP = Key<Double>("defaultTopP", default: 0.9)
    static let defaultTopK = Key<Int>("defaultTopK", default: 40)
    
    // AI Backend Settings
    static let selectedAIServiceType = Key<AIServiceType?>("selectedAIServiceType", default: .ollama)
    static let selectedAIBackend = Key<AIBackend>("selectedAIBackend", default: .ollamaKit)
    static let llamaKitModelPath = Key<String>("llamaKitModelPath", default: "")
    static let isOllamaInstalled = Key<Bool>("isOllamaInstalled", default: false)
    
    static let experimentalCodeHighlighting = Key<Bool>("experimentalCodeHighlighting", default: false)
    static let hasAcceptedTermsAndPrivacy = Key<Bool>("hasAcceptedTermsAndPrivacy", default: false)
}

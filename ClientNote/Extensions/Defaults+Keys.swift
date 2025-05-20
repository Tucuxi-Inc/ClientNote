//
//  Defaults+Keys.swift
//
//
//  Created by Kevin Hermawan on 13/07/24.
//

import Defaults
import Foundation
import AppKit.NSFont

extension Defaults.Keys {
    static let defaultChatName = Key<String>("defaultChatName", default: "New Chat")
    static let defaultModel = Key<String>("defaultModel", default: "qwen3:0.6b")
    static let defaultHost = Key<String>("defaultHost", default: "http://localhost:11434")
    static let defaultHasLaunched = Key<Bool>("defaultHasLaunched", default: false)
    static let fontSize = Key<Double>("fontSize", default: NSFont.systemFontSize)
    static let defaultSystemPrompt = Key<String>("defaultSystemPrompt", default: """
        You are a highly capable, precise, and helpful assistant. Your goal is to understand and follow the user's instructions exactly and to answer their questions as clearly and usefully as possible.

        Always prioritize:
        1. Accuracy: Provide factually correct and relevant information.
        2. Clarity: Use clear, concise language. Avoid unnecessary verbosity.
        3. Instruction-Following: Execute the user's specific instructions without deviation or unsolicited tangents.
        4. Helpfulness: If the user input is incomplete or unclear, ask clarifying questions.
        5. Tone: Maintain a professional, respectful, and informative tone at all times.

        Unless explicitly asked, do not add opinions, disclaimers, or unnecessary elaboration. When appropriate, structure your response with bullets, steps, or sections for readability. If a task cannot be completed, explain why and suggest an alternative.

        Act as a reliable partner in solving the user's problem.
        """)
    static let defaultTemperature = Key<Double>("defaultTemperature", default: 0.7)
    static let defaultTopP = Key<Double>("defaultTopP", default: 0.9)
    static let defaultTopK = Key<Int>("defaultTopK", default: 40)
    
    static let experimentalCodeHighlighting = Key<Bool>("experimentalCodeHighlighting", default: false)
}

//
//  MessageViewModel.swift
//
//
//  Created by Kevin Hermawan on 13/07/24.
//

import Foundation
import OllamaKit
import SwiftData

@MainActor
@Observable
final class MessageViewModel {
    private var modelContext: ModelContext
    private var generationTask: Task<Void, Never>?
    private weak var chatViewModel: ChatViewModel?
    
    var messages: [Message] = []
    var tempResponse: String = ""
    var loading: MessageViewModelLoading? = nil
    var error: MessageViewModelError? = nil
    
    init(modelContext: ModelContext, chatViewModel: ChatViewModel? = nil) {
        self.modelContext = modelContext
        self.chatViewModel = chatViewModel
    }
    
    func setChatViewModel(_ viewModel: ChatViewModel) {
        self.chatViewModel = viewModel
    }
    
    func load(of chat: Chat?) {
        // Clear current messages and state
        self.messages = []
        self.tempResponse = ""
        self.loading = nil
        self.error = nil
        
        guard let chat = chat else { return }
        
        let chatId = chat.id
        let predicate = #Predicate<Message> { $0.chat?.id == chatId }
        let sortDescriptor = SortDescriptor(\Message.createdAt)
        let fetchDescriptor = FetchDescriptor<Message>(predicate: predicate, sortBy: [sortDescriptor])
        
        self.loading = .load
        
        do {
            defer { self.loading = nil }
            self.messages = try self.modelContext.fetch(fetchDescriptor)
        } catch {
            self.error = .load(error.localizedDescription)
        }
    }
    
    func generate(activeChat: Chat, prompt: String, modelPrompt: String? = nil) {
        // Get an OllamaKit instance for this chat
        guard let host = activeChat.host,
              let baseURL = URL(string: host) else {
            self.error = .generate("Invalid host URL")
            return
        }
        
        let ollamaKit = OllamaKit(baseURL: baseURL)
        
        // Create a message with the display prompt (without PIRP instructions)
        let message = Message(prompt: prompt)
        message.chat = activeChat
        messages.append(message)
        modelContext.insert(message)
        
        self.loading = .generate
        self.error = nil
        
        generationTask = Task {
            defer { self.loading = nil }
            
            do {
                // Use the modelPrompt if provided, otherwise use the display prompt
                let data = message.toOKChatRequestData(messages: self.messages, modelPrompt: modelPrompt)
                
                for try await chunk in ollamaKit.chat(data: data) {
                    if Task.isCancelled { break }
                    
                    tempResponse = tempResponse + (chunk.message?.content ?? "")
                    
                    if chunk.done {
                        message.response = tempResponse
                        activeChat.modifiedAt = .now
                        tempResponse = ""
                        
                        if messages.count == 1 {
                            self.generateTitle(ollamaKit, activeChat: activeChat)
                        }
                        
                        // Save chat content to activity
                        chatViewModel?.saveActivityContent()
                    }
                }

                // If chunk was not done: handle temporary response
                if !tempResponse.isEmpty {
                    // properly close <think> block
                    if tempResponse.matches(of: /<\/?think>/).count == 1 {
                        tempResponse += "\n</think>\n"
                    }

                    // properly close any code blocks
                    if tempResponse.matches(of: /```/).count % 2 == 1 {
                        tempResponse += "\n```\n"
                    } else {
                        // ... or add a visual separator
                        tempResponse += "\n\n---\n"
                    }

                    // mark response as cancelled
                    tempResponse += "\n_CANCELLED_"

                    message.response = tempResponse
                    activeChat.modifiedAt = .now
                    tempResponse = ""
                }
            } catch {
                self.error = .generate(error.localizedDescription)
            }
        }
    }
    
    func regenerate(activeChat: Chat) {
        guard let lastMessage = messages.last else { return }
        lastMessage.response = nil
        
        // Get an OllamaKit instance for this chat
        guard let host = activeChat.host,
              let baseURL = URL(string: host) else {
            self.error = .generate("Invalid host URL")
            return
        }
        
        let ollamaKit = OllamaKit(baseURL: baseURL)
        
        self.loading = .generate
        self.error = nil
        
        generationTask = Task {
            defer { self.loading = nil }
            
            do {
                let data = lastMessage.toOKChatRequestData(messages: self.messages)
                
                for try await chunk in ollamaKit.chat(data: data) {
                    if Task.isCancelled { break }
                    
                    tempResponse = tempResponse + (chunk.message?.content ?? "")
                    
                    if chunk.done {
                        lastMessage.response = tempResponse
                        activeChat.modifiedAt = .now
                        tempResponse = ""
                    }
                }

                // If chunk was not done: handle temporary response
                if !tempResponse.isEmpty {
                    // properly close <think> block
                    if tempResponse.matches(of: /<\/?think>/).count == 1 {
                        tempResponse += "\n</think>\n"
                    }

                    // properly close any code blocks
                    if tempResponse.matches(of: /```/).count % 2 == 1 {
                        tempResponse += "\n```\n"
                    } else {
                        // ... or add a visual separator
                        tempResponse += "\n\n---\n"
                    }

                    // mark response as cancelled
                    tempResponse += "\n_CANCELLED_"

                    lastMessage.response = tempResponse
                    activeChat.modifiedAt = .now
                    tempResponse = ""
                }
            } catch {
                self.error = .generate(error.localizedDescription)
            }
        }
    }
    
    private func generateTitle(_ ollamaKit: OllamaKit, activeChat: Chat) {
        var requestMessages = [OKChatRequestData.Message]()
        
        for message in messages {
            let userMessage = OKChatRequestData.Message(role: .user, content: message.prompt)
            let assistantMessage = OKChatRequestData.Message(role: .assistant, content: message.response ?? "")
            
            requestMessages.append(userMessage)
            requestMessages.append(assistantMessage)
        }
        
        let userMessage = OKChatRequestData.Message(role: .user, content: "Just reply with a short title about this conversation. One line maximum. No markdown.")
        requestMessages.append(userMessage)
        
        generationTask = Task {
            defer { self.loading = nil }
            
            activeChat.name = "New Chat"
            var title: String = ""
            do {
                var isReasoningContent = false
                
                for try await chunk in ollamaKit.chat(data: OKChatRequestData(model: activeChat.model, messages: requestMessages)) {
                    if Task.isCancelled { break }
                    
                    guard let content = chunk.message?.content else { continue }
                    
                    if content.contains("<think>") {
                        isReasoningContent = true
                        continue
                    }
                    
                    if content.contains("</think>") {
                        isReasoningContent = false
                        continue
                    }
                    
                    if !isReasoningContent {
                        title += content
                        if title.isEmpty == false {
                            activeChat.name = title.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
                        }
                    }
                    
                    if chunk.done {
                        activeChat.modifiedAt = .now
                    }
                }
            } catch {
                self.error = .generateTitle(error.localizedDescription)
            }
        }
    }
    
    func cancelGeneration() {
        self.generationTask?.cancel()
        self.loading = .generate
    }
}

enum MessageViewModelLoading {
    case load
    case generate
}

enum MessageViewModelError: Error {
    case load(String)
    case generate(String)
    case generateTitle(String)
}

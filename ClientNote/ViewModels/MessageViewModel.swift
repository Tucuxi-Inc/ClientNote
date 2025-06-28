//
//  MessageViewModel.swift
//
//
//  Created by Kevin Hermawan on 13/07/24.
//

import Foundation
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
        print("DEBUG: MessageViewModel.load() called")
        
        // Clear current messages and state
        self.messages = []
        self.tempResponse = ""
        self.loading = nil
        self.error = nil
        
        guard let chat = chat else { 
            print("DEBUG: MessageViewModel - No chat provided, returning")
            return 
        }
        
        print("DEBUG: MessageViewModel - Loading chat: \(chat.id)")
        print("DEBUG: MessageViewModel - Chat has \(chat.messages.count) messages directly attached")
        
        let chatId = chat.id
        let predicate = #Predicate<Message> { $0.chat?.id == chatId }
        let sortDescriptor = SortDescriptor(\Message.createdAt)
        let fetchDescriptor = FetchDescriptor<Message>(predicate: predicate, sortBy: [sortDescriptor])
        
        self.loading = .load
        
        do {
            defer { self.loading = nil }
            let fetchedMessages = try self.modelContext.fetch(fetchDescriptor)
            print("DEBUG: MessageViewModel - Fetched \(fetchedMessages.count) messages from database")
            
            for (index, message) in fetchedMessages.enumerated() {
                print("DEBUG: MessageViewModel - Fetched message \(index + 1): prompt='\(String(message.prompt.prefix(50)))...', hasResponse=\(message.response != nil)")
            }
            
            self.messages = fetchedMessages
            print("DEBUG: MessageViewModel - Final message count: \(self.messages.count)")
        } catch {
            print("DEBUG: MessageViewModel - Error loading messages: \(error)")
            self.error = .load(error.localizedDescription)
        }
    }
    
    func generate(activeChat: Chat, prompt: String, modelPrompt: String? = nil) {
        // Create a message with the display prompt (without PIRP instructions)
        let message = Message(prompt: prompt)
        message.chat = activeChat
        messages.append(message)
        modelContext.insert(message)
        
        // CRITICAL: Set loading state and clear tempResponse immediately for thinking indicator
        self.loading = .generate
        self.tempResponse = "" // Clear any previous streaming content
        self.error = nil
        
        generationTask = Task {
            defer { 
                Task { @MainActor in
                    self.loading = nil
                    self.tempResponse = "" // Clear temp response when done
                }
            }
            
            do {
                guard let chatViewModel = self.chatViewModel else {
                    throw MessageViewModelError.generate("ChatViewModel not available")
                }
                
                // Clear tempResponse again just before starting to ensure clean state
                await MainActor.run {
                    self.tempResponse = ""
                }
                
                let response = try await chatViewModel.generateAIResponse(
                    prompt: prompt,
                    systemPrompt: modelPrompt ?? activeChat.systemPrompt
                ) { partialContent in
                    // Handle streaming updates
                    Task { @MainActor in
                        self.tempResponse += partialContent
                    }
                }
                
                await MainActor.run {
                    message.response = response
                    activeChat.modifiedAt = .now
                    
                    // Clear temp response since we now have the final response
                    self.tempResponse = ""
                    
                    // Save to activity if this is part of an activity
                    self.chatViewModel?.saveActivityContent()
                }
                
            } catch {
                await MainActor.run {
                    print("DEBUG: MessageViewModel generation failed: \(error)")
                self.error = .generate(error.localizedDescription)
                    self.tempResponse = "" // Clear temp response on error
                }
            }
        }
    }
    
    func regenerate(activeChat: Chat) {
        guard let lastMessage = messages.last else { return }
        lastMessage.response = nil
        
        // CRITICAL: Set loading state and clear tempResponse immediately for thinking indicator
        self.loading = .generate
        self.tempResponse = "" // Clear any previous streaming content
        self.error = nil
        
        generationTask = Task {
            defer { 
                Task { @MainActor in
                    self.loading = nil
                    self.tempResponse = "" // Clear temp response when done
                }
            }
            
            do {
                guard let chatViewModel = self.chatViewModel else {
                    throw MessageViewModelError.generate("ChatViewModel not available")
                }

                // Clear tempResponse again just before starting to ensure clean state
                await MainActor.run {
                    self.tempResponse = ""
                    }

                let response = try await chatViewModel.generateAIResponse(
                    prompt: lastMessage.prompt,
                    systemPrompt: activeChat.systemPrompt
                ) { partialContent in
                    // Handle streaming updates
                    Task { @MainActor in
                        self.tempResponse += partialContent
                    }
                }
                
                await MainActor.run {
                    lastMessage.response = response
                    activeChat.modifiedAt = .now
                    
                    // Clear temp response since we now have the final response
                    self.tempResponse = ""
                    
                    // Save to activity if this is part of an activity
                    self.chatViewModel?.saveActivityContent()
                }
                
            } catch {
                await MainActor.run {
                    print("DEBUG: MessageViewModel regenerate failed: \(error)")
                self.error = .generate(error.localizedDescription)
                    self.tempResponse = "" // Clear temp response on error
                }
            }
        }
    }
    
    private func generateTitle(activeChat: Chat) async throws {
        guard let chatViewModel = self.chatViewModel else {
            throw MessageViewModelError.generate("ChatViewModel not available")
        }
        
        // Build conversation context
        var conversationSummary = ""
        for message in messages {
            conversationSummary += "User: \(message.prompt)\n"
            conversationSummary += "Assistant: \(message.response ?? "")\n\n"
        }
        
        let titlePrompt = "\(conversationSummary)\n\nGenerate a short, descriptive title for this conversation. One line maximum. No markdown or quotes."
        
        let title = try await chatViewModel.generateAIResponse(
            prompt: titlePrompt,
            systemPrompt: "You are a helpful assistant that creates concise, descriptive titles."
        ) { _ in /* No streaming needed for titles */ }
        
        activeChat.name = title.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        
        do {
            try modelContext.save()
            } catch {
            print("DEBUG: Failed to save title: \(error)")
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
    
    var localizedDescription: String {
        switch self {
        case .load(let message):
            return message
        case .generate(let message):
            return message
        }
    }
}

import Defaults
import OllamaKit
import SwiftData
import SwiftUI
import Foundation

@MainActor
@Observable
final class ChatViewModel {
    private var modelContext: ModelContext
    private var _chatNameTemp: String = ""
    private weak var messageViewModel: MessageViewModel?
    
    var models: [String] = []
    
    var chats: [Chat] = []
    var activeChat: Chat? = nil
    var selectedChats = Set<Chat>()

    var shouldFocusPrompt = false

    var isHostReachable: Bool = true
    var loading: ChatViewModelLoading? = nil
    var error: ChatViewModelError? = nil
    
    var isRenameChatPresented = false
    var isDeleteConfirmationPresented = false
    
    // Shared state for selected client and task
    var selectedClientID: UUID? = nil
    var selectedTask: String = "Create a Client Session Note"
    
    // File-based persistence for clients
    var clients: [Client] = []
    
    // Activity type selection for filtering
    var selectedActivityType: ActivityType = .sessionNote
    
    // Selected activity tracking
    var selectedActivityID: UUID? = nil
    
    // Computed property: selected activity
    var selectedActivity: ClientActivity? {
        guard let selectedClientIndex = clients.firstIndex(where: { $0.id == selectedClientID }),
              let selectedActivityID = selectedActivityID else {
            return nil
        }
        return clients[selectedClientIndex].activities.first { $0.id == selectedActivityID }
    }
    
    // Computed property: filtered and sorted activities for the selected client and activity type
    var filteredActivities: [ClientActivity] {
        guard let client = selectedClient else { return [] }
        let activities = client.activities
        
        // If "All" is selected, return all activities
        if selectedActivityType == .all {
            return activities.sorted { $0.date > $1.date }
        }
        
        // Otherwise filter by type
        return activities
            .filter { $0.type == selectedActivityType }
            .sorted { $0.date > $1.date }
    }
    
    private var clientsDirectory: URL {
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let dir = urls[0].appendingPathComponent("Clients", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    func loadClients() {
        let dir = clientsDirectory
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        var loaded: [Client] = []
        for file in files where file.pathExtension == "json" {
            if let data = try? Data(contentsOf: file),
               let client = try? JSONDecoder().decode(Client.self, from: data) {
                loaded.append(client)
            }
        }
        self.clients = loaded
    }
    
    func saveClient(_ client: Client) {
        let file = clientsDirectory.appendingPathComponent("client_\(client.identifier).json")
        if let data = try? JSONEncoder().encode(client) {
            try? data.write(to: file)
        }
    }
    
    func addClient(_ client: Client) {
        clients.append(client)
        saveClient(client)
        selectedClientID = client.id
    }
    
    func selectClient(by id: UUID) {
        selectedClientID = id
    }
    
    var selectedClient: Client? {
        clients.first(where: { $0.id == selectedClientID })
    }
    
    var chatNameTemp: String {
        get {
            if isRenameChatPresented, let activeChat {
                return activeChat.name
            }
            
            return _chatNameTemp
        }
        
        set {
            _chatNameTemp = newValue
        }
    }
    
    init(modelContext: ModelContext, messageViewModel: MessageViewModel? = nil) {
        self.modelContext = modelContext
        self.messageViewModel = messageViewModel
        loadClients()
    }
    
    func setMessageViewModel(_ viewModel: MessageViewModel) {
        self.messageViewModel = viewModel
    }
    
    func fetchModels(_ ollamaKit: OllamaKit) {
        self.loading = .fetchModels
        self.error = nil
        
        Task {
            do {
                defer { self.loading = nil }
                
                let isReachable = await ollamaKit.reachable()
                
                guard isReachable else {
                    self.error = .fetchModels("Unable to connect to Ollama server. Please verify that Ollama is running and accessible.")
                    return
                }
                
                let response = try await ollamaKit.models()
                self.models = response.models.map { $0.name }
                
                guard !self.models.isEmpty else {
                    self.error = .fetchModels("You don't have any Ollama model. Please pull at least one Ollama model first.")
                    return
                }
                
                if let host = activeChat?.host, host.isEmpty {
                    self.activeChat?.host = self.models.first
                }
            } catch {
                self.error = .fetchModels(error.localizedDescription)
            }
        }
    }
    
    func load() {
        do {
            let sortDescriptor = SortDescriptor(\Chat.modifiedAt, order: .reverse)
            let fetchDescriptor = FetchDescriptor<Chat>(sortBy: [sortDescriptor])
            
            self.chats = try self.modelContext.fetch(fetchDescriptor)
        } catch {
            self.error = .load(error.localizedDescription)
        }
    }
    
    func create(model: String) {
        let chat = Chat(model: model)
        self.modelContext.insert(chat)
        
        self.chats.insert(chat, at: 0)
        self.selectedChats = [chat]
        self.shouldFocusPrompt = true
    }
    
    func rename() {
        guard let activeChat else { return }
        
        if let index = self.chats.firstIndex(where: { $0.id == activeChat.id }) {
            self.chats[index].name = _chatNameTemp
            self.chats[index].modifiedAt = .now
        }
    }
    
    func remove() {
        for chat in selectedChats {
            self.modelContext.delete(chat)
            self.chats.removeAll(where: { $0.id == chat.id })
        }
    }
    
    func removeTemporaryChat(chatToRemove: Chat) {
        if (chatToRemove.name == Defaults[.defaultChatName] && chatToRemove.messages.isEmpty) {
            self.modelContext.delete(chatToRemove)
            self.chats.removeAll(where: { $0.id == chatToRemove.id })
        }
    }
    
    // Load chat history for a selected activity
    func loadActivityChat(_ activity: ClientActivity) {
        print("DEBUG: Loading chat for activity: \(activity.id)")
        
        // Remove any existing chat
        if let activeChat = activeChat {
            modelContext.delete(activeChat)
            chats.removeAll(where: { $0.id == activeChat.id })
        }
        
        // Create a new chat with the activity's content
        let chat = Chat(model: Defaults[.defaultModel])
        chat.systemPrompt = getSystemPromptForActivityType(activity.type)
        
        // Parse the stored content into messages
        if !activity.content.isEmpty {
            do {
                guard let contentData = activity.content.data(using: .utf8) else {
                    print("DEBUG: Could not convert content to data")
                    return
                }
                
                let chatHistory = try JSONDecoder().decode([[String: String]].self, from: contentData)
                print("DEBUG: Found \(chatHistory.count) messages in history")
                
                for messageData in chatHistory {
                    if let prompt = messageData["prompt"] {
                        let message = Message(prompt: prompt)
                        message.chat = chat
                        message.response = messageData["response"]
                        chat.messages.append(message)
                    }
                }
            } catch {
                print("DEBUG: Error parsing chat history: \(error)")
                // Handle legacy content format or invalid data
                let message = Message(prompt: activity.content)
                message.chat = chat
                chat.messages.append(message)
            }
        }
        
        modelContext.insert(chat)
        chats.insert(chat, at: 0)
        activeChat = chat
        
        // Tell MessageViewModel to load this chat's messages
        messageViewModel?.load(of: chat)
    }
    
    // Watch for activity selection changes
    func onActivitySelected() {
        if let activity = selectedActivity {
            // Update the selected task to match the activity type
            selectedTask = taskForActivityType(activity.type)
            
            // Clear current chat and create new one for this activity
            loadActivityChat(activity)
        }
    }
    
    // Save chat content to activity
    func saveActivityContent() {
        guard let activity = selectedActivity,
              let clientIndex = clients.firstIndex(where: { $0.id == selectedClientID }),
              let activityIndex = clients[clientIndex].activities.firstIndex(where: { $0.id == activity.id }),
              let chat = activeChat else {
            print("DEBUG: Cannot save activity content - missing required data")
            return
        }
        
        // Create an array of message dictionaries
        let messageHistory = chat.messages.map { message -> [String: String] in
            var messageData: [String: String] = ["prompt": message.prompt]
            if let response = message.response {
                messageData["response"] = response
            }
            return messageData
        }
        
        do {
            let jsonData = try JSONEncoder().encode(messageHistory)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("DEBUG: Saving chat history with \(messageHistory.count) messages")
                clients[clientIndex].activities[activityIndex].content = jsonString
                saveClient(clients[clientIndex])
            }
        } catch {
            print("DEBUG: Error saving chat history: \(error)")
        }
    }
    
    // Create a new activity and associated chat
    func createNewActivity() {
        guard let clientIndex = clients.firstIndex(where: { $0.id == selectedClientID }) else { return }
        
        // Get activity type from selected task
        let type = getActivityTypeFromTask(selectedTask)
        
        // Generate a unique title for the new activity
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        let defaultTitle = "\(type.rawValue) - \(dateFormatter.string(from: Date()))"
        
        // Count existing activities of this type today
        let today = Calendar.current.startOfDay(for: Date())
        let activitiesOfTypeToday = clients[clientIndex].activities.filter { activity in
            activity.type == type && 
            Calendar.current.isDate(activity.date, inSameDayAs: today)
        }
        
        // If there are other activities today, append a number
        let title = activitiesOfTypeToday.isEmpty ? defaultTitle :
            "\(defaultTitle) (\(activitiesOfTypeToday.count + 1))"
        
        let newActivity = ClientActivity(
            type: type,
            date: Date(),
            content: "",
            title: title
        )
        
        // Create a new chat for this activity
        let chat = Chat(model: Defaults[.defaultModel])
        chat.systemPrompt = getSystemPromptForActivityType(type)
        modelContext.insert(chat)
        chats.insert(chat, at: 0)
        activeChat = chat
        
        // Add and select the new activity
        clients[clientIndex].activities.insert(newActivity, at: 0)
        saveClient(clients[clientIndex])
        selectedActivityID = newActivity.id
    }
    
    private func getActivityTypeFromTask(_ task: String) -> ActivityType {
        switch task {
        case "Create a Client Session Note":
            return .sessionNote
        case "Create a Treatment Plan":
            return .treatmentPlan
        case "Brainstorm":
            return .brainstorm
        default:
            return .sessionNote
        }
    }
    
    private func taskForActivityType(_ type: ActivityType) -> String {
        switch type {
        case .sessionNote:
            return "Create a Client Session Note"
        case .treatmentPlan:
            return "Create a Treatment Plan"
        case .brainstorm:
            return "Brainstorm"
        case .all:
            return "Create a Client Session Note"
        }
    }
    
    private func getSystemPromptForActivityType(_ type: ActivityType) -> String {
        switch type {
        case .sessionNote:
            return """
            You're Euni™ - Client Notes. You are a clinical documentation assistant helping a therapist generate an insurance-ready psychotherapy progress note. You will use the information provided to you here to write a psychotherapy progress note using (unless otherwise instructed by the user) the BIRP format (Behavior, Intervention, Response, Plan).
            Requirements:
            - Use clear, objective, and concise clinical language
            - Maintain gender-neutral pronouns
            - Do not make up quotes - only use exact quotes if and when provided by the user
            - Focus on observable behaviors, reported thoughts and feelings, therapist interventions, and clinical goals
            - Apply relevant approaches and techniques, including typical interventions and session themes
            - Use documentation language suitable for EHRs and insurance billing
            - If schemas, distortions, or core beliefs are addressed, name them using standard psychological terms
            - Conclude with a brief, action-oriented treatment plan
            """
        case .treatmentPlan:
            return """
            You're Euni™ - Client Notes. You are a clinical documentation assistant helping a therapist generate a comprehensive treatment plan. Focus on creating a structured, goal-oriented treatment plan that meets clinical and insurance requirements.
            Requirements:
            - Include clear treatment goals and objectives
            - Specify measurable outcomes
            - List specific interventions and therapeutic techniques
            - Include timeframes for goal achievement
            - Address presenting problems identified in the assessment
            - Consider client's strengths and resources
            - Include both short-term and long-term goals
            - Ensure goals are realistic and achievable
            """
        case .brainstorm:
            return """
            You're Euni™ - Client Notes. You are a clinical brainstorming assistant helping a therapist explore therapeutic approaches, interventions, and treatment strategies. Focus on generating creative yet evidence-based ideas while maintaining clinical appropriateness.
            Requirements:
            - Suggest evidence-based interventions
            - Consider multiple therapeutic approaches
            - Provide rationale for suggestions
            - Keep client's specific needs in mind
            - Include practical implementation steps
            - Consider potential challenges and solutions
            - Maintain clinical appropriateness
            - Reference relevant research or theoretical frameworks when applicable
            """
        case .all:
            return Defaults[.defaultSystemPrompt]
        }
    }
}

enum ChatViewModelLoading {
    case fetchModels
}

enum ChatViewModelError: Error {
    case fetchModels(String)
    case load(String)
}

import Defaults
import OllamaKit
import SwiftData
import SwiftUI
import Foundation

/// ChatViewModel is the central coordinator for the Euni™ Client Notes application.
/// It manages client data, activities, chat interactions, and integration with the Ollama AI service.
///
/// Key responsibilities:
/// - Client management (adding, selecting, saving clients)
/// - Activity tracking (session notes, treatment plans, brainstorming)
/// - Chat interaction with Ollama AI
/// - Note format management and template handling
/// - Therapeutic modality analysis and engagement tracking
///
/// The ViewModel follows a file-based persistence model for client data and
/// integrates with SwiftData for chat history management.
@MainActor
@Observable
final class ChatViewModel {
    // MARK: - Private Properties
    
    /// The SwiftData context for managing persistent storage
    private var modelContext: ModelContext
    
    /// Temporary storage for chat renaming operations
    private var _chatNameTemp: String = ""
    
    /// Reference to the message handling view model
    private weak var messageViewModel: MessageViewModel?
    
    // MARK: - Public Properties
    
    /// Available AI models from Ollama
    var models: [String] = []
    
    /// Collection of all chat sessions
    var chats: [Chat] = []
    
    /// Currently active chat session
    var activeChat: Chat? = nil
    
    /// Set of currently selected chats (for multi-select operations)
    var selectedChats = Set<Chat>()
    
    /// Flag to control input field focus
    var shouldFocusPrompt = false
    
    /// Indicates if the Ollama host is reachable
    var isHostReachable: Bool = true
    
    /// Current loading state
    var loading: ChatViewModelLoading? = nil
    
    /// Current error state
    var error: ChatViewModelError? = nil
    
    /// UI state for chat renaming
    var isRenameChatPresented = false
    
    /// UI state for deletion confirmation
    var isDeleteConfirmationPresented = false
    
    // MARK: - Client and Activity State
    
    /// Currently selected client's ID
    var selectedClientID: UUID? = nil
    
    /// Currently selected task type
    var selectedTask: String = "Create a Client Session Note"
    
    /// Collection of all clients
    var clients: [Client] = []
    
    /// Currently selected activity type filter
    var selectedActivityType: ActivityType = .sessionNote
    
    /// Currently selected activity's ID
    var selectedActivityID: UUID? = nil
    
    // MARK: - Note Format Properties
    
    /// Currently selected note format (e.g., "BIRP", "SOAP")
    var selectedNoteFormat: String = "PIRP"
    
    /// Custom template for note formatting
    var noteFormatTemplate: String = ""
    
    // MARK: - Note Format Definitions
    
    /// Represents a clinical note format with its structure and usage guidelines
    struct NoteFormat: Identifiable {
        /// Unique identifier for the format (e.g., "SOAP", "BIRP")
        let id: String
        /// Full name of the format
        let name: String
        /// Primary use case or focus area
        let focus: String
        /// Detailed description of the format's structure and usage
        let description: String
    }
    
    /// Available clinical note formats with their descriptions and guidelines
    let availableNoteFormats: [NoteFormat] = [
        NoteFormat(
            id: "SOAP",
            name: "Subjective, Objective, Assessment, Plan",
            focus: "Widely used; insurance-friendly",
            description: """
                SOAP is a widely-used format that breaks down notes into:
                • Subjective: Client's reported symptoms and experiences
                • Objective: Observable facts and measurements
                • Assessment: Clinical interpretation and diagnosis
                • Plan: Treatment plan and next steps
                """
        ),
        NoteFormat(
            id: "DAP",
            name: "Data, Assessment, Plan",
            focus: "Streamlined alternative to SOAP",
            description: """
                DAP simplifies documentation into:
                • Data: Both subjective and objective information
                • Assessment: Clinical interpretation
                • Plan: Treatment direction and interventions
                """
        ),
        NoteFormat(
            id: "BIRP",
            name: "Behavior, Intervention, Response, Plan",
            focus: "Emphasizes behavior change",
            description: """
                BIRP focuses on behavioral aspects:
                • Behavior: Client's actions and statements
                • Intervention: Therapist's techniques and approaches
                • Response: Client's reaction to interventions
                • Plan: Next steps in treatment
                """
        ),
        NoteFormat(
            id: "PIRP",
            name: "Problem, Intervention, Response, Plan",
            focus: "Similar to BIRP with \"Problem\" first",
            description: """
                PIRP emphasizes problem-solving:
                • Problem: Current issues and concerns
                • Intervention: Therapeutic techniques used
                • Response: Client's reaction and progress
                • Plan: Future treatment direction
                """
        ),
        NoteFormat(
            id: "GIRP",
            name: "Goal, Intervention, Response, Plan",
            focus: "Highlights goals upfront",
            description: """
                GIRP emphasizes goal-oriented treatment:
                • Goal: Treatment objectives
                • Intervention: Methods used
                • Response: Client's progress
                • Plan: Next steps
                """
        ),
        NoteFormat(
            id: "SBAR",
            name: "Situation, Background, Assessment, Recommendation",
            focus: "Healthcare handoff, not therapy-specific",
            description: """
                SBAR structures communication:
                • Situation: Current client status
                • Background: Relevant history
                • Assessment: Clinical evaluation
                • Recommendation: Suggested actions
                """
        ),
        NoteFormat(
            id: "FOCUS",
            name: "Focus, Observe, Client Response, Utilize, Specify",
            focus: "Specialty rehab settings",
            description: """
                FOCUS is detailed and specific:
                • Focus: Treatment emphasis
                • Observe: Client presentation
                • Client Response: Progress and reactions
                • Utilize: Resources and methods
                • Specify: Detailed plans
                """
        )
    ]
    
    // MARK: - Initialization
    
    /// Initialize the ChatViewModel
    /// - Parameters:
    ///   - modelContext: SwiftData context for persistence
    ///   - messageViewModel: Optional message handling view model
    init(modelContext: ModelContext, messageViewModel: MessageViewModel? = nil) {
        self.modelContext = modelContext
        self.messageViewModel = messageViewModel
        loadClients()
    }
    
    /// Set the message view model after initialization
    /// - Parameter viewModel: The message handling view model
    func setMessageViewModel(_ viewModel: MessageViewModel) {
        self.messageViewModel = viewModel
    }
    
    // MARK: - Client Directory Management
    
    /// Directory where client files are stored
    private var clientsDirectory: URL {
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let dir = urls[0].appendingPathComponent("Clients", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    // MARK: - Client Management
    
    /// Loads all clients from persistent storage
    ///
    /// This method:
    /// 1. Reads client files from the documents directory
    /// 2. Deserializes JSON data into Client objects
    /// 3. Updates the clients array
    /// 4. Validates current selections
    /// 5. Handles any missing or invalid data
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
        
        // Validate selections after loading
        validateClientSelection()
        if let selectedID = selectedActivityID {
            // Check if the selected activity is still valid
            if !filteredActivities.contains(where: { $0.id == selectedID }) {
                print("DEBUG: Selected activity \(selectedID) no longer valid after loading clients")
                selectedActivityID = filteredActivities.first?.id
            }
        }
    }
    
    /// Saves a client's data to persistent storage
    /// - Parameter client: The client to save
    ///
    /// This method:
    /// 1. Encodes the client object to JSON
    /// 2. Writes the data to a file named with the client's identifier
    /// 3. Handles any serialization or file writing errors
    func saveClient(_ client: Client) {
        let file = clientsDirectory.appendingPathComponent("client_\(client.identifier).json")
        if let data = try? JSONEncoder().encode(client) {
            try? data.write(to: file)
        }
    }
    
    /// Adds a new client to the system
    /// - Parameter client: The new client to add
    ///
    /// This method:
    /// 1. Adds the client to the in-memory array
    /// 2. Saves the client to persistent storage
    /// 3. Updates the selected client to the new client
    func addClient(_ client: Client) {
        clients.append(client)
        saveClient(client)
        selectedClientID = client.id
    }
    
    /// Selects a client by their ID
    /// - Parameter id: The UUID of the client to select
    func selectClient(by id: UUID) {
        selectedClientID = id
    }
    
    /// Validates the current client selection
    ///
    /// This method ensures that:
    /// 1. The selected client still exists
    /// 2. If not, resets to the first available client
    /// 3. If no clients exist, clears the selection
    ///
    /// This is typically called after loading clients or
    /// when client data might have changed.
    func validateClientSelection() {
        if let selectedID = selectedClientID {
            // Check if the selected client still exists
            if !clients.contains(where: { $0.id == selectedID }) {
                print("DEBUG: Invalid client selection: \(selectedID)")
                // Reset to first available client or clear selection
                if let firstClient = clients.first {
                    selectedClientID = firstClient.id
                    print("DEBUG: Reset to first available client: \(firstClient.id)")
                } else {
                    selectedClientID = nil
                    print("DEBUG: No valid clients available")
                }
            }
        }
    }
    
    /// Deletes a client and all their associated data
    /// - Parameter clientID: The UUID of the client to delete
    ///
    /// This method:
    /// 1. Removes the client from memory
    /// 2. Deletes the client's file from storage
    /// 3. Updates selections if the deleted client was selected
    /// 4. Handles cleanup of associated data
    func deleteClient(_ clientID: UUID) {
        guard let clientIndex = clients.firstIndex(where: { $0.id == clientID }) else {
            return
        }
        
        // Get the client's file path
        let clientFile = clientsDirectory.appendingPathComponent("client_\(clients[clientIndex].identifier).json")
        
        // Remove from memory
        clients.remove(at: clientIndex)
        
        // Delete the file
        try? FileManager.default.removeItem(at: clientFile)
        
        // Reset selections if needed
        if selectedClientID == clientID {
            selectedClientID = clients.first?.id
        }
    }
    
    /// The currently selected activity for the active client
    /// - Returns: The ClientActivity object if both client and activity are selected, nil otherwise
    var selectedActivity: ClientActivity? {
        print("DEBUG: selectedActivity getter called")
        print("DEBUG: selectedClientID: \(selectedClientID?.uuidString ?? "nil")")
        print("DEBUG: selectedActivityID: \(selectedActivityID?.uuidString ?? "nil")")
        
        guard let selectedClientIndex = clients.firstIndex(where: { $0.id == selectedClientID }) else {
            print("DEBUG: selectedActivity - no client found for selectedClientID")
            return nil
        }
        
        guard let selectedActivityID = selectedActivityID else {
            print("DEBUG: selectedActivity - selectedActivityID is nil")
            return nil
        }
        
        print("DEBUG: selectedActivity - looking for activity in \(clients[selectedClientIndex].activities.count) activities")
        
        // Debug: list all activities
        for (index, act) in clients[selectedClientIndex].activities.enumerated() {
            print("DEBUG: Activity \(index + 1): id=\(act.id), type=\(act.type.rawValue), content_length=\(act.content.count)")
        }
        
        let activity = clients[selectedClientIndex].activities.first { $0.id == selectedActivityID }
        print("DEBUG: selectedActivity - found activity: \(activity?.id.uuidString ?? "nil")")
        if let activity = activity {
            print("DEBUG: selectedActivity - activity content length: \(activity.content.count)")
            print("DEBUG: selectedActivity - activity content preview: \(String(activity.content.prefix(100)))")
        }
        
        return activity
    }
    
    /// Filtered and sorted activities for the selected client and activity type
    /// - Returns: An array of activities filtered by type and sorted by date (newest first)
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
    
    /// The currently selected client
    /// - Returns: The Client object if one is selected, nil otherwise
    var selectedClient: Client? {
        clients.first(where: { $0.id == selectedClientID })
    }
    
    /// Temporary name for chat renaming operations
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
    
    // MARK: - Ollama Integration
    
    /// Fetches available AI models from the Ollama server
    /// - Parameter ollamaKit: The OllamaKit instance configured with the appropriate base URL
    ///
    /// This method performs several key operations:
    /// 1. Checks if the Ollama server is reachable
    /// 2. Retrieves the list of available models
    /// 3. Updates the UI state based on the results
    /// 4. Handles error conditions appropriately
    ///
    /// The method will set the following state:
    /// - `loading`: Indicates fetch progress
    /// - `error`: Contains any error information
    /// - `models`: Updated list of available models
    /// - `isHostReachable`: Indicates server availability
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
    
    /// Loads existing chat history from persistent storage
    ///
    /// This method:
    /// 1. Retrieves chats sorted by modification date (newest first)
    /// 2. Updates the `chats` array with the results
    /// 3. Handles any errors during the fetch operation
    func load() {
        do {
            let sortDescriptor = SortDescriptor(\Chat.modifiedAt, order: .reverse)
            let fetchDescriptor = FetchDescriptor<Chat>(sortBy: [sortDescriptor])
            
            self.chats = try self.modelContext.fetch(fetchDescriptor)
        } catch {
            self.error = .load(error.localizedDescription)
        }
    }
    
    /// Creates a new chat session with the specified AI model
    /// - Parameter model: The identifier of the Ollama model to use
    ///
    /// This method:
    /// 1. Creates a new Chat instance
    /// 2. Inserts it into persistent storage
    /// 3. Updates the UI state for the new chat
    /// 4. Sets focus to the prompt field
    func create(model: String) {
        let chat = Chat(model: model)
        self.modelContext.insert(chat)
        
        self.chats.insert(chat, at: 0)
        self.selectedChats = [chat]
        self.shouldFocusPrompt = true
    }
    
    /// Renames the active chat session
    ///
    /// This method:
    /// 1. Updates the chat name in memory
    /// 2. Updates the modification timestamp
    /// 3. Changes are automatically persisted via SwiftData
    func rename() {
        guard let activeChat else { return }
        
        if let index = self.chats.firstIndex(where: { $0.id == activeChat.id }) {
            self.chats[index].name = _chatNameTemp
            self.chats[index].modifiedAt = .now
        }
    }
    
    /// Removes selected chat sessions
    ///
    /// This method:
    /// 1. Deletes the chats from persistent storage
    /// 2. Updates the in-memory chat array
    /// 3. Handles multiple chat deletions in a single operation
    func remove() {
        for chat in selectedChats {
            self.modelContext.delete(chat)
            self.chats.removeAll(where: { $0.id == chat.id })
        }
    }
    
    /// Removes a temporary chat if it meets specific criteria
    /// - Parameter chatToRemove: The chat to potentially remove
    ///
    /// A chat is considered temporary if:
    /// - It has the default chat name
    /// - It contains no messages
    func removeTemporaryChat(chatToRemove: Chat) {
        if (chatToRemove.name == Defaults[.defaultChatName] && chatToRemove.messages.isEmpty) {
            self.modelContext.delete(chatToRemove)
            self.chats.removeAll(where: { $0.id == chatToRemove.id })
        }
    }
    
    // MARK: - Chat Loading and State Management
    
    /// Loads an existing activity's chat content
    /// - Parameter activity: The activity whose chat content should be loaded
    ///
    /// This method:
    /// 1. Saves current activity content if needed
    /// 2. Removes any existing active chat
    /// 3. Creates a new chat with appropriate system prompt
    /// 4. Loads and parses the activity's content
    /// 5. Updates the UI state for the new chat
    func loadActivityChat(_ activity: ClientActivity) {
        print("DEBUG: ===== loadActivityChat START =====")
        print("DEBUG: Loading chat for activity: \(activity.id) (\(activity.type.rawValue))")
        print("DEBUG: Activity title: \(activity.title ?? "nil")")
        print("DEBUG: Activity content length: \(activity.content.count)")
        
        // Save current activity content before switching
        if let currentActivity = selectedActivity, currentActivity.id != activity.id {
            print("DEBUG: Saving current activity (\(currentActivity.id)) content before switching")
            saveActivityContent()
        }
        
        // Remove any existing chat
        if let existingChat = activeChat {
            print("DEBUG: Removing existing chat: \(existingChat.id)")
            modelContext.delete(existingChat)
            chats.removeAll(where: { $0.id == existingChat.id })
        } else {
            print("DEBUG: No existing chat to remove")
        }
        
        // Create a new chat with the activity's content
        let chat = Chat(model: Defaults[.defaultModel])
        
        // Explicitly set the system prompt based on the activity type
        let type = activity.type
        chat.systemPrompt = getSystemPromptForActivityType(type)
        print("DEBUG: Set system prompt for activity type: \(type.rawValue)")
        
        // Parse the stored content into messages
        var messagesLoaded = 0
        if !activity.content.isEmpty {
            print("DEBUG: Activity has content, parsing...")
            print("DEBUG: Content preview: \(String(activity.content.prefix(200)))...")
            
            guard let contentData = activity.content.data(using: .utf8) else {
                print("DEBUG: ERROR - Could not convert content to data")
                return
            }
            
            // Try to decode as JSON array first (new format)
            do {
                let chatHistory = try JSONDecoder().decode([[String: String]].self, from: contentData)
                print("DEBUG: Successfully decoded JSON chat history with \(chatHistory.count) entries")
                
                // Load messages directly without additional filtering since saveActivityContent already filtered
                for (index, messageData) in chatHistory.enumerated() {
                    if let prompt = messageData["prompt"], !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        print("DEBUG: Loading message \(index + 1): \(String(prompt.prefix(50)))...")
                        
                        let message = Message(prompt: prompt)
                        message.chat = chat
                        message.response = messageData["response"]
                        chat.messages.append(message)
                        messagesLoaded += 1
                        print("DEBUG: Added message with response: \(message.response != nil)")
                    } else {
                        print("DEBUG: Message \(index + 1) has empty prompt, skipping")
                    }
                }
            } catch {
                print("DEBUG: JSON parsing failed, checking for legacy format: \(error)")
                
                // Handle legacy content format - treat entire content as a single user message
                // This handles cases where old activities might have been saved differently
                let trimmedContent = activity.content.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedContent.isEmpty {
                    // Check if this looks like a user prompt (not a system prompt or analysis)
                    let isUserContent = !trimmedContent.hasPrefix("You are a clinical documentation assistant") &&
                                       !trimmedContent.contains("Consider these common patterns of client engagement") &&
                                       !trimmedContent.hasPrefix("AVAILABLE CLIENT CONTEXT:")
                    
                    if isUserContent {
                        let message = Message(prompt: trimmedContent)
                        message.chat = chat
                        chat.messages.append(message)
                        messagesLoaded = 1
                        print("DEBUG: Created single legacy message from content")
                    } else {
                        print("DEBUG: Legacy content appears to be system/analysis content, not loading as user message")
                    }
                } else {
                    print("DEBUG: Legacy content is empty after trimming")
                }
            }
        } else {
            print("DEBUG: Activity has no content (empty)")
        }
        
        print("DEBUG: Total messages loaded: \(messagesLoaded)")
        print("DEBUG: Chat messages count: \(chat.messages.count)")
        
        modelContext.insert(chat)
        chats.insert(chat, at: 0)
        activeChat = chat
        print("DEBUG: Set activeChat to: \(chat.id)")
        
        // Tell MessageViewModel to load this chat's messages
        messageViewModel?.load(of: chat)
        print("DEBUG: MessageViewModel loaded with \(messageViewModel?.messages.count ?? 0) messages")
        
        // Make sure the selected task matches the activity type
        let oldTask = selectedTask
        selectedTask = taskForActivityType(activity.type)
        print("DEBUG: Updated selectedTask from '\(oldTask)' to '\(selectedTask)'")
        
        // Ensure this activity is marked as selected
        if selectedActivityID != activity.id {
            print("DEBUG: Setting selectedActivityID to match loaded activity: \(activity.id)")
            selectedActivityID = activity.id
        }
        
        print("DEBUG: Final state - selectedActivityID: \(selectedActivityID?.uuidString ?? "nil")")
        print("DEBUG: Final state - selectedActivity: \(selectedActivity?.id.uuidString ?? "nil")")
        print("DEBUG: ===== loadActivityChat END =====")
    }
    
    /// Determines if a prompt is an analysis prompt that shouldn't be displayed
    /// - Parameter prompt: The prompt to check
    /// - Returns: True if this is an analysis prompt
    private func isAnalysisPrompt(_ prompt: String) -> Bool {
        // This method is deprecated in favor of more specific filtering in saveActivityContent
        // Keeping for backwards compatibility but returning false to avoid over-filtering
        return false
    }
    
    /// Handles the action to generate a response from the AI
    /// - Parameters:
    ///   - prompt: The user's prompt
    ///   - noteFormat: Optional note format override (for EasyNote)
    ///   - providedModalities: Optional pre-selected modalities (for EasyNote)
    /// This method creates a message and triggers response generation
    func handleGenerateAction(prompt: String, noteFormat: String? = nil, providedModalities: [String: [String]]? = nil) {
        guard let activeChat = activeChat else { return }
        
        let activityType = getActivityTypeFromTask(selectedTask)
        print("DEBUG: Generating with activity type: \(activityType.rawValue)")
        
        // For brainstorm activities, use simple generation
        if activityType == .brainstorm {
            print("DEBUG: ===== BRAINSTORM GENERATION START =====")
            print("DEBUG: Using simple generation for Brainstorm")
            print("DEBUG: selectedTask: '\(selectedTask)'")
            print("DEBUG: activityType: \(activityType.rawValue)")
            
            let expectedPrompt = getSystemPromptForActivityType(activityType)
            print("DEBUG: Expected brainstorm prompt: \(String(expectedPrompt.prefix(100)))...")
            print("DEBUG: Current activeChat systemPrompt: \(String(activeChat.systemPrompt?.prefix(100) ?? "nil")...)") 
            
            // CRITICAL: Ensure we're using the clean brainstorm prompt
            activeChat.systemPrompt = expectedPrompt
            print("DEBUG: Set activeChat systemPrompt to brainstorm prompt")
            
            // CRITICAL: Clear all previous messages to prevent contamination
            // This ensures brainstorm doesn't see treatment plan or session note history
            print("DEBUG: Clearing \(activeChat.messages.count) previous messages for clean brainstorm")
            for message in activeChat.messages {
                modelContext.delete(message)
            }
            activeChat.messages.removeAll()
            print("DEBUG: Chat messages cleared - starting with clean slate")
            
            // Update MessageViewModel to reflect the cleared state
            messageViewModel?.load(of: activeChat)
            
            // Verify the prompt was set correctly
            if let currentPrompt = activeChat.systemPrompt {
                print("DEBUG: Verification - systemPrompt length: \(currentPrompt.count)")
                print("DEBUG: Verification - systemPrompt starts with: '\(String(currentPrompt.prefix(50)))...'")
                
                // Check if it contains therapeutic modality content (which it shouldn't for brainstorm)
                let containsTherapeuticContent = currentPrompt.contains("therapeutic") || 
                                               currentPrompt.contains("modalities") ||
                                               currentPrompt.contains("clinical documentation")
                print("DEBUG: Contains therapeutic content: \(containsTherapeuticContent)")
                
                if containsTherapeuticContent {
                    print("DEBUG: WARNING - Brainstorm prompt contains therapeutic content!")
                    print("DEBUG: Full prompt: \(currentPrompt)")
                }
            }
            
            // Create message and generate normally
            let message = Message(prompt: prompt)
            message.chat = activeChat
            activeChat.messages.append(message)
            
            print("DEBUG: Created brainstorm message with prompt: '\(String(prompt.prefix(100)))...'")
            print("DEBUG: Chat now has \(activeChat.messages.count) messages (should be 1)")
            print("DEBUG: Calling messageViewModel.generate() for brainstorm")
            
            messageViewModel?.generate(activeChat: activeChat, prompt: prompt)
            saveActivityContent()
            
            print("DEBUG: ===== BRAINSTORM GENERATION END =====")
            return
        }
        
        // For treatment plans, use streaming generation (single pass, not two-pass like session notes)
        if activityType == .treatmentPlan {
            print("DEBUG: ===== TREATMENT PLAN GENERATION START =====")
            print("DEBUG: Using streaming generation for Treatment Plan")
            print("DEBUG: selectedTask: '\(selectedTask)'")
            print("DEBUG: activityType: \(activityType.rawValue)")
            
            let expectedPrompt = getSystemPromptForActivityType(activityType)
            print("DEBUG: Expected treatment plan prompt: \(String(expectedPrompt.prefix(100)))...")
            print("DEBUG: Current activeChat systemPrompt: \(String(activeChat.systemPrompt?.prefix(100) ?? "nil")...)")
            
            // Set the proper treatment plan system prompt
            activeChat.systemPrompt = expectedPrompt
            print("DEBUG: Set activeChat systemPrompt to treatment plan prompt")
            
            // CRITICAL: Clear all previous messages to prevent contamination
            // This ensures treatment plans don't see session note or brainstorm history
            print("DEBUG: Clearing \(activeChat.messages.count) previous messages for clean treatment plan")
            for message in activeChat.messages {
                modelContext.delete(message)
            }
            activeChat.messages.removeAll()
            print("DEBUG: Chat messages cleared for treatment plan - starting with clean slate")
            
            // Update MessageViewModel to reflect the cleared state
            messageViewModel?.load(of: activeChat)
            
            // Create user message first (this is what will be displayed)
            let userMessage = Message(prompt: prompt)
            userMessage.chat = activeChat
            activeChat.messages.append(userMessage)
            
            // Update MessageViewModel immediately to show the user message
            messageViewModel?.load(of: activeChat)
            
            // Set initial loading state
            messageViewModel?.loading = .generate
            
            // Start streaming generation for treatment plan
            Task {
                do {
                    print("DEBUG: Starting treatment plan streaming generation")
                    
                    // Get OllamaKit instance
                    guard let host = activeChat.host,
                          let baseURL = URL(string: host) else {
                        throw ChatViewModelError.generate("Invalid host configuration")
                    }
                    
                    let ollamaKit = OllamaKit(baseURL: baseURL)
                    
                    // Get client context for treatment plan
                    let clientContext = getClientContext()
                    
                    // Generate treatment plan with streaming feedback
                    let treatmentPlan = try await generateAnalysisWithStreaming(prompt: """
                        AVAILABLE CLIENT CONTEXT:
                        \(clientContext)
                        
                        USER REQUEST:
                        \(prompt)
                        
                        Please create a comprehensive treatment plan using the structured format outlined in the system prompt. Follow the 7-section format exactly and provide detailed, clinically appropriate content for each section.
                        """, ollamaKit: ollamaKit)
                    
                    await MainActor.run {
                        userMessage.response = treatmentPlan
                        activeChat.modifiedAt = .now
                        
                        // Clear loading state
                        messageViewModel?.loading = nil
                        
                        // Update MessageViewModel to reflect the completed message
                        messageViewModel?.load(of: activeChat)
                        
                        // Save the activity content
                        saveActivityContent()
                        
                        print("DEBUG: Treatment plan generation completed successfully")
                    }
                    
                } catch {
                    await MainActor.run {
                        print("DEBUG: Treatment plan generation failed: \(error)")
                        messageViewModel?.loading = nil
                        messageViewModel?.tempResponse = ""
                        self.error = .generate("Treatment plan generation failed: \(error.localizedDescription)")
                        
                        // Provide a fallback response
                        let fallbackResponse = """
                        **Treatment Plan Generation Error**
                        
                        The treatment plan generation failed: \(error.localizedDescription)
                        
                        **Original Input:**
                        \(prompt)
                        
                        **Suggested Action:**
                        Please try regenerating this treatment plan or check your connection to Ollama.
                        """
                        
                        userMessage.response = fallbackResponse
                        messageViewModel?.load(of: activeChat)
                        saveActivityContent()
                    }
                }
            }
            
            print("DEBUG: ===== TREATMENT PLAN GENERATION END =====")
            return
        }
        
        // For session notes only, use two-pass generation
        print("DEBUG: Using two-pass generation for \(activityType.rawValue)")
        
        // Get OllamaKit instance
        guard let host = activeChat.host,
              let baseURL = URL(string: host) else {
            print("DEBUG: Invalid host URL for OllamaKit")
            self.error = .generate("Invalid host configuration")
            return
        }
        
        let ollamaKit = OllamaKit(baseURL: baseURL)
        
        // CRITICAL: Clear all previous messages to prevent contamination
        // This ensures session notes don't see treatment plan or brainstorm history
        print("DEBUG: Clearing \(activeChat.messages.count) previous messages for clean session note")
        for message in activeChat.messages {
            modelContext.delete(message)
        }
        activeChat.messages.removeAll()
        print("DEBUG: Chat messages cleared for session note - starting with clean slate")
        
        // Update MessageViewModel to reflect the cleared state
        messageViewModel?.load(of: activeChat)
        
        // Create the user message first (this is what will be displayed)
        let userMessage = Message(prompt: prompt)
        userMessage.chat = activeChat
        activeChat.messages.append(userMessage)
        
        // Update MessageViewModel immediately to show the user message
        messageViewModel?.load(of: activeChat)
        
        // Set initial loading state (will be updated during streaming)
        messageViewModel?.loading = .generate
        
        // Start the two-pass generation process
        Task {
            do {
                print("DEBUG: Starting two-pass generation process")
                
                // Perform two-pass generation internally without creating additional messages
                let finalNote = try await performTwoPassGeneration(
                    userInput: prompt,
                    ollamaKit: ollamaKit,
                    isEasyNote: noteFormat != nil,
                    providedModalities: providedModalities,
                    noteFormat: noteFormat
                )
                
                // Update the user message with the generated response
                await MainActor.run {
                    userMessage.response = finalNote
                    activeChat.modifiedAt = .now
                    
                    // Clear loading state (streaming will have already cleared tempResponse)
                    messageViewModel?.loading = nil
                    
                    // Update MessageViewModel to reflect the completed message
                    messageViewModel?.load(of: activeChat)
                    
                    // Save the activity content
                    saveActivityContent()
                    
                    print("DEBUG: Two-pass generation completed successfully")
                }
                
            } catch {
                await MainActor.run {
                    print("DEBUG: Two-pass generation failed: \(error)")
                    messageViewModel?.loading = nil
                    messageViewModel?.tempResponse = ""
                    self.error = .generate("Two-pass generation failed: \(error.localizedDescription)")
                    
                    // Provide a fallback response instead of leaving the message empty
                    let fallbackResponse = """
                    **Note Generation Error**
                    
                    The advanced two-pass generation failed: \(error.localizedDescription)
                    
                    **Original Input:**
                    \(prompt)
                    
                    **Suggested Action:**
                    Please try regenerating this note or use the simple text input instead of the Easy Note form.
                    """
                    
                    userMessage.response = fallbackResponse
                    messageViewModel?.load(of: activeChat)
                    saveActivityContent()
                }
            }
        }
    }
    
    // MARK: - Activity Management
    
    /// Creates a new activity and associated chat session
    /// - Parameter isEasyNote: Whether this activity is created through the EasyNote interface
    ///
    /// This method:
    /// 1. Creates a new activity with appropriate type based on selected task
    /// 2. Generates a unique title including timestamp and sequence number
    /// 3. Creates an associated chat with appropriate system prompt
    /// 4. Saves the activity to persistent storage
    /// 5. Updates UI state to reflect the new activity
    ///
    /// The title generation logic:
    /// - Uses current date and time
    /// - Appends a sequence number if multiple activities exist for the same day
    /// - Format: "{Type} - {Date} [(Count)]"
    func createNewActivity(isEasyNote: Bool = false) {
        print("DEBUG: ===== createNewActivity START =====")
        print("DEBUG: isEasyNote: \(isEasyNote)")
        print("DEBUG: selectedClientID: \(selectedClientID?.uuidString ?? "nil")")
        print("DEBUG: selectedTask: '\(selectedTask)'")
        
        guard let clientIndex = clients.firstIndex(where: { $0.id == selectedClientID }) else { 
            print("DEBUG: Cannot create activity - no client found for selectedClientID")
            return 
        }
        
        // Get activity type from selected task
        let type = getActivityTypeFromTask(selectedTask)
        print("DEBUG: Activity type from task: \(type.rawValue)")
        
        // Check if we already have a very recent activity of this type (within last 5 seconds)
        // This helps prevent accidental duplicates from rapid clicks
        let fiveSecondsAgo = Date().addingTimeInterval(-5)
        let veryRecentActivities = clients[clientIndex].activities.filter { activity in
            activity.type == type && activity.date > fiveSecondsAgo
        }
        
        if !veryRecentActivities.isEmpty {
            print("DEBUG: WARNING - Found \(veryRecentActivities.count) very recent activities of type \(type.rawValue)")
            print("DEBUG: Most recent activity created at: \(veryRecentActivities.first?.date ?? Date())")
            print("DEBUG: Skipping duplicate activity creation")
            
            // Select the most recent activity instead of creating a new one
            if let mostRecent = veryRecentActivities.first {
                selectedActivityID = mostRecent.id
                print("DEBUG: Selected existing recent activity: \(mostRecent.id)")
            }
            return
        }
        
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
        
        print("DEBUG: Generated title: '\(title)'")
        print("DEBUG: Activities of type \(type.rawValue) today: \(activitiesOfTypeToday.count)")
        
        let newActivity = ClientActivity(
            type: type,
            date: Date(),
            content: "",
            title: title
        )
        
        print("DEBUG: Created new activity object: \(newActivity.id)")
        
        // Add and select the new activity
        clients[clientIndex].activities.insert(newActivity, at: 0)
        saveClient(clients[clientIndex])
        selectedActivityID = newActivity.id
        
        print("DEBUG: createNewActivity - Set selectedActivityID to: \(newActivity.id)")
        print("DEBUG: createNewActivity - selectedActivity is now: \(selectedActivity?.id.uuidString ?? "nil")")
        print("DEBUG: createNewActivity - Total activities for client: \(clients[clientIndex].activities.count)")
        
        // Print for debugging
        print("DEBUG: Created new activity with type: \(type.rawValue), task: \(selectedTask)")
        
        // Clear the chat view for new activities
        clearChatView()
        
        // Create a fresh chat for this new activity
        createFreshChatForActivity(newActivity, isEasyNote: isEasyNote)
        
        // Ensure UI focus for new activities
        shouldFocusPrompt = true
        
        print("DEBUG: ===== createNewActivity END =====")
    }
    
    /// Clears the current chat view
    /// This method removes the active chat and clears the message view
    private func clearChatView() {
        print("DEBUG: clearChatView() called")
        
        if let existingChat = activeChat {
            print("DEBUG: Clearing existing chat: \(existingChat.id)")
            // Save any pending content before removing
            saveActivityContent()
            
            // Clear all messages from the chat first
            for message in existingChat.messages {
                modelContext.delete(message)
            }
            existingChat.messages.removeAll()
            
            // Delete the chat itself
            modelContext.delete(existingChat)
            chats.removeAll(where: { $0.id == existingChat.id })
        } else {
            print("DEBUG: No existing chat to clear")
        }
        
        // Clear all related state
        activeChat = nil
        
        // Clear the message view completely and load the empty state
        messageViewModel?.messages.removeAll()
        messageViewModel?.tempResponse = ""
        messageViewModel?.loading = nil
        messageViewModel?.load(of: nil) // Load empty state
        
        print("DEBUG: Chat view fully cleared")
    }
    
    /// Creates a fresh chat for the given activity
    /// - Parameters:
    ///   - activity: The activity to create a chat for
    ///   - isEasyNote: Whether this is an EasyNote format
    private func createFreshChatForActivity(_ activity: ClientActivity, isEasyNote: Bool = false) {
        let chat = Chat(model: Defaults[.defaultModel])
        chat.systemPrompt = getSystemPromptForActivityType(activity.type, isEasyNote: isEasyNote)
        modelContext.insert(chat)
        chats.insert(chat, at: 0)
        activeChat = chat
        
        // Load the empty chat in MessageViewModel
        messageViewModel?.load(of: chat)
        print("DEBUG: Created fresh chat for \(activity.type.rawValue): \(chat.id)")
    }
    
    /// Converts a task name to its corresponding activity type
    /// - Parameter task: The task name to convert
    /// - Returns: The corresponding ActivityType
    ///
    /// Mapping:
    /// - "Create a Client Session Note" → .sessionNote
    /// - "Create a Treatment Plan" → .treatmentPlan
    /// - "Brainstorm" → .brainstorm
    /// - Default → .sessionNote
    func getActivityTypeFromTask(_ task: String) -> ActivityType {
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
    
    /// Converts an activity type to its corresponding task name
    /// - Parameter type: The ActivityType to convert
    /// - Returns: The corresponding task name
    ///
    /// This is the inverse operation of getActivityTypeFromTask(_:)
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
    
    /// Handles activity selection changes
    ///
    /// This method:
    /// 1. Validates the selected activity exists
    /// 2. Updates the selected task to match the activity type
    /// 3. Loads the appropriate chat history 
    /// 4. Handles invalid selections by resetting to a valid state
    func onActivitySelected() {
        print("DEBUG: onActivitySelected() called with selectedActivityID: \(selectedActivityID?.uuidString ?? "nil")")
        
        // Validate client selection first
        validateClientSelection()
        
        if let selectedID = selectedActivityID {
            // Validate that the selected activity exists in the filtered activities
            guard let activity = filteredActivities.first(where: { $0.id == selectedID }) else {
                print("DEBUG: Invalid activity selection: \(selectedID)")
                print("DEBUG: Available filtered activities: \(filteredActivities.count)")
                
                // Reset to first available activity or clear selection
                if let firstActivity = filteredActivities.first {
                    selectedActivityID = firstActivity.id
                    print("DEBUG: Reset to first available activity: \(firstActivity.id)")
                    // Recursively call to handle the corrected selection
                    onActivitySelected()
                } else {
                    selectedActivityID = nil
                    clearChatView()
                    print("DEBUG: No valid activities available, cleared selection")
                }
                return
            }
            
            print("DEBUG: Valid activity selected: \(activity.id) (\(activity.type.rawValue))")
            print("DEBUG: Current activeChat: \(activeChat?.id.uuidString ?? "nil")")
            print("DEBUG: Current selectedActivity: \(selectedActivity?.id.uuidString ?? "nil")")
            
            // Update the selected task to match the activity type
            let oldTask = selectedTask
            selectedTask = taskForActivityType(activity.type)
            
            // Also update the selected activity type filter if needed
            if selectedActivityType != activity.type && selectedActivityType != .all {
                print("DEBUG: Updating selectedActivityType from \(selectedActivityType.rawValue) to \(activity.type.rawValue)")
                selectedActivityType = activity.type
            }
            
            print("DEBUG: Updated selectedTask from '\(oldTask)' to '\(selectedTask)'")
            
            // Always load the activity chat when selecting from sidebar
            // This ensures the chat view shows the correct content
            print("DEBUG: Loading chat for selected activity")
            loadActivityChat(activity)
        } else {
            print("DEBUG: No activity selected (selectedActivityID is nil)")
            // Clear chat view when no activity is selected
            clearChatView()
        }
    }
    

    
    /// Clears the chat view when starting a new activity type
    /// This should be called when switching between session notes, treatment plans, and brainstorming
    func clearChatForNewActivityType() {
        print("DEBUG: Clearing chat for new activity type")
        clearChatView()
        shouldFocusPrompt = true
    }
    
    /// Saves the current chat content to the associated activity
    ///
    /// This method:
    /// 1. Validates all required references exist
    /// 2. Converts chat messages to a serializable format
    /// 3. Saves the content to the activity
    /// 4. Updates the client file
    ///
    /// The chat content is saved as a JSON array of message dictionaries,
    /// where each message contains:
    /// - prompt: The user's input
    /// - response: The AI's response (if any)
    func saveActivityContent() {
        print("DEBUG: saveActivityContent() called")
        print("DEBUG: selectedClientID: \(selectedClientID?.uuidString ?? "nil")")
        print("DEBUG: selectedActivityID: \(selectedActivityID?.uuidString ?? "nil")")
        print("DEBUG: selectedActivity: \(selectedActivity?.id.uuidString ?? "nil")")
        print("DEBUG: activeChat: \(activeChat?.id.uuidString ?? "nil")")
        
        guard let activity = selectedActivity else {
            print("DEBUG: Cannot save - selectedActivity is nil")
            return
        }
        
        guard let clientIndex = clients.firstIndex(where: { $0.id == selectedClientID }) else {
            print("DEBUG: Cannot save - client not found for selectedClientID: \(selectedClientID?.uuidString ?? "nil")")
            return
        }
        
        guard let activityIndex = clients[clientIndex].activities.firstIndex(where: { $0.id == activity.id }) else {
            print("DEBUG: Cannot save - activity not found in client's activities: \(activity.id)")
            return
        }
        
        guard let chat = activeChat else {
            print("DEBUG: Cannot save - activeChat is nil")
            return
        }
        
        print("DEBUG: All required data available, proceeding with save")
        print("DEBUG: Chat has \(chat.messages.count) total messages")
        
        // Don't save if there are no messages to save
        guard !chat.messages.isEmpty else {
            print("DEBUG: No messages to save for activity")
            return
        }
        
        // Create an array of message dictionaries, keeping only user interactions and final responses
        // This filters out intermediate analysis prompts but preserves legitimate user content
        let messageHistory = chat.messages.compactMap { message -> [String: String]? in
            let prompt = message.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip completely empty prompts
            guard !prompt.isEmpty else {
                print("DEBUG: Skipping empty prompt")
                return nil
            }
            
            // Only filter out internal analysis prompts - be very specific
            let internalAnalysisMarkers = [
                "Consider these common patterns of client engagement",
                "Analyze the following therapy session transcript",
                "Please analyze the client's engagement and responsiveness",
                "You are a clinical documentation assistant generating a structured"
            ]
            
            // Only skip if the prompt starts with or contains these specific analysis markers
            let isInternalAnalysis = internalAnalysisMarkers.contains { marker in
                prompt.hasPrefix(marker) || (prompt.contains(marker) && prompt.count > 200)
            }
            
            if isInternalAnalysis {
                print("DEBUG: Skipping internal analysis prompt: \(String(prompt.prefix(50)))...")
                return nil
            }
            
            // Include all other user prompts and their responses
            var messageData: [String: String] = ["prompt": prompt]
            if let response = message.response, !response.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                messageData["response"] = response
            }
            
            print("DEBUG: Including message - prompt: '\(String(prompt.prefix(50)))...', hasResponse: \(message.response != nil)")
            return messageData
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let jsonData = try encoder.encode(messageHistory)
            
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("DEBUG: Saving chat history with \(messageHistory.count) messages")
                print("DEBUG: JSON preview: \(String(jsonString.prefix(200)))...")
                clients[clientIndex].activities[activityIndex].content = jsonString
                saveClient(clients[clientIndex])
                print("DEBUG: Successfully saved activity content")
            } else {
                print("DEBUG: Failed to convert JSON data to string")
            }
        } catch {
            print("DEBUG: Error saving chat history: \(error)")
        }
    }
    
    // Get system prompt for activity type
    func getSystemPromptForActivityType(_ type: ActivityType, isEasyNote: Bool = false) -> String {
        switch type {
        case .sessionNote:
            return isEasyNote ? SystemPrompts.easyNote : SystemPrompts.sessionNote
        case .treatmentPlan:
            return isEasyNote ? SystemPrompts.easyTreatmentPlan : SystemPrompts.treatmentPlan
        case .brainstorm:
            return SystemPrompts.brainstorm
        case .all:
            return SystemPrompts.brainstorm
        }
    }
    
    // System Prompts for different activities and contexts
    private struct SystemPrompts {
        // Default/Brainstorm prompt - already defined in Defaults.Keys
        static var brainstorm: String {
            return Defaults[.defaultSystemPrompt]
        }
        
        // Regular Session Note prompt
        static let sessionNote = """
        You are a clinical documentation assistant helping a therapist generate an insurance-ready psychotherapy progress note. 
        Focus on creating a structured, objective note that meets clinical and insurance requirements.

        You will use:
        1. The session transcript provided
        2. The modalities analysis provided (which identifies therapeutic techniques used)
        3. The client's treatment plan (if provided)
        4. Recent session notes (if provided)
        5. Any other client context provided

        Requirements:
        1. Use clear, objective, and concise clinical language
        2. Maintain gender-neutral pronouns ("they/them")
        3. Only use quotes if explicitly provided
        4. Focus on observable behaviors, reported thoughts/feelings, therapist interventions, and progress toward clinical goals
        5. Applies relevant modalities and interventions (e.g., CBT, DBT, ACT, Psychodynamic), naming them when appropriate
        6. References any schemas, cognitive distortions, or core beliefs using standard psychological terminology
        7. Concludes with a brief, action-oriented treatment plan
        8. If suicidal ideation or self-harm arises, include:
           a. Client statements or behaviors prompting risk assessment
           b. Identified risk and protective factors
           c. Outcome of suicide risk assessment with clinical rationale
           d. Any collaboratively developed safety plan
           e. Follow-up arrangements
        9. If a formal assessment tool was used, reference it by name
        10. Reflects clinical reasoning, ethical care, and legal defensibility
        11. Shows progression and connection to previous sessions when context is available
        12. Integrates treatment plan goals and tracks progress toward them
        13. Notes any significant changes in presentation or circumstances since last session
        14. Documents any coordination of care or external referrals
        15. For telehealth sessions:
            • First session: Document informed consent, risks/limitations discussed, license number, emergency resources
            • Subsequent sessions: Document identity confirmation, appropriateness, confidentiality measures

        Structure the output according to the specified note format, using appropriate headings.
        Ensure continuity with previous sessions when that context is available.
        Focus on demonstrating progress and clinical decision-making.
        """
        
        // EasyNote prompt - used when the form is used
        static let easyNote = """
        You are a clinical documentation assistant processing a structured therapy note.
        Use the provided form data to create a comprehensive, insurance-ready progress note.
        
        Requirements:
        1. Use all provided form fields in the final note
        2. Maintain clinical language and objectivity
        3. Follow the specified note format
        4. Include clear next steps
        
        [Placeholder for full EasyNote prompt]
        """
        
        // Regular Treatment Plan prompt
        static let treatmentPlan = """
        You are a licensed mental health professional and clinical supervisor. Your task is to produce (or update) a psychotherapy treatment plan for a client using whatever information is currently available in their record, plus the most recent prior treatment plan and session note if they exist. Follow these steps in order:

        1. **Ingest All Available Data**  
           • Client Identifier: "[client_id]"  
           • (Do not use Client Name in the plan itself.)  
           • Gender: "[gender]"  
           • Birthdate / Age: "[birthdate_or_age]"  
           • Start-of-Care Date: "[start_date]"  
           • Presenting Concerns: "[presenting_concerns]"  
           • Relevant History: "[history]"  
           • Presenting Symptoms: "[symptoms]"  
           • Insurance & ICD-10 Diagnosis: "[insurance_info], [icd10_code]"  
           • Client Strengths: "[strengths]"  
           • Treatment Obstacles: "[obstacles]"  
           • Cultural / Identity Factors: "[cultural_factors]"  
           • Current Risk Assessment: "[risk_assessment]"  
           • Most Recent Treatment Plan (if any):  
             "[prior_treatment_plan]"  
           • Most Recent Session Note Summary (if any):  
             "[recent_session_note]"

        2. **Detect Missing Critical Information**  
           Identify any of these critical elements that are blank or incomplete:  
           - ICD-10 Diagnosis  
           - At least one Long-Term Goal  
           - At least two Short-Term Objectives  
           - Risk Assessment  
           
           - **If any are missing**, ask the user succinctly for those specific items.  
             Example:  
             "I'm missing your client's ICD-10 diagnosis. Please provide it (e.g. 'F41.1 Generalized Anxiety Disorder'), or reply 'Generic Plan' to proceed with a general framework based on presenting concerns alone."  

        3. **Branch Logic**  
           - **Complete Data Path:**  
             Once all critical information is present, draft a **comprehensive treatment plan** according to the structure in Step 4.  
           - **Generic Plan Path:**  
             If the user replies "Generic Plan," produce a template plan based solely on the available data and clearly note any assumptions or gaps.  
           - **Iterative Path:**  
             If the user provides additional missing details, resume the Complete Data Path.

        4. **Output Format**  
           Use these headings exactly (with numbering) and populate each section:

           1. **Client Info & Diagnosis**  
              - Pseudonym & Age  
              - Start-of-Care  
              - ICD-10 Diagnosis (with code)  
              - Presenting Concerns & Symptoms  

           2. **Strengths & Barriers**  
              - Key Strengths  
              - Treatment Obstacles  

           3. **Review of Prior Plan & Session**  
              - Brief summary of prior treatment plan goals (if any)  
              - Summary of most recent session themes/actions (if any)  

           4. **Goals & Objectives**  
              - **Long-Term Goals:** (List 1–2 SMART goals)  
              - **Short-Term Objectives:** (List 2–4 measurable steps)  

           5. **Recommended Interventions & Modalities**  
              - Tailor to chosen modality(ies) (e.g., CBT, DBT, Narrative)  
              - Specify session techniques and homework assignments  

           6. **Timeline & Outcome Measures**  
              - Proposed frequency/duration of sessions  
              - Key metrics or scales for monitoring progress  
              - Review dates  

           7. **Cultural & Risk Considerations**  
              - Cultural, identity or language factors  
              - Any safety planning or risk-management steps  

        5. **Tone & Style**  
           - Professional, empathetic, and clinician-focused.  
           - Use clear, concise clinical language suitable for inclusion in a client's chart.  
           - When you must make assumptions due to missing data, state them explicitly.

        BEGIN now by examining the provided fields, prompting for any missing critical items, and then generating the appropriate treatment plan.
        """
        
        // Easy Treatment Plan prompt
        static let easyTreatmentPlan = """
        You are a clinical documentation assistant processing a structured treatment plan.
        Use the provided form data to create a comprehensive treatment plan.
        
        Requirements:
        1. Use all provided form fields
        2. Create measurable goals
        3. Include specific interventions
        4. Set clear timeframes
        
        [Placeholder for full Easy Treatment Plan prompt]
        """
    }
    
    // MARK: - Therapeutic Modality Analysis
    
    /// Represents a specific therapeutic intervention technique
    /// Used to identify and track specific therapeutic methods used in sessions
    struct TherapyIntervention: Identifiable {
        let id = UUID()
        /// Name of the intervention technique
        let name: String
        /// Clinical description of the intervention
        let description: String
        /// Specific phrases or patterns that indicate this intervention is being used
        let detectionCriteria: String
    }
    
    /// Represents a complete therapeutic modality with its associated interventions
    /// Used to categorize and analyze therapeutic approaches in sessions
    struct TherapyModality: Identifiable {
        let id = UUID()
        /// Name of the therapeutic modality
        let name: String
        /// Clinical description of the modality
        let description: String
        /// Patterns that indicate this modality is being used
        let detectionCriteria: [String]
        /// Specific interventions associated with this modality
        let interventions: [TherapyIntervention]
    }
    
    /// Comprehensive catalog of therapeutic modalities and their interventions
    /// This serves as the knowledge base for analyzing therapy sessions
    private let therapyModalities: [TherapyModality] = [
        TherapyModality(
            name: "Cognitive Behavioral Therapy (CBT)",
            description: "A structured, time-limited approach targeting the interplay of thoughts, feelings, and behaviors to alleviate distress and build coping skills.",
            detectionCriteria: [
                "Explicit identification of 'automatic thoughts' or cognitive distortions",
                "Use of worksheets or thought‐records",
                "Goal-setting around behavior change"
            ],
            interventions: [
                TherapyIntervention(
                    name: "Cognitive Restructuring",
                    description: "Identifying and challenging maladaptive thoughts.",
                    detectionCriteria: "Therapist asks 'What evidence supports that thought?' or 'Is there an alternative explanation?'"
                ),
                TherapyIntervention(
                    name: "Behavioral Activation",
                    description: "Scheduling pleasant or goal-directed activities.",
                    detectionCriteria: "Discussion of activity logs or 'Let's plan three enjoyable tasks this week.'"
                ),
                TherapyIntervention(
                    name: "Socratic Questioning",
                    description: "Guided discovery via open, probing questions.",
                    detectionCriteria: "Series of 'Why do you think...?' or 'How might you view that differently?'"
                ),
                TherapyIntervention(
                    name: "Exposure Tasks",
                    description: "Gradual confrontation of feared stimuli.",
                    detectionCriteria: "Let's hierarchy‐rank your anxiety triggers and schedule step one."
                ),
                TherapyIntervention(
                    name: "Thought Records",
                    description: "Written logs of situations, emotions, thoughts, and alternative responses.",
                    detectionCriteria: "References to worksheets documenting SITUATION–THOUGHT–FEELING–RESPONSE."
                )
            ]
        ),
        TherapyModality(
            name: "Dialectical Behavior Therapy (DBT)",
            description: "An offshoot of CBT emphasizing balance between acceptance and change; widely used for emotion dysregulation and self-harm.",
            detectionCriteria: [
                "Explicit skills training (mindfulness, distress tolerance)",
                "Dialectical framing ('both/and' rather than 'either/or')"
            ],
            interventions: [
                TherapyIntervention(
                    name: "Mindfulness",
                    description: "Nonjudgmental present-moment awareness.",
                    detectionCriteria: "Let's notice your breath and observe thoughts without reacting."
                ),
                TherapyIntervention(
                    name: "Distress Tolerance",
                    description: "Crisis‐survival strategies (e.g., TIP, self-soothe).",
                    detectionCriteria: "Introduction of 'STOP' skill or 'Ice‐water method' for high distress."
                ),
                TherapyIntervention(
                    name: "Emotion Regulation",
                    description: "Identifying and reducing vulnerability to emotions.",
                    detectionCriteria: "Track your emotion cycles and use PLEASE skills for balance."
                ),
                TherapyIntervention(
                    name: "Interpersonal Effectiveness",
                    description: "Assertiveness skills (DEAR MAN, GIVE, FAST).",
                    detectionCriteria: "Role-play of DEAR MAN script for a difficult conversation."
                )
            ]
        ),
        TherapyModality(
            name: "Acceptance and Commitment Therapy (ACT)",
            description: "Fosters psychological flexibility via acceptance of inner experience and committed action toward personal values.",
            detectionCriteria: [
                "Language of 'acceptance' vs. 'change'",
                "Values clarification exercises"
            ],
            interventions: [
                TherapyIntervention(
                    name: "Cognitive Defusion",
                    description: "Creating distance from unhelpful thoughts.",
                    detectionCriteria: "Imagine that thought as a leaf floating down a stream."
                ),
                TherapyIntervention(
                    name: "Values Clarification",
                    description: "Identifying life domains and guiding action.",
                    detectionCriteria: "'What matters most to you in these areas?' worksheets."
                ),
                TherapyIntervention(
                    name: "Committed Action",
                    description: "Goal steps aligned with values.",
                    detectionCriteria: "What small step can you take today toward that value?"
                ),
                TherapyIntervention(
                    name: "Acceptance Exercises",
                    description: "Willingness to experience private events.",
                    detectionCriteria: "Allow the feeling to be here without judgment."
                )
            ]
        ),
        TherapyModality(
            name: "Psychodynamic Therapy",
            description: "Explores unconscious processes, early relationships, and transference to uncover patterns driving current problems.",
            detectionCriteria: [
                "Discussion of childhood, dreams, or 'defenses'",
                "Therapist interpretations linking past to present"
            ],
            interventions: [
                TherapyIntervention(
                    name: "Interpretation",
                    description: "Translating client material into unconscious meaning.",
                    detectionCriteria: "You seem upset with me—could that be reminiscent of how you felt with your father?"
                ),
                TherapyIntervention(
                    name: "Exploration of Transference",
                    description: "Analyzing client's projections onto therapist.",
                    detectionCriteria: "I notice you reacted to that question by avoiding eye contact—what does that remind you of?"
                ),
                TherapyIntervention(
                    name: "Defense Mechanism Analysis",
                    description: "Identifying suppression, projection, etc.",
                    detectionCriteria: "Therapist labels 'You might be using intellectualization to avoid feeling anxious.'"
                )
            ]
        ),
        TherapyModality(
            name: "Person-Centered Therapy",
            description: "A non-directive approach emphasizing unconditional positive regard, empathy, and congruence to facilitate self-actualization.",
            detectionCriteria: [
                "Client leads content; therapist provides deep reflection",
                "Absence of structured homework or direct advice"
            ],
            interventions: [
                TherapyIntervention(
                    name: "Reflective Listening",
                    description: "Mirroring back client's feelings/content.",
                    detectionCriteria: "It sounds like you felt abandoned when that happened—did I get that right?"
                ),
                TherapyIntervention(
                    name: "Unconditional Positive Regard",
                    description: "Nonjudgmental acceptance.",
                    detectionCriteria: "Therapist expresses genuine warmth without evaluation."
                ),
                TherapyIntervention(
                    name: "Empathy Statements",
                    description: "Validating client's subjective experience.",
                    detectionCriteria: "I can imagine that was really painful for you."
                )
            ]
        ),
        TherapyModality(
            name: "Eye Movement Desensitization and Reprocessing (EMDR)",
            description: "Trauma-focused therapy using bilateral stimulation (e.g., eye movements) to reprocess distressing memories.",
            detectionCriteria: [
                "Use of BLS protocols",
                "Client report of 'noticing sensations' during bilateral tapping"
            ],
            interventions: [
                TherapyIntervention(
                    name: "Desensitization (BLS)",
                    description: "Therapist guides client through sets of bilateral eye movements.",
                    detectionCriteria: "Follow my fingers side to side while recalling the image."
                ),
                TherapyIntervention(
                    name: "Installation of Positive Cognition",
                    description: "Strengthening adaptive beliefs post-desensitization.",
                    detectionCriteria: "What positive belief about yourself would you like to anchor here?"
                ),
                TherapyIntervention(
                    name: "Resource Development",
                    description: "Building coping images or 'safe place.'",
                    detectionCriteria: "Imagine your sanctuary—describe where and how it feels."
                )
            ]
        ),
        TherapyModality(
            name: "Internal Family Systems (IFS)",
            description: "Views personality as multiple 'parts' guided by a core Self; promotes healing via Self-leadership.",
            detectionCriteria: [
                "Parts language ('exiles,' 'managers,' 'firefighters')",
                "Therapist invitations to 'meet' an inner part"
            ],
            interventions: [
                TherapyIntervention(
                    name: "Parts Mapping",
                    description: "Identifying and naming distinct parts.",
                    detectionCriteria: "Where in your body do you feel that anger part?"
                ),
                TherapyIntervention(
                    name: "Unblending",
                    description: "Separating Self from parts to observe.",
                    detectionCriteria: "Therapist 'steps back' and asks client to witness the part."
                ),
                TherapyIntervention(
                    name: "Self-led Dialogue",
                    description: "Facilitating compassionate conversation between Self and parts.",
                    detectionCriteria: "What does your calm Self want to say to the anxious part?"
                )
            ]
        ),
        TherapyModality(
            name: "Solution-Focused Brief Therapy (SFBT)",
            description: "Goal-and-solution orientation focusing on clients' strengths and exceptions to problems.",
            detectionCriteria: [
                "Emphasis on 'what's working' rather than 'what's wrong'",
                "Frequent scaling and miracle questions"
            ],
            interventions: [
                TherapyIntervention(
                    name: "Miracle Question",
                    description: "Imagining a future without the problem.",
                    detectionCriteria: "If a miracle happened overnight, what would be different tomorrow?"
                ),
                TherapyIntervention(
                    name: "Scaling Questions",
                    description: "Rating progress or confidence on a 0–10 scale.",
                    detectionCriteria: "On a scale of 0–10, where are you today in feeling hopeful?"
                ),
                TherapyIntervention(
                    name: "Exception Finding",
                    description: "Identifying times problem did not occur.",
                    detectionCriteria: "When was the last time you felt less anxious? What were you doing?"
                )
            ]
        ),
        TherapyModality(
            name: "Narrative Therapy",
            description: "Externalizes problems and empowers clients to re-author their life stories.",
            detectionCriteria: [
                "Language of 'the problem is the problem'",
                "Therapist helps client separate identity from issues"
            ],
            interventions: [
                TherapyIntervention(
                    name: "Externalization",
                    description: "Treating the problem as separate from the person.",
                    detectionCriteria: "How does Anxiety show up as its own entity?"
                ),
                TherapyIntervention(
                    name: "Re-authoring",
                    description: "Developing alternative, preferred narratives.",
                    detectionCriteria: "Tell me a story about a time you overcame that challenge."
                ),
                TherapyIntervention(
                    name: "Mapping Influence",
                    description: "Charting how client responds to the problem.",
                    detectionCriteria: "What effects does Depression have on your daily life?"
                )
            ]
        ),
        TherapyModality(
            name: "Trauma-Focused CBT (TF-CBT)",
            description: "Adaptation of CBT for children/adolescents that incorporates gradual trauma processing.",
            detectionCriteria: [
                "Use of trauma narration or graded exposure",
                "Parental involvement often documented"
            ],
            interventions: [
                TherapyIntervention(
                    name: "Psychoeducation",
                    description: "Teaching about trauma reactions.",
                    detectionCriteria: "It's normal to have nightmares after something scary happens."
                ),
                TherapyIntervention(
                    name: "Trauma Narration",
                    description: "Writing or telling the trauma story.",
                    detectionCriteria: "References to 'my story' exercises."
                ),
                TherapyIntervention(
                    name: "Relaxation Skills",
                    description: "Progressive muscle relaxation, deep breathing.",
                    detectionCriteria: "Let's do 5-4-3-2-1 grounding now."
                )
            ]
        ),
        TherapyModality(
            name: "Behavioral Therapy",
            description: "Focuses on modifying observable behavior via learning principles (conditioning, reinforcement).",
            detectionCriteria: [
                "Data-driven tracking of ABCs (Antecedent–Behavior–Consequence)",
                "Explicit reward or token systems"
            ],
            interventions: [
                TherapyIntervention(
                    name: "Reinforcement",
                    description: "Positive or negative reinforcement schedules.",
                    detectionCriteria: "When you complete the task, you earn a token."
                ),
                TherapyIntervention(
                    name: "Shaping",
                    description: "Gradual approximation of target behavior.",
                    detectionCriteria: "You did half today—next session we'll add a bit more."
                ),
                TherapyIntervention(
                    name: "Contingency Management",
                    description: "Systematic consequence arrangements.",
                    detectionCriteria: "If smoking stays below two cigarettes, you get an extra break."
                )
            ]
        ),
        TherapyModality(
            name: "Motivational Interviewing (MI)",
            description: "Client-centered, directive method to foster intrinsic motivation for change, especially in ambivalence.",
            detectionCriteria: [
                "Eliciting 'change talk' vs. 'sustain talk'",
                "Use of OARS (Open-ended questions, Affirmations, Reflective listening, Summaries)"
            ],
            interventions: [
                TherapyIntervention(
                    name: "Open-Ended Questions",
                    description: "Invites expansive responses.",
                    detectionCriteria: "What are your thoughts on making this change?"
                ),
                TherapyIntervention(
                    name: "Affirmations",
                    description: "Recognizing client strengths.",
                    detectionCriteria: "It's great that you stuck with that despite challenges."
                ),
                TherapyIntervention(
                    name: "Reflective Listening",
                    description: "Mirror content and feeling.",
                    detectionCriteria: "You're feeling torn between quitting and staying the same."
                ),
                TherapyIntervention(
                    name: "Summaries",
                    description: "Pulling together key client statements.",
                    detectionCriteria: "So far, you've noted X, Y, and Z as reasons to change."
                )
            ]
        )
    ]
    
    /// Generates a prompt for analyzing therapeutic modalities in session content
    /// - Returns: A structured prompt for the AI to analyze therapeutic approaches
    ///
    /// The prompt instructs the AI to:
    /// 1. Identify therapeutic modalities used
    /// 2. Detect specific interventions
    /// 3. Provide evidence from the transcript
    /// 4. Note any unique or combined approaches
    func getModalitiesAnalysisPrompt() -> String {
        var prompt = """
        Analyze the following therapy session transcript to identify therapeutic modalities and interventions used.
        
        Consider these common psychotherapy modalities and their typical interventions:
        
        """
        
        for modality in therapyModalities {
            prompt += "\n\n\(modality.name)\n"
            prompt += "Description: \(modality.description)\n"
            prompt += "Detection Criteria:\n"
            for criterion in modality.detectionCriteria {
                prompt += "- \(criterion)\n"
            }
            prompt += "\nInterventions:\n"
            for intervention in modality.interventions {
                prompt += "• \(intervention.name)\n"
                prompt += "  - What: \(intervention.description)\n"
                prompt += "  - Detect: \(intervention.detectionCriteria)\n"
            }
        }
        
        prompt += """
        
        Please analyze the session and:
        1. Identify all therapeutic modalities used
        2. List specific interventions from each modality
        3. Provide evidence from the transcript supporting each identification
        4. Note any significant therapeutic moments or techniques that don't fit these categories
        
        Format your response as a structured list.
        """
        
        return prompt
    }
    
    /// Performs comprehensive analysis of a therapy session
    /// - Parameters:
    ///   - transcript: The session transcript to analyze
    ///   - ollamaKit: The OllamaKit instance for AI analysis
    ///   - isEasyNote: Whether this is an EasyNote format
    ///   - providedModalities: Pre-selected modalities for EasyNote
    /// - Returns: A tuple containing modalities analysis and engagement analysis
    /// - Throws: ChatViewModelError if analysis fails
    private func performSessionAnalysis(
        transcript: String,
        ollamaKit: OllamaKit,
        isEasyNote: Bool = false,
        providedModalities: [String: [String]]? = nil
    ) async throws -> (modalities: String, engagement: String) {
        guard messageViewModel != nil else {
            throw ChatViewModelError.generate("MessageViewModel not available")
        }
        
        print("DEBUG: performSessionAnalysis - starting analysis")
        
        // Get modalities analysis
        let modalitiesAnalysis: String
        if isEasyNote, let modalities = providedModalities {
            print("DEBUG: Using provided modalities for EasyNote")
            var analysis = "Therapeutic Modalities Analysis:\n\n"
            for (modality, interventions) in modalities {
                analysis += "\(modality):\n"
                for intervention in interventions {
                    analysis += "- \(intervention)\n"
                }
                analysis += "\n"
            }
            modalitiesAnalysis = analysis
        } else {
            print("DEBUG: Generating modalities analysis with AI")
            let analysisPrompt = getModalitiesAnalysisPrompt() + "\n\nSession Transcript:\n" + transcript
            modalitiesAnalysis = try await generateAnalysis(prompt: analysisPrompt, ollamaKit: ollamaKit)
            print("DEBUG: Modalities analysis completed, length: \(modalitiesAnalysis.count)")
        }
        
        // Get engagement patterns analysis with retry
        print("DEBUG: Starting engagement analysis")
        let engagementPrompt = getEngagementPatternsPrompt() + "\n\nSession Transcript:\n" + transcript
        
        var engagementAnalysis: String = ""
        var retryCount = 0
        let maxRetries = 2
        
        while retryCount <= maxRetries {
            do {
                print("DEBUG: Engagement analysis attempt \(retryCount + 1) of \(maxRetries + 1)")
                engagementAnalysis = try await generateAnalysis(prompt: engagementPrompt, ollamaKit: ollamaKit)
                print("DEBUG: Engagement analysis completed, length: \(engagementAnalysis.count)")
                break
            } catch {
                retryCount += 1
                print("DEBUG: Engagement analysis attempt \(retryCount) failed: \(error)")
                
                if retryCount > maxRetries {
                    print("DEBUG: All engagement analysis attempts failed, using fallback")
                    engagementAnalysis = "Engagement analysis could not be completed. Client engagement appeared cooperative based on the session content provided."
                    break
                } else {
                    print("DEBUG: Waiting before retry...")
                    try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                }
            }
        }
        
        print("DEBUG: performSessionAnalysis - completed successfully")
        return (modalities: modalitiesAnalysis, engagement: engagementAnalysis)
    }
    
    /// Generates an AI analysis based on a specific prompt
    /// - Parameters:
    ///   - prompt: The analysis prompt to send to the AI
    ///   - ollamaKit: The OllamaKit instance for AI interaction
    /// - Returns: The generated analysis
    /// - Throws: ChatViewModelError if generation fails
    private func generateAnalysis(prompt: String, ollamaKit: OllamaKit) async throws -> String {
        guard let activeChat = self.activeChat else {
            throw ChatViewModelError.generate("No active chat available")
        }
        
        print("DEBUG: Starting analysis generation with prompt length: \(prompt.count)")
        print("DEBUG: Analysis prompt preview: \(String(prompt.prefix(100)))...")
        
        // Use direct OllamaKit API call instead of going through MessageViewModel
        // This prevents creating temporary messages that could interfere with the main chat
        let chatData = OKChatRequestData(
            model: activeChat.model,
            messages: [
                OKChatRequestData.Message(role: .system, content: activeChat.systemPrompt ?? ""),
                OKChatRequestData.Message(role: .user, content: prompt)
            ]
        )
        
        var fullResponse = ""
        var isReasoningContent = false
        
        do {
            print("DEBUG: Making direct API call for analysis")
            
            for try await chunk in ollamaKit.chat(data: chatData) {
                guard let content = chunk.message?.content else { continue }
                
                // Handle reasoning content (like <think> tags) by skipping it
                if content.contains("<think>") {
                    isReasoningContent = true
                    continue
                }
                
                if content.contains("</think>") {
                    isReasoningContent = false
                    continue
                }
                
                // Only accumulate non-reasoning content
                if !isReasoningContent {
                    fullResponse += content
                }
                
                // Check if generation is done
                if chunk.done {
                    print("DEBUG: Analysis generation completed via direct API")
                    print("DEBUG: Response length: \(fullResponse.count)")
                    break
                }
            }
            
            // Validate we got a meaningful response
            let trimmedResponse = fullResponse.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedResponse.isEmpty else {
                throw ChatViewModelError.generate("Empty response from analysis generation")
            }
            
            print("DEBUG: Analysis generation successful")
            return trimmedResponse
            
        } catch {
            print("DEBUG: Analysis generation failed: \(error)")
            throw ChatViewModelError.generate("Analysis generation failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Client Engagement Pattern Tracking
    
    /// Represents a specific example of client engagement behavior
    /// Used to identify and categorize client responses and participation
    struct ClientEngagementExample: Identifiable {
        let id = UUID()
        /// Description of the engagement behavior
        let description: String
        /// Category of engagement (e.g., "Active Listening", "Response to Interventions")
        let category: String
        /// Qualitative assessment of the engagement
        let tone: EngagementTone
    }
    
    /// Represents the qualitative assessment of client engagement
    /// Used to categorize engagement patterns as positive, negative, or neutral
    enum EngagementTone {
        /// Indicates positive engagement and receptiveness
        case positive
        /// Indicates resistance or disengagement
        case negative
        /// Indicates neither clearly positive nor negative engagement
        case neutral
    }
    
    /// Groups related engagement examples into categories
    /// Used to organize and analyze different aspects of client engagement
    struct ClientEngagementCategory {
        /// Name of the engagement category
        let name: String
        /// Collection of example behaviors in this category
        let examples: [ClientEngagementExample]
    }
    
    /// Comprehensive catalog of client engagement patterns
    /// Used as a reference for analyzing client participation and response
    private let clientEngagementPatterns: [ClientEngagementCategory] = [
        ClientEngagementCategory(
            name: "General Receptiveness",
            examples: [
                ClientEngagementExample(
                    description: "The client was open and engaged, participating actively throughout the session.",
                    category: "General Receptiveness",
                    tone: .positive
                ),
                ClientEngagementExample(
                    description: "The client demonstrated a willingness to explore new perspectives and engage in the conversation.",
                    category: "General Receptiveness",
                    tone: .positive
                ),
                ClientEngagementExample(
                    description: "The client seemed disengaged and offered minimal verbal feedback during the session.",
                    category: "General Receptiveness",
                    tone: .negative
                )
            ]
        ),
        ClientEngagementCategory(
            name: "Active Listening",
            examples: [
                ClientEngagementExample(
                    description: "The client listened attentively and responded thoughtfully to prompts.",
                    category: "Active Listening",
                    tone: .positive
                ),
                ClientEngagementExample(
                    description: "The client showed a high level of engagement by reflecting on key points discussed.",
                    category: "Active Listening",
                    tone: .positive
                ),
                ClientEngagementExample(
                    description: "The client appeared distant and unresponsive to discussion points.",
                    category: "Active Listening",
                    tone: .negative
                )
            ]
        ),
        ClientEngagementCategory(
            name: "Response to Interventions",
            examples: [
                ClientEngagementExample(
                    description: "The client responded positively to the interventions, showing clear interest and engagement in the strategies discussed.",
                    category: "Response to Interventions",
                    tone: .positive
                ),
                ClientEngagementExample(
                    description: "The client appeared resistant to feedback and became defensive when suggestions were offered.",
                    category: "Response to Interventions",
                    tone: .negative
                ),
                ClientEngagementExample(
                    description: "The client demonstrated a willingness to apply the interventions, expressing interest in integrating them into their routine.",
                    category: "Response to Interventions",
                    tone: .positive
                )
            ]
        ),
        ClientEngagementCategory(
            name: "Nonverbal Communication",
            examples: [
                ClientEngagementExample(
                    description: "The client's body language indicated receptiveness, with consistent eye contact and positive posture.",
                    category: "Nonverbal Communication",
                    tone: .positive
                ),
                ClientEngagementExample(
                    description: "The client exhibited closed body language, such as crossed arms or avoiding eye contact.",
                    category: "Nonverbal Communication",
                    tone: .negative
                )
            ]
        ),
        ClientEngagementCategory(
            name: "Commitment to Practice",
            examples: [
                ClientEngagementExample(
                    description: "The client has committed to practicing their healthy coping skills and self-care activities between sessions.",
                    category: "Commitment to Practice",
                    tone: .positive
                ),
                ClientEngagementExample(
                    description: "The client expressed reluctance to engage in between-session practice or homework.",
                    category: "Commitment to Practice",
                    tone: .negative
                )
            ]
        )
    ]
    
    /// Generates a prompt for analyzing client engagement patterns
    /// - Returns: A structured prompt for the AI to analyze client engagement
    ///
    /// The prompt instructs the AI to analyze:
    /// 1. Overall engagement level
    /// 2. Response to specific interventions
    /// 3. Nonverbal communication
    /// 4. Commitment to practice
    /// 5. Changes in engagement during the session
    private func getEngagementPatternsPrompt() -> String {
        var prompt = """
        Consider these common patterns of client engagement and responsiveness when analyzing the session:
        
        """
        
        for category in clientEngagementPatterns {
            prompt += "\n\n\(category.name):\n"
            
            // Add positive examples
            prompt += "Positive Indicators:\n"
            for example in category.examples.filter({ $0.tone == .positive }) {
                prompt += "- \(example.description)\n"
            }
            
            // Add negative examples
            prompt += "\nChallenging Indicators:\n"
            for example in category.examples.filter({ $0.tone == .negative }) {
                prompt += "- \(example.description)\n"
            }
        }
        
        prompt += """
        
        Please analyze the client's engagement and responsiveness, considering:
        1. Overall level of engagement and receptiveness
        2. Specific responses to interventions and suggestions
        3. Notable nonverbal communication
        4. Commitment to between-session practice
        5. Any significant changes in engagement during the session
        
        Format your response as a structured analysis focusing on these aspects.
        """
        
        return prompt
    }
    
    /// Performs complete two-pass note generation for session notes and treatment plans
    /// - Parameters:
    ///   - userInput: The original user input (transcript or form data)
    ///   - ollamaKit: The OllamaKit instance for AI analysis
    ///   - isEasyNote: Whether this is an EasyNote format
    ///   - providedModalities: Pre-selected modalities for EasyNote
    ///   - noteFormat: Override note format (for EasyNote)
    /// - Returns: The final generated note
    /// - Throws: ChatViewModelError if generation fails
    func performTwoPassGeneration(
        userInput: String,
        ollamaKit: OllamaKit,
        isEasyNote: Bool = false,
        providedModalities: [String: [String]]? = nil,
        noteFormat: String? = nil
    ) async throws -> String {
        let activityType = getActivityTypeFromTask(selectedTask)
        
        // For brainstorm activities, skip two-pass and use simple generation
        guard activityType != .brainstorm else {
            print("DEBUG: Using simple generation for Brainstorm activity")
            return userInput // For brainstorm, just pass through the user input
        }
        
        print("DEBUG: Starting two-pass generation for activity type: \(activityType.rawValue)")
        
        // FIRST PASS: Analyze the session content
        print("DEBUG: First Pass - Analyzing session content")
        let analysis = try await performSessionAnalysis(
            transcript: userInput,
            ollamaKit: ollamaKit,
            isEasyNote: isEasyNote,
            providedModalities: providedModalities
        )
        
        // Add a small delay between passes to ensure first pass completes
        print("DEBUG: Waiting briefly between first and second pass...")
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // SECOND PASS: Generate the structured note
        print("DEBUG: Second Pass - Generating structured note")
        let finalNote = try await generateStructuredNote(
            userInput: userInput,
            analysis: analysis,
            ollamaKit: ollamaKit,
            activityType: activityType,
            isEasyNote: isEasyNote,
            noteFormat: noteFormat
        )
        
        print("DEBUG: Two-pass generation completed successfully")
        return finalNote
    }
    
    /// Generates the structured note using analysis and context (Second Pass)
    /// - Parameters:
    ///   - userInput: Original user input
    ///   - analysis: Analysis from first pass
    ///   - ollamaKit: OllamaKit instance
    ///   - activityType: Type of activity being generated
    ///   - isEasyNote: Whether this is EasyNote format
    ///   - noteFormat: Override note format
    /// - Returns: Generated structured note
    /// - Throws: ChatViewModelError if generation fails
    private func generateStructuredNote(
        userInput: String,
        analysis: (modalities: String, engagement: String),
        ollamaKit: OllamaKit,
        activityType: ActivityType,
        isEasyNote: Bool,
        noteFormat: String? = nil
    ) async throws -> String {
        // Get client context
        let clientContext = getClientContext()
        
        // Determine which note format to use (override from EasyNote or default)
        let formatToUse = noteFormat ?? selectedNoteFormat
        let noteFormatInfo = availableNoteFormats.first(where: { $0.id == formatToUse })
        
        // DEBUG: Track format selection
        print("DEBUG: generateStructuredNote - Format selection:")
        print("DEBUG: - noteFormat parameter: \(noteFormat ?? "nil")")
        print("DEBUG: - selectedNoteFormat: \(selectedNoteFormat)")
        print("DEBUG: - formatToUse: \(formatToUse)")
        print("DEBUG: - noteFormatInfo found: \(noteFormatInfo != nil)")
        print("DEBUG: - noteFormatTemplate.isEmpty: \(noteFormatTemplate.isEmpty)")
        
        // Determine if we should use template or standard format
        let useTemplate = !noteFormatTemplate.isEmpty
        
        let formatInstructions: String
        if useTemplate {
            print("DEBUG: Using custom template format")
            formatInstructions = """
            CRITICAL: Structure your response exactly according to the provided template:
            
            \(noteFormatTemplate)
            
            Format Rules:
            1. Follow the template structure exactly
            2. Do not add sections not present in the template
            3. Do not make up or fabricate any client information
            4. Use only the provided client information and context
            """
        } else {
            print("DEBUG: Using standard \(formatToUse) format")
            
            // Extract specific section requirements from the format definition
            let sectionInstructions = generateDetailedFormatInstructions(for: formatToUse, formatInfo: noteFormatInfo)
            
            formatInstructions = """
            CRITICAL: Structure your response using the \(formatToUse) format with these EXACT requirements:
            
            \(sectionInstructions)
            
            MANDATORY FORMAT RULES:
            1. Use the exact section headings shown above in bold
            2. Include ALL sections in the order specified
            3. Do not add any sections not listed above
            4. Do not combine or merge sections
            5. Do not change the section names or order
            6. Use clinical terminology appropriate for insurance documentation
            7. Base content only on provided session information and client context
            8. Do not invent or fabricate any client details not provided
            
            STRUCTURE EXAMPLE:
            **[Section Name]**
            [Content for that section]
            
            **[Next Section Name]**  
            [Content for that section]
            
            Remember: This note will be used for insurance billing and clinical records, so accuracy and format compliance are critical.
            """
        }
        
        // Create the second pass prompt
        let secondPassPrompt = """
        You are a clinical documentation assistant generating a structured \(activityType.rawValue.lowercased()).
        
        AVAILABLE CLIENT CONTEXT:
        \(clientContext)
        
        FIRST PASS ANALYSIS RESULTS:
        
        THERAPEUTIC MODALITIES AND INTERVENTIONS:
        \(analysis.modalities)
        
        CLIENT ENGAGEMENT AND RESPONSIVENESS:
        \(analysis.engagement)
        
        \(formatInstructions)
        
        ORIGINAL SESSION CONTENT:
        \(userInput)
        
        INSTRUCTIONS:
        - Use the analysis results to inform your clinical reasoning and documentation
        - Incorporate the identified modalities and interventions appropriately
        - Reference the client engagement patterns in your assessment
        - Follow the specified format structure exactly
        - Use only factual information from the provided context
        - Do not invent or assume any client details not provided
        - Ensure clinical terminology and professional language throughout
        - Make clear connections between interventions used and client responses
        """
        
        print("DEBUG: Second pass prompt format section preview:")
        print("DEBUG: \(String(formatInstructions.prefix(200)))...")
        
        // Generate the final note with streaming feedback for better UX
        return try await generateAnalysisWithStreaming(prompt: secondPassPrompt, ollamaKit: ollamaKit)
    }
    
    /// Enhanced session note generation with modality and engagement analysis (Legacy method for compatibility)
    /// - Parameters:
    ///   - transcript: The session transcript to analyze
    ///   - ollamaKit: The OllamaKit instance for AI analysis
    ///   - isEasyNote: Whether this is an EasyNote format
    ///   - providedModalities: Pre-selected modalities for EasyNote
    ///
    /// This method is kept for compatibility but now delegates to the new two-pass system
    func enhanceSessionNoteGeneration(
        transcript: String,
        ollamaKit: OllamaKit,
        isEasyNote: Bool = false,
        providedModalities: [String: [String]]? = nil
    ) async {
        // Check both the activity type and the selectedTask to ensure we're not in Brainstorm mode
        let activityType = getActivityTypeFromTask(selectedTask)
        
        // Skip enhancement for brainstorm activities
        guard let activeChat = activeChat,
              activityType != .brainstorm else {
            print("DEBUG: Skipping note enhancement for Brainstorm activity")
            // If we're in brainstorm mode, ensure the system prompt is set correctly
            if let activeChat = activeChat, activityType == .brainstorm {
                activeChat.systemPrompt = SystemPrompts.brainstorm
                print("DEBUG: Enforcing brainstorm system prompt")
            }
            return
        }

        print("DEBUG: Legacy enhanceSessionNoteGeneration called - updating system prompt only")
        
        // For legacy compatibility, just update the system prompt with basic format instructions
        // Get client context
        let clientContext = getClientContext()
        
        // Get the selected note format details
        let noteFormat = availableNoteFormats.first(where: { $0.id == selectedNoteFormat })
        
        // Update the system prompt for basic generation
        activeChat.systemPrompt = """
            You are a clinical documentation assistant helping generate a structured clinical note.
            
            AVAILABLE CLIENT CONTEXT:
            \(clientContext)
            
            CRITICAL: Structure your response using the \(selectedNoteFormat) format:
            \(noteFormat?.description ?? "")
            
            Format Rules:
            1. Use the exact section headings for \(selectedNoteFormat)
            2. Include ALL required sections
            3. Do not make up or fabricate any client information
            4. Use only the provided client information and context
            5. Ensure clinical terminology and proper context throughout
            
            \(isEasyNote ? "Use the provided structured form data to generate the note." : "Use the provided transcript and context to generate the note.")
            """
        
        // Ensure the MessageViewModel is up to date
        messageViewModel?.load(of: activeChat)
    }
    
    /// Gets the relevant context for the current client
    /// - Returns: A formatted string containing client context
    private func getClientContext() -> String {
        guard let client = selectedClient else {
            return "No client context available"
        }
        
        var context = """
        CLIENT INFORMATION:
        Name: \(client.identifier)
        """
        
        // Get the last treatment plan
        if let treatmentPlan = client.activities
            .filter({ $0.type == .treatmentPlan })
            .sorted(by: { $0.date > $1.date })
            .first {
            context += "\n\nLAST TREATMENT PLAN (\(formatDate(treatmentPlan.date))):\n\(treatmentPlan.content)"
        }
        
        // Get the last 2 session notes
        let recentNotes = client.activities
            .filter({ $0.type == .sessionNote })
            .sorted(by: { $0.date > $1.date })
            .prefix(2)
        
        if !recentNotes.isEmpty {
            context += "\n\nRECENT SESSION NOTES:"
            for note in recentNotes {
                context += "\n\nSESSION NOTE (\(formatDate(note.date))):\n\(note.content)"
            }
        }
        
        return context
    }
    
    /// Formats a date consistently
    /// - Parameter date: The date to format
    /// - Returns: A formatted date string
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    /// Generates an AI analysis with streaming feedback for better user experience
    /// - Parameters:
    ///   - prompt: The analysis prompt to send to the AI
    ///   - ollamaKit: The OllamaKit instance for AI interaction
    /// - Returns: The generated analysis
    /// - Throws: ChatViewModelError if generation fails
    ///
    /// This method provides real-time streaming updates to the UI so users can see
    /// the note being generated progressively, which improves the user experience
    /// during the potentially long second pass generation.
    private func generateAnalysisWithStreaming(prompt: String, ollamaKit: OllamaKit) async throws -> String {
        guard let activeChat = self.activeChat else {
            throw ChatViewModelError.generate("No active chat available")
        }
        
        print("DEBUG: Starting streaming analysis generation with prompt length: \(prompt.count)")
        print("DEBUG: Analysis prompt preview: \(String(prompt.prefix(100)))...")
        
        // Use direct OllamaKit API call with streaming updates to MessageViewModel
        let chatData = OKChatRequestData(
            model: activeChat.model,
            messages: [
                OKChatRequestData.Message(role: .system, content: activeChat.systemPrompt ?? ""),
                OKChatRequestData.Message(role: .user, content: prompt)
            ]
        )
        
        var fullResponse = ""
        var isReasoningContent = false
        
        do {
            print("DEBUG: Making streaming API call for analysis")
            
            // Clear any existing temp response and set loading state
            await MainActor.run {
                messageViewModel?.tempResponse = ""
                messageViewModel?.loading = .generate
            }
            
            for try await chunk in ollamaKit.chat(data: chatData) {
                guard let content = chunk.message?.content else { continue }
                
                // Handle reasoning content (like <think> tags) by skipping it
                if content.contains("<think>") {
                    isReasoningContent = true
                    continue
                }
                
                if content.contains("</think>") {
                    isReasoningContent = false
                    continue
                }
                
                // Only accumulate and display non-reasoning content
                if !isReasoningContent {
                    fullResponse += content
                    
                    // Update the UI with streaming content
                    await MainActor.run {
                        messageViewModel?.tempResponse = fullResponse
                    }
                }
                
                // Check if generation is done
                if chunk.done {
                    print("DEBUG: Streaming analysis generation completed")
                    print("DEBUG: Response length: \(fullResponse.count)")
                    break
                }
            }
            
            // Clear loading state
            await MainActor.run {
                messageViewModel?.loading = nil
                messageViewModel?.tempResponse = ""
            }
            
            // Validate we got a meaningful response
            let trimmedResponse = fullResponse.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedResponse.isEmpty else {
                throw ChatViewModelError.generate("Empty response from streaming analysis generation")
            }
            
            print("DEBUG: Streaming analysis generation successful")
            return trimmedResponse
            
        } catch {
            // Clear loading state on error
            await MainActor.run {
                messageViewModel?.loading = nil
                messageViewModel?.tempResponse = ""
            }
            
            print("DEBUG: Streaming analysis generation failed: \(error)")
            throw ChatViewModelError.generate("Streaming analysis generation failed: \(error.localizedDescription)")
        }
    }
    
    /// Generates detailed format instructions with specific section headings
    /// - Parameters:
    ///   - formatId: The format identifier (e.g., "PIRP", "SOAP")
    ///   - formatInfo: The format information object
    /// - Returns: Detailed instructions with specific section requirements
    private func generateDetailedFormatInstructions(for formatId: String, formatInfo: NoteFormat?) -> String {
        guard let formatInfo = formatInfo else {
            return "Use standard clinical note format with appropriate sections."
        }
        
        print("DEBUG: Generating detailed instructions for format: \(formatId)")
        
        // Extract section names and descriptions from the format description
        let sections = extractSectionsFromDescription(formatInfo.description)
        
        if sections.isEmpty {
            print("DEBUG: No sections found for \(formatId), using fallback")
            return """
            \(formatInfo.name) Format:
            \(formatInfo.description)
            
            Structure your note according to this format's requirements.
            """
        }
        
        // Build detailed section-by-section instructions
        var instructions = """
        \(formatInfo.name) (\(formatId)) Format:
        Focus: \(formatInfo.focus)
        
        REQUIRED SECTIONS (in exact order):
        
        """
        
        for (index, section) in sections.enumerated() {
            instructions += """
            \(index + 1). **\(section.name)**
               \(section.description)
               
            """
        }
        
        instructions += """
        
        SECTION FORMATTING:
        - Use the exact section names shown above as bold headings
        - Write comprehensive content for each section
        - Maintain the order specified above
        - Each section should contain substantial clinical content
        """
        
        print("DEBUG: Generated \(sections.count) sections for \(formatId)")
        return instructions
    }
    
    /// Extracts section names and descriptions from format description text
    /// - Parameter description: The format description containing bullet points
    /// - Returns: Array of section name/description pairs
    private func extractSectionsFromDescription(_ description: String) -> [(name: String, description: String)] {
        var sections: [(name: String, description: String)] = []
        
        // Split by lines and look for bullet point patterns
        let lines = description.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Look for bullet points with section names (• SectionName: Description)
            if trimmed.hasPrefix("•") || trimmed.hasPrefix("-") {
                // Remove bullet point
                let withoutBullet = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
                
                // Split on colon to separate name from description
                if let colonIndex = withoutBullet.firstIndex(of: ":") {
                    let sectionName = String(withoutBullet[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                    let sectionDescription = String(withoutBullet[withoutBullet.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                    
                    if !sectionName.isEmpty && !sectionDescription.isEmpty {
                        sections.append((name: sectionName, description: sectionDescription))
                    }
                }
            }
        }
        
        return sections
    }
    
    /// Handles client selection changes and clears chat appropriately
    func onClientSelected() {
        print("DEBUG: onClientSelected() called - selectedClientID: \(selectedClientID?.uuidString ?? "nil")")
        
        // Clear chat view when switching clients
        clearChatView()
        
        // Clear activity selection since activities are client-specific
        selectedActivityID = nil
        
        // Reset to default activity type
        selectedActivityType = .sessionNote
        selectedTask = "Create a Client Session Note"
        
        print("DEBUG: Client switched - chat cleared and activity selection reset")
    }
}

enum ChatViewModelLoading {
    case fetchModels
}

enum ChatViewModelError: Error {
    case fetchModels(String)
    case load(String)
    case generate(String)
}

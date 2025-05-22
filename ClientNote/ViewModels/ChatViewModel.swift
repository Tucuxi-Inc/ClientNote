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
        guard let selectedClientIndex = clients.firstIndex(where: { $0.id == selectedClientID }),
              let selectedActivityID = selectedActivityID else {
            return nil
        }
        return clients[selectedClientIndex].activities.first { $0.id == selectedActivityID }
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
    
    /// Loads the chat history for a specific activity
    /// - Parameter activity: The activity whose chat history should be loaded
    ///
    /// This method performs several operations:
    /// 1. Removes any existing active chat
    /// 2. Creates a new chat with appropriate system prompt
    /// 3. Loads and parses the activity's content
    /// 4. Handles both JSON and legacy content formats
    /// 5. Updates the UI state for the new chat
    ///
    /// The content parsing supports two formats:
    /// - JSON array of message dictionaries (newer format)
    /// - Plain text content (legacy format)
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
            print("DEBUG: Raw content: \(activity.content)")
            guard let contentData = activity.content.data(using: .utf8) else {
                print("DEBUG: Could not convert content to data")
                return
            }
            
            // Try to decode as JSON array first
            do {
                let chatHistory = try JSONDecoder().decode([[String: String]].self, from: contentData)
                print("DEBUG: Successfully decoded JSON chat history with \(chatHistory.count) messages")
                
                for messageData in chatHistory {
                    if let prompt = messageData["prompt"] {
                        let message = Message(prompt: prompt)
                        message.chat = chat
                        message.response = messageData["response"]
                        chat.messages.append(message)
                    }
                }
            } catch {
                print("DEBUG: JSON parsing failed, treating as legacy content: \(error)")
                // Handle legacy content format or invalid data by creating a single message
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
    
    // MARK: - Activity Management
    
    /// Creates a new activity and associated chat session
    /// - Parameter isEasyNote: Whether this activity is created through the EasyNote interface
    ///
    /// This method performs several operations:
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
        
        // Create a new chat for this activity with the appropriate system prompt
        let chat = Chat(model: Defaults[.defaultModel])
        chat.systemPrompt = getSystemPromptForActivityType(type, isEasyNote: isEasyNote)
        modelContext.insert(chat)
        chats.insert(chat, at: 0)
        activeChat = chat
        
        // Add and select the new activity
        clients[clientIndex].activities.insert(newActivity, at: 0)
        saveClient(clients[clientIndex])
        selectedActivityID = newActivity.id
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
        if let selectedID = selectedActivityID {
            // Validate that the selected activity exists
            guard let activity = filteredActivities.first(where: { $0.id == selectedID }) else {
                print("DEBUG: Invalid activity selection: \(selectedID)")
                // Reset to first available activity or clear selection
                if let firstActivity = filteredActivities.first {
                    selectedActivityID = firstActivity.id
                    print("DEBUG: Reset to first available activity: \(firstActivity.id)")
                } else {
                    selectedActivityID = nil
                    print("DEBUG: No valid activities available")
                }
                return
            }
            
            print("DEBUG: Valid activity selected: \(activity.id)")
            // Update the selected task to match the activity type
            selectedTask = taskForActivityType(activity.type)
            
            // Clear current chat and create new one for this activity
            loadActivityChat(activity)
        }
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
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let jsonData = try encoder.encode(messageHistory)
            
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("DEBUG: Saving chat history with \(messageHistory.count) messages")
                print("DEBUG: JSON preview: \(String(jsonString.prefix(200)))...")
                clients[clientIndex].activities[activityIndex].content = jsonString
                saveClient(clients[clientIndex])
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
        You are a clinical documentation assistant helping create a comprehensive treatment plan.
        Focus on creating a structured, goal-oriented plan that meets clinical requirements.

        Requirements:
        1. Include clear treatment goals
        2. Specify measurable outcomes
        3. List specific interventions
        4. Include timeframes
        5. Address presenting problems
        
        [Placeholder for full Treatment Plan prompt]
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
        
        // Get modalities analysis
        let modalitiesAnalysis: String
        if isEasyNote, let modalities = providedModalities {
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
            let analysisPrompt = getModalitiesAnalysisPrompt() + "\n\nSession Transcript:\n" + transcript
            modalitiesAnalysis = try await generateAnalysis(prompt: analysisPrompt, ollamaKit: ollamaKit)
        }
        
        // Get engagement patterns analysis
        let engagementPrompt = getEngagementPatternsPrompt() + "\n\nSession Transcript:\n" + transcript
        let engagementAnalysis = try await generateAnalysis(prompt: engagementPrompt, ollamaKit: ollamaKit)
        
        return (modalities: modalitiesAnalysis, engagement: engagementAnalysis)
    }
    
    /// Generates an AI analysis based on a specific prompt
    /// - Parameters:
    ///   - prompt: The analysis prompt to send to the AI
    ///   - ollamaKit: The OllamaKit instance for AI interaction
    /// - Returns: The generated analysis
    /// - Throws: ChatViewModelError if generation fails
    private func generateAnalysis(prompt: String, ollamaKit: OllamaKit) async throws -> String {
        guard let messageViewModel = self.messageViewModel else {
            throw ChatViewModelError.generate("MessageViewModel not available")
        }
        
        guard let activeChat = self.activeChat else {
            throw ChatViewModelError.generate("No active chat available")
        }
        
        let analysisMessage = Message(prompt: prompt)
        analysisMessage.chat = activeChat
        
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    let currentMessages = messageViewModel.messages
                    messageViewModel.generate(ollamaKit, activeChat: activeChat, prompt: prompt)
                    
                    while messageViewModel.loading == .generate {
                        try await Task.sleep(nanoseconds: 100_000_000)
                    }
                    
                    if let lastMessage = messageViewModel.messages.last,
                       let response = lastMessage.response {
                        messageViewModel.messages = currentMessages
                        continuation.resume(returning: response)
                    } else {
                        continuation.resume(throwing: ChatViewModelError.generate("Failed to generate analysis"))
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
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
    
    /// Enhances session note generation with modality and engagement analysis
    /// - Parameters:
    ///   - transcript: The session transcript to analyze
    ///   - ollamaKit: The OllamaKit instance for AI analysis
    ///   - isEasyNote: Whether this is an EasyNote format
    ///   - providedModalities: Pre-selected modalities for EasyNote
    ///
    /// This method:
    /// 1. Performs comprehensive session analysis
    /// 2. Updates the system prompt with analysis results
    /// 3. Integrates findings into note generation
    /// 4. Handles both structured and unstructured note formats
    func enhanceSessionNoteGeneration(
        transcript: String,
        ollamaKit: OllamaKit,
        isEasyNote: Bool = false,
        providedModalities: [String: [String]]? = nil
    ) async {
        do {
            let analysis = try await performSessionAnalysis(
                transcript: transcript,
                ollamaKit: ollamaKit,
                isEasyNote: isEasyNote,
                providedModalities: providedModalities
            )
            
            if let activeChat = activeChat {
                let currentPrompt = activeChat.systemPrompt ?? getSystemPromptForActivityType(.sessionNote)
                activeChat.systemPrompt = """
                    \(currentPrompt)
                    
                    Consider the following analyses for this session:
                    
                    THERAPEUTIC MODALITIES AND INTERVENTIONS:
                    \(analysis.modalities)
                    
                    CLIENT ENGAGEMENT AND RESPONSIVENESS:
                    \(analysis.engagement)
                    
                    \(isEasyNote ? "Use the provided structured form data to generate the note." : "Analyze the transcript to generate the note.")
                    Incorporate these analyses into your note, ensuring proper clinical terminology and context.
                    Pay particular attention to accurately describing the client's engagement and response to interventions.
                    """
            }
        } catch {
            self.error = .generate(error.localizedDescription)
        }
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

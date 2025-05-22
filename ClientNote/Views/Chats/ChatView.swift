//
//  ChatView.swift
//  ClientNote
//
//  Created by Kevin Hermawan on 8/2/24.
//

import Defaults
import ChatField
import OllamaKit
import SwiftUI
import ViewCondition
import Speech
import AVFoundation

@Observable
class SpeechRecognitionViewModel {
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    
    var isRecording = false
    var showingPermissionAlert = false
    var showingErrorAlert = false
    var errorMessage = ""
    
    init() {
        requestSpeechRecognitionPermission()
    }
    
    private func requestSpeechRecognitionPermission() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
                case .denied, .restricted, .notDetermined:
                    self.showingPermissionAlert = true
                @unknown default:
                    self.showingPermissionAlert = true
                }
            }
        }
    }
    
    func startRecording(completion: @escaping (String) -> Void) {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            errorMessage = "Speech recognition is not available on this device."
            showingErrorAlert = true
            return
        }
        
        do {
            if audioEngine.isRunning {
                audioEngine.stop()
                recognitionRequest?.endAudio()
                isRecording = false
                return
            }
            
            recognitionTask?.cancel()
            recognitionTask = nil
            
            let inputNode = audioEngine.inputNode
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else {
                errorMessage = "Unable to create recognition request. Please try again."
                showingErrorAlert = true
                return
            }
            
            recognitionRequest.shouldReportPartialResults = true
            
            recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { result, error in
                if let error = error {
                    if let error = error as NSError? {
                        switch (error.domain, error.code) {
                        case ("kLSRErrorDomain", 301):
                            return
                        case ("kAFAssistantErrorDomain", 1101):
                            return
                        case (_, 1110):
                            if self.isRecording {
                                self.errorMessage = "No speech detected. Please try speaking again."
                                self.showingErrorAlert = true
                            }
                        default:
                            if !self.isRecording { return }
                            self.errorMessage = "Speech recognition error: \(error.localizedDescription)"
                            self.showingErrorAlert = true
                        }
                    }
                    self.stopRecording()
                    return
                }
                
                guard let result = result else { return }
                
                DispatchQueue.main.async {
                    if !result.bestTranscription.formattedString.isEmpty {
                        completion(result.bestTranscription.formattedString)
                    }
                }
            }
            
            guard recognitionTask != nil else {
                errorMessage = "Failed to create recognition task. Please try again."
                showingErrorAlert = true
                return
            }
            
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                self.recognitionRequest?.append(buffer)
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true
        } catch {
            errorMessage = "Error starting recording: \(error.localizedDescription)"
            showingErrorAlert = true
            stopRecording()
        }
    }
    
    func stopRecording() {
        recognitionTask?.cancel()
        recognitionTask = nil
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        isRecording = false
    }
    
    func cleanup() {
        stopRecording()
        speechRecognizer = nil
    }
}

struct ChatView: View {
    @Environment(ChatViewModel.self) private var chatViewModel
    @Environment(MessageViewModel.self) private var messageViewModel
    @Environment(CodeHighlighter.self) private var codeHighlighter

    @AppStorage("experimentalCodeHighlighting") private var experimentalCodeHighlighting = false
    @Default(.fontSize) private var fontSize: Double

    @State private var ollamaKit: OllamaKit
    @State private var prompt = ""
    @State private var scrollProxy: ScrollViewProxy? = nil
    @State private var isPreferencesPresented = false
    @State private var isEasyNotePresented = false
    @State private var showAddClientSheet = false
    @FocusState private var isFocused: Bool
    
    private let taskOptions = [
        "Create a Treatment Plan",
        "Create a Client Session Note",
        "Brainstorm"
    ]
    
    init() {
        let baseURL = URL(string: Defaults[.defaultHost])!
        self._ollamaKit = State(initialValue: OllamaKit(baseURL: baseURL))
    }
    
    private func updateSystemPrompt() {
        // Get the appropriate system prompt from ChatViewModel
        let type = chatViewModel.getActivityTypeFromTask(chatViewModel.selectedTask)
        let systemPrompt = chatViewModel.getSystemPromptForActivityType(type)
        
        // Update the active chat's system prompt
        chatViewModel.activeChat?.systemPrompt = systemPrompt
    }
    
    var body: some View {
        MainChatContent(
            prompt: $prompt,
            messageViewModel: messageViewModel,
            chatViewModel: chatViewModel,
            fontSize: fontSize,
            isFocused: _isFocused,
            isEasyNotePresented: $isEasyNotePresented,
            isPreferencesPresented: $isPreferencesPresented,
            showAddClientSheet: $showAddClientSheet,
            ollamaKit: $ollamaKit,
            taskOptions: taskOptions,
            copyAction: copyAction,
            generateAction: generateAction,
            regenerateAction: regenerateAction,
            onActiveChatChanged: onActiveChatChanged,
            updateSystemPrompt: updateSystemPrompt
        )
        .sheet(isPresented: $isEasyNotePresented, onDismiss: {
            print("DEBUG: ChatView - EasyNote sheet dismissed")
        }) {
            NavigationView {
                EasyNoteSheet(prompt: $prompt, generateAction: {
                    print("DEBUG: ChatView - EasyNote generateAction called")
                    if !prompt.isEmpty {
                        print("DEBUG: ChatView - Processing EasyNote prompt, length: \(prompt.count)")
                        chatViewModel.handleGenerateAction(prompt: prompt)
                    } else {
                        print("DEBUG: ChatView - Empty prompt from EasyNote")
                    }
                })
            }
            .frame(minWidth: 1000, minHeight: 800)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    // MARK: - Helper Views
    
    struct MainChatContent: View {
        @Binding var prompt: String
        let messageViewModel: MessageViewModel
        let chatViewModel: ChatViewModel
        let fontSize: Double
        @FocusState var isFocused: Bool
        @Binding var isEasyNotePresented: Bool
        @Binding var isPreferencesPresented: Bool
        @Binding var showAddClientSheet: Bool
        @Binding var ollamaKit: OllamaKit
        let taskOptions: [String]
        let copyAction: (_ content: String) -> Void
        let generateAction: () -> Void
        let regenerateAction: () -> Void
        let onActiveChatChanged: () -> Void
        let updateSystemPrompt: () -> Void
        
        @State private var scrollProxy: ScrollViewProxy? = nil
        @Environment(CodeHighlighter.self) private var codeHighlighter
        @AppStorage("experimentalCodeHighlighting") private var experimentalCodeHighlighting = false
        
        var body: some View {
            ScrollViewReader { proxy in
                VStack {
                    MessagesListView(
                        messages: messageViewModel.messages,
                        tempResponse: messageViewModel.tempResponse,
                        isGenerating: messageViewModel.loading == .generate,
                        copyAction: copyAction,
                        regenerateAction: regenerateAction
                    )
                    .scrollContentBackground(.hidden)
                    .background(Color.euniFieldBackground.opacity(0.5))
                    
                    ChatInputView(
                        prompt: $prompt,
                        isEasyNotePresented: $isEasyNotePresented,
                        messageViewModel: messageViewModel,
                        chatViewModel: chatViewModel,
                        fontSize: fontSize,
                        isFocused: _isFocused,
                        generateAction: generateAction,
                        onActiveChatChanged: onActiveChatChanged
                    )
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    .padding(.horizontal)
                    .visible(if: chatViewModel.activeChat.isNotNil, removeCompletely: true)
                }
                .onAppear {
                    self.scrollProxy = proxy
                }
                .onChange(of: chatViewModel.activeChat?.id) { _, _ in
                    onActiveChatChanged()
                }
                .onChange(of: messageViewModel.tempResponse) { _, _ in
                    if let proxy = scrollProxy {
                        scrollToBottom(proxy: proxy, messages: messageViewModel.messages)
                    }
                }
                .onChange(of: fontSize) { _, _ in
                    codeHighlighter.fontSize = fontSize
                }
                .onChange(of: experimentalCodeHighlighting) { _, _ in
                    codeHighlighter.enabled = experimentalCodeHighlighting
                }
            }
            .navigationTitle("")
            .toolbar {
                Group {
                    // Left: New Session Button and Activity Picker
                    ToolbarItem(placement: .navigation) {
                        HStack(spacing: 16) {
                            // New Session Button
                            Button(action: {
                                chatViewModel.createNewActivity()
                                
                                // Ensure the view resets to the new activity
                                prompt = ""
                                if let newActivityId = chatViewModel.selectedActivityID {
                                    DispatchQueue.main.async {
                                        // Force loading the activity chat
                                        if let clientIndex = chatViewModel.clients.firstIndex(where: { $0.id == chatViewModel.selectedClientID }),
                                           let activity = chatViewModel.clients[clientIndex].activities.first(where: { $0.id == newActivityId }) {
                                            chatViewModel.loadActivityChat(activity)
                                            messageViewModel.load(of: chatViewModel.activeChat)
                                        }
                                    }
                                }
                            }) {
                                Image(systemName: "square.and.pencil")
                                    .foregroundColor(Color.euniPrimary)
                            }
                            .keyboardShortcut("n")
                            .help("Create new activity")
                            
                            // Activity Picker
                            VStack(spacing: 4) {
                                Text("Activity")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color.euniSecondary)
                                Picker("Choose Activity", selection: Binding(
                                    get: { chatViewModel.selectedTask },
                                    set: { chatViewModel.selectedTask = $0 }
                                )) {
                                    ForEach(taskOptions, id: \.self) { task in
                                        Text(task).tag(task)
                                    }
                                }
                                .frame(width: 200)
                                .onChange(of: chatViewModel.selectedTask) { _, _ in
                                    updateSystemPrompt()
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }

                    // Center: Client Picker
                    ToolbarItem(placement: .principal) {
                        VStack(spacing: 4) {
                            Text("Client")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color.euniSecondary)
                            Picker("Choose Client", selection: Binding(
                                get: { chatViewModel.selectedClientID ?? UUID(uuidString: "00000000-0000-0000-0000-000000000001")! },
                                set: { newValue in
                                    if newValue == UUID(uuidString: "00000000-0000-0000-0000-000000000000") {
                                        showAddClientSheet = true
                                    } else if newValue != UUID(uuidString: "00000000-0000-0000-0000-000000000001") {
                                        chatViewModel.selectedClientID = newValue
                                    }
                                }
                            )) {
                                Text("Choose Client").tag(UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)
                                ForEach(chatViewModel.clients) { client in
                                    Text(client.identifier).tag(client.id)
                                }
                                Text("Add New Client").tag(UUID(uuidString: "00000000-0000-0000-0000-000000000000")!)
                            }
                            .frame(width: 200)
                        }
                        .padding(.vertical, 8)
                    }

                    // Right side items
                    ToolbarItem(placement: .automatic) {
                        HStack(spacing: 16) {
                            VStack(spacing: 4) {
                                Text("Assistant")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color.euniSecondary)
                                Picker("Choose an Assistant", selection: Binding(
                                    get: { chatViewModel.activeChat?.model ?? "" },
                                    set: { newModel in
                                        chatViewModel.activeChat?.model = newModel
                                    }
                                )) {
                                    ForEach(chatViewModel.models, id: \.self) { model in
                                        Text(AssistantModel.nameFor(modelId: model)).tag(model)
                                    }
                                }
                                .frame(width: 200)
                            }
                            
                            // Preferences button
                            Button(action: { isPreferencesPresented.toggle() }) {
                                Image(systemName: "sidebar.trailing")
                            }
                            .foregroundColor(Color.euniSecondary)
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .sheet(isPresented: $showAddClientSheet, onDismiss: {
                if let last = chatViewModel.clients.last {
                    chatViewModel.selectedClientID = last.id
                }
            }) {
                NavigationStack {
                    AddClientView()
                }
                .frame(minWidth: 600, minHeight: 900)
            }
            .inspector(isPresented: $isPreferencesPresented) {
                ChatPreferencesView(ollamaKit: $ollamaKit)
                    .inspectorColumnWidth(min: 320, ideal: 320)
            }
            .onChange(of: chatViewModel.activeChat?.id) { oldValue, newValue in
                print("DEBUG: ChatView - Active chat changed: \(oldValue?.uuidString ?? "nil") -> \(newValue?.uuidString ?? "nil")")
                onActiveChatChanged()
            }
        }
        
        private func scrollToBottom(proxy: ScrollViewProxy, messages: [Message]) {
            guard messages.count > 0 else { return }
            guard let lastMessage = messages.last else { return }
            
            DispatchQueue.main.async {
                proxy.scrollTo(lastMessage, anchor: .bottom)
            }
        }
    }
    
    struct MessagesListView: View {
        let messages: [Message]
        let tempResponse: String
        let isGenerating: Bool
        let copyAction: (_ content: String) -> Void
        let regenerateAction: () -> Void
        
        var body: some View {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(messages) { message in
                        VStack(spacing: 16) {
                            UserMessageView(content: message.displayPrompt, copyAction: copyAction)
                            
                            if let response = message.response {
                                AssistantMessageView(
                                    content: response,
                                    isGenerating: false,
                                    isLastMessage: message == messages.last,
                                    copyAction: copyAction,
                                    regenerateAction: regenerateAction
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    if !tempResponse.isEmpty {
                        AssistantMessageView(
                            content: tempResponse,
                            isGenerating: true,
                            isLastMessage: true,
                            copyAction: copyAction,
                            regenerateAction: regenerateAction
                        )
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
        }
    }
    
    struct ChatInputView: View {
        @Binding var prompt: String
        @Binding var isEasyNotePresented: Bool
        let messageViewModel: MessageViewModel
        let chatViewModel: ChatViewModel
        let fontSize: Double
        @FocusState var isFocused: Bool
        let generateAction: () -> Void
        let onActiveChatChanged: () -> Void
        
        var body: some View {
            VStack {
                ChatFieldView(
                    prompt: $prompt,
                    isEasyNotePresented: $isEasyNotePresented,
                    messageViewModel: messageViewModel,
                    chatViewModel: chatViewModel,
                    fontSize: fontSize,
                    isFocused: _isFocused,
                    generateAction: generateAction,
                    onActiveChatChanged: onActiveChatChanged
                )
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func onActiveChatChanged() {
        print("DEBUG: ChatView - onActiveChatChanged called")
        self.prompt = ""
        if chatViewModel.shouldFocusPrompt {
            chatViewModel.shouldFocusPrompt = false
            Task {
                try await Task.sleep(for: .seconds(0.8))
                withAnimation {
                    self.isFocused = true
                }
            }
        }

        if let activeChat = chatViewModel.activeChat, 
           let host = activeChat.host, 
           let baseURL = URL(string: host) {
            print("DEBUG: ChatView - Updating OllamaKit with host: \(host)")
            self.ollamaKit = OllamaKit(baseURL: baseURL)
            
            // Check Ollama connection with retry
            Task {
                var retryCount = 0
                let maxRetries = 3
                
                while retryCount < maxRetries {
                    do {
                        let isReachable = await ollamaKit.reachable()
                        if isReachable {
                            print("DEBUG: ChatView - Successfully connected to Ollama")
                            self.chatViewModel.isHostReachable = true
                            self.chatViewModel.fetchModels(self.ollamaKit)
                            break
                        } else {
                            print("DEBUG: ChatView - Ollama not reachable, attempt \(retryCount + 1) of \(maxRetries)")
                            self.chatViewModel.isHostReachable = false
                            retryCount += 1
                            if retryCount < maxRetries {
                                try await Task.sleep(for: .seconds(2))
                            }
                        }
                    } catch {
                        print("DEBUG: ChatView - Error connecting to Ollama: \(error)")
                        retryCount += 1
                        if retryCount < maxRetries {
                            try await Task.sleep(for: .seconds(2))
                        }
                    }
                }
                
                if retryCount >= maxRetries {
                    print("DEBUG: ChatView - Failed to connect to Ollama after \(maxRetries) attempts")
                    // Update UI to show connection error
                    DispatchQueue.main.async {
                        self.chatViewModel.error = .fetchModels("Unable to connect to Ollama server after multiple attempts. Please verify that Ollama is running and accessible at \(host)")
                    }
                }
            }
        }
    }
    
    private func copyAction(_ content: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
    }
    
    private func generateAction() {
        print("DEBUG: ChatView - generateAction called")
        guard let activeChat = chatViewModel.activeChat, 
              !activeChat.model.isEmpty, 
              chatViewModel.isHostReachable else {
            print("DEBUG: ChatView - Cannot generate: activeChat=\(chatViewModel.activeChat != nil), model=\(chatViewModel.activeChat?.model ?? "nil"), reachable=\(chatViewModel.isHostReachable)")
            return
        }

        if messageViewModel.loading == .generate {
            print("DEBUG: ChatView - Cancelling existing generation")
            messageViewModel.cancelGeneration()
        } else {
            let promptToSend = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !promptToSend.isEmpty else {
                print("DEBUG: ChatView - Empty prompt, clearing")
                self.prompt = ""
                return
            }

            // Verify that the system prompt matches the selected activity type
            let activityType = chatViewModel.getActivityTypeFromTask(chatViewModel.selectedTask)
            let expectedPrompt = chatViewModel.getSystemPromptForActivityType(activityType)
            
            if activityType == .brainstorm && activeChat.systemPrompt != expectedPrompt {
                print("DEBUG: ChatView - Correcting system prompt for Brainstorm before generating")
                activeChat.systemPrompt = expectedPrompt
            }
            
            print("DEBUG: ChatView - Generating with prompt length: \(promptToSend.count) for activity type: \(activityType.rawValue)")
            print("DEBUG: ChatView - Prompt preview: \(String(promptToSend.prefix(100)))...")
            
            // Use the new method to handle generation properly
            chatViewModel.handleGenerateAction(prompt: promptToSend)
        }
        
        self.prompt = ""
    }
    
    private func regenerateAction() {
        guard let activeChat = chatViewModel.activeChat, !activeChat.model.isEmpty, chatViewModel.isHostReachable else { return }
        
        if messageViewModel.loading == .generate {
            messageViewModel.cancelGeneration()
        } else {
            guard let activeChat = chatViewModel.activeChat else { return }
            
            messageViewModel.regenerate(activeChat: activeChat)
        }
        
        prompt = ""
    }
}

struct ChatFieldView: View {
    @Binding var prompt: String
    @Binding var isEasyNotePresented: Bool
    let messageViewModel: MessageViewModel
    let chatViewModel: ChatViewModel
    let fontSize: Double
    @FocusState var isFocused: Bool
    let generateAction: () -> Void
    let onActiveChatChanged: () -> Void
    @State private var speechRecognitionVM = SpeechRecognitionViewModel()
    @State private var textHeight: CGFloat = 40
    
    // Add state for tracking which easy sheet to show
    @State private var activeEasySheet: EasySheetType = .none
    @State private var showEasySheet = false
    
    // Enum to track which sheet to show
    private enum EasySheetType {
        case note
        case treatmentPlan
        case none
    }
    
    private var showEasyButton: Bool {
        chatViewModel.selectedTask.contains("Session Note") ||
        chatViewModel.selectedTask.contains("Treatment Plan")
    }
    
    private var easyButtonIcon: String {
        switch chatViewModel.selectedTask {
        case "Create a Client Session Note":
            return "note.text.badge.plus"
        case "Create a Treatment Plan":
            return "checklist.checked"
        default:
            return "note.text.badge.plus"
        }
    }
    
    private var easyButtonLabel: String {
        switch chatViewModel.selectedTask {
        case "Create a Client Session Note":
            return "Easy Note"
        case "Create a Treatment Plan":
            return "Easy Plan"
        default:
            return "Easy Note"
        }
    }
    
    private func handleEasyButtonTap() {
        print("DEBUG: Easy button clicked for task: \(chatViewModel.selectedTask)")
        updateActiveEasySheet()
        showEasySheet = true
        print("DEBUG: showEasySheet set to true")
    }
    
    private func updateActiveEasySheet() {
        switch chatViewModel.selectedTask {
        case "Create a Client Session Note":
            print("DEBUG: Setting activeEasySheet to .note")
            activeEasySheet = .note
        case "Create a Treatment Plan":
            print("DEBUG: Setting activeEasySheet to .treatmentPlan")
            activeEasySheet = .treatmentPlan
        default:
            print("DEBUG: Setting activeEasySheet to .none")
            activeEasySheet = .none
        }
    }
    
    var body: some View {
        VStack {
            HStack(alignment: .top, spacing: 8) {
                // Left column with Easy Button and Microphone Button
                VStack(spacing: 8) {
                    // Easy Button - only shown for Session Note and Treatment Plan
                    if showEasyButton {
                        Button(action: handleEasyButtonTap) {
                            Image(systemName: easyButtonIcon)
                                .foregroundStyle(.white)
                                .fontWeight(.bold)
                                .padding(8)
                        }
                        .help(easyButtonLabel)
                        .background(Color.euniPrimary)
                        .buttonStyle(.borderless)
                        .clipShape(.circle)
                    }
                    
                    // Microphone Button - always visible for all activity types
                    Button {
                        if speechRecognitionVM.isRecording {
                            speechRecognitionVM.stopRecording()
                        } else {
                            speechRecognitionVM.startRecording { transcribedText in
                                prompt = transcribedText
                            }
                        }
                    } label: {
                        Image(systemName: speechRecognitionVM.isRecording ? "stop.circle.fill" : "mic.circle")
                            .foregroundStyle(Color.euniText)
                            .fontWeight(.bold)
                            .padding(8)
                    }
                    .background(speechRecognitionVM.isRecording ? Color.euniError : Color.euniSecondary)
                    .buttonStyle(.borderless)
                    .clipShape(.circle)
                }
                
                // Chat Field
                TextEditor(text: $prompt)
                    .font(.system(size: fontSize))
                    .frame(height: max(40, textHeight))
                    .scrollContentBackground(.hidden)
                    .background(Color.euniFieldBackground)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.euniBorder, lineWidth: 1)
                    )
                    .focused($isFocused)
                    .onChange(of: prompt) { _, newValue in
                        let size = CGSize(width: NSScreen.main?.frame.width ?? 800 - 100, height: .infinity)
                        let estimatedHeight = newValue.boundingRect(
                            with: size,
                            options: [.usesLineFragmentOrigin, .usesFontLeading],
                            attributes: [.font: NSFont.systemFont(ofSize: fontSize)],
                            context: nil
                        ).height
                        textHeight = min(max(40, estimatedHeight + 20), 200)
                    }
                    .onSubmit {
                        if messageViewModel.loading != .generate {
                            generateAction()
                        }
                    }
                
                // Send Button
                Button(action: generateAction) {
                    Image(systemName: messageViewModel.loading == .generate ? "stop.fill" : "arrow.up")
                        .foregroundStyle(Color.euniText)
                        .fontWeight(.bold)
                        .padding(8)
                }
                .background(messageViewModel.loading == .generate ? Color.euniError : Color.euniPrimary)
                .buttonStyle(.borderless)
                .clipShape(.circle)
                .disabled(prompt.isEmpty && messageViewModel.loading != .generate)
            }
            .padding(8)
            .background(Color.euniFieldBackground)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.euniBorder, lineWidth: 1)
            )
            
            // Footer
            if chatViewModel.loading != nil {
                ProgressView()
                    .controlSize(.small)
            } else if case .fetchModels(let message) = chatViewModel.error {
                HStack {
                    Text(message)
                        .foregroundStyle(.red)
                    
                    Button("Try Again", action: onActiveChatChanged)
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                }
                .font(.callout)
            } else if messageViewModel.messages.isEmpty == false {
                Text("\u{2318}+R to regenerate the response")
                    .font(.callout)
                    .foregroundColor(.secondary)
            } else {
                Text("AI can make mistakes. Please double-check responses.")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
        }
        .alert("Microphone Access Required", isPresented: $speechRecognitionVM.showingPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                    NSWorkspace.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please grant microphone access in System Settings to use voice input.")
        }
        .alert("Speech Recognition Error", isPresented: $speechRecognitionVM.showingErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(speechRecognitionVM.errorMessage)
        }
        .onAppear {
            // Initialize the activeEasySheet based on the default task
            updateActiveEasySheet()
        }
        .onChange(of: chatViewModel.selectedTask) { oldValue, newValue in
            // Update activeEasySheet whenever the task changes
            updateActiveEasySheet()
        }
        .sheet(isPresented: $showEasySheet, onDismiss: {
            print("DEBUG: Sheet dismissed, activeEasySheet was: \(activeEasySheet)")
            activeEasySheet = .none
            print("DEBUG: Reset activeEasySheet to .none")
        }) {
            switch activeEasySheet {
            case .note:
                NavigationView {
                    EasyNoteSheet(prompt: $prompt, generateAction: {
                        if !prompt.isEmpty {
                            generateAction()
                        }
                    })
                }
                .frame(minWidth: 1000, minHeight: 800)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .treatmentPlan:
                NavigationView {
                    EasyTreatmentPlanSheet(prompt: $prompt, generateAction: generateAction)
                }
                .frame(minWidth: 1000, minHeight: 800)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .none:
                EmptyView()
            }
        }
    }
}

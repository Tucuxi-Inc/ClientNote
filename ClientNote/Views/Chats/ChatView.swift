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
    @FocusState private var isFocused: Bool
    
    init() {
        let baseURL = URL(string: Defaults[.defaultHost])!
        self._ollamaKit = State(initialValue: OllamaKit(baseURL: baseURL))
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
            ollamaKit: $ollamaKit,
            copyAction: copyAction,
            generateAction: generateAction,
            regenerateAction: regenerateAction,
            onActiveChatChanged: onActiveChatChanged
        )
        .sheet(isPresented: $isEasyNotePresented, onDismiss: {
            print("DEBUG: ChatView - EasyNote sheet dismissed")
        }) {
            NavigationView {
                EasyNoteSheet(prompt: $prompt, generateAction: {
                    print("DEBUG: ChatView - EasyNote generateAction called")
                    if !prompt.isEmpty {
                        print("DEBUG: ChatView - Processing EasyNote prompt, length: \(prompt.count)")
                        DispatchQueue.main.async {
                            generateAction()
                        }
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
        @Binding var ollamaKit: OllamaKit
        let copyAction: (_ content: String) -> Void
        let generateAction: () -> Void
        let regenerateAction: () -> Void
        let onActiveChatChanged: () -> Void
        
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
            .navigationTitle(chatViewModel.selectedClient?.identifier ?? "No Client Selected")
            .toolbar {
                Group {
                    // Centered app name
                    ToolbarItem(placement: .principal) {
                        Text("Euni™ - Client Notes")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(Color.euniText)
                    }
                    // Right: Activity and Assistant Name
                    ToolbarItem(placement: .automatic) {
                        HStack(spacing: 24) {
                            // Show selected activity title or type
                            if let activity = chatViewModel.selectedActivity {
                                Text(activity.displayTitle)
                                    .font(.headline)
                                    .foregroundColor(Color.euniSecondary)
                                    .layoutPriority(1)
                            } else {
                                // Show selected task type
                                let taskType = chatViewModel.selectedTask.replacingOccurrences(of: "Create a ", with: "")
                                Text(taskType)
                                    .font(.headline)
                                    .foregroundColor(Color.euniSecondary)
                                    .layoutPriority(1)
                            }
                            // Assistant Name (right aligned, can truncate)
                            if let model = chatViewModel.activeChat?.model, !model.isEmpty {
                                Text(AssistantModel.nameFor(modelId: model))
                                    .font(.headline)
                                    .foregroundColor(Color.euniSecondary)
                                    .lineLimit(1)
                                    .frame(maxWidth: 200, alignment: .trailing)
                            } else {
                                Text("")
                                    .frame(maxWidth: 200, alignment: .trailing)
                            }
                        }
                    }
                    // Preferences button (sidebar.trailing icon)
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: { isPreferencesPresented.toggle() }) {
                            Image(systemName: "sidebar.trailing")
                        }
                        .foregroundColor(Color.euniSecondary)
                    }
                }
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
            self.chatViewModel.fetchModels(self.ollamaKit)
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

            print("DEBUG: ChatView - Generating with prompt length: \(promptToSend.count)")
            print("DEBUG: ChatView - Prompt preview: \(String(promptToSend.prefix(100)))...")
            
            messageViewModel.generate(ollamaKit, activeChat: activeChat, prompt: promptToSend)
        }
        
        self.prompt = ""
    }
    
    private func regenerateAction() {
        guard let activeChat = chatViewModel.activeChat, !activeChat.model.isEmpty, chatViewModel.isHostReachable else { return }
        
        if messageViewModel.loading == .generate {
            messageViewModel.cancelGeneration()
        } else {
            guard let activeChat = chatViewModel.activeChat else { return }
            
            messageViewModel.regenerate(ollamaKit, activeChat: activeChat)
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
    
    var body: some View {
        VStack {
            HStack(alignment: .top, spacing: 8) {
                // Left column with Easy Note Button and Microphone Button
                VStack(spacing: 8) {
                    // Easy Note Button
                    Button(action: { isEasyNotePresented = true }) {
                        Image(systemName: "note.text.badge.plus")
                            .foregroundStyle(.white)
                            .fontWeight(.bold)
                            .padding(8)
                    }
                    .background(Color.euniPrimary)
                    .buttonStyle(.borderless)
                    .clipShape(.circle)
                    
                    // Microphone Button
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
    }
}

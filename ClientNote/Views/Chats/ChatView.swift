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
    @Environment(\.colorScheme) private var colorScheme
    @Environment(CodeHighlighter.self) private var codeHighlighter

    @AppStorage("experimentalCodeHighlighting") private var experimentalCodeHighlighting = false
    @Default(.fontSize) private var fontSize

    @State private var ollamaKit: OllamaKit
    @State private var prompt: String = ""
    @State private var scrollProxy: ScrollViewProxy? = nil
    @State private var isPreferencesPresented: Bool = false
    @State private var isEasyNotePresented: Bool = false
    @FocusState private var isFocused: Bool

    init() {
        let baseURL = URL(string: Defaults[.defaultHost])!
        self._ollamaKit = State(initialValue: OllamaKit(baseURL: baseURL))
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            VStack {
                List(messageViewModel.messages) { message in
                    let lastMessageId = messageViewModel.messages.last?.id
                    
                    UserMessageView(
                        content: message.displayPrompt,
                        copyAction: self.copyAction
                    )
                    .padding(.top)
                    .padding(.horizontal)
                    .listRowSeparator(.hidden)
                    
                    AssistantMessageView(
                        content: message.response ?? messageViewModel.tempResponse,
                        isGenerating: messageViewModel.loading == .generate,
                        isLastMessage: lastMessageId == message.id,
                        copyAction: self.copyAction,
                        regenerateAction: self.regenerateAction
                    )
                    .id(message)
                    .padding(.top)
                    .padding(.horizontal)
                    .listRowSeparator(.hidden)
                    .if(lastMessageId == message.id) { view in
                        view.padding(.bottom)
                    }
                }
                
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
                .padding(.top, 8)
                .padding(.bottom, 12)
                .padding(.horizontal)
                .visible(if: chatViewModel.activeChat.isNotNil, removeCompletely: true)
            }
            .onAppear {
                self.scrollProxy = proxy
            }
            .onChange(of: chatViewModel.activeChat?.id, initial: true) {
                self.onActiveChatChanged()
            }
            .onChange(of: messageViewModel.tempResponse) {
                if let proxy = scrollProxy {
                    scrollToBottom(proxy: proxy)
                }
            }
            .onChange(of: colorScheme, initial: true) {
                codeHighlighter.colorScheme = colorScheme
            }
            .onChange(of: fontSize, initial: true) {
                codeHighlighter.fontSize = fontSize
            }
            .onChange(of: experimentalCodeHighlighting) {
                codeHighlighter.enabled = experimentalCodeHighlighting
            }
        }
        .navigationTitle(chatViewModel.activeChat?.name ?? "ClientNote")
        .navigationSubtitle(chatViewModel.activeChat?.model ?? "")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Show Preferences", systemImage: "sidebar.trailing") {
                    isPreferencesPresented.toggle()
                }
            }
        }
        .inspector(isPresented: $isPreferencesPresented) {
            ChatPreferencesView(ollamaKit: $ollamaKit)
                .inspectorColumnWidth(min: 320, ideal: 320)
        }
        .sheet(isPresented: $isEasyNotePresented) {
            NavigationView {
                EasyNoteSheet(prompt: $prompt, generateAction: generateAction)
            }
        }
    }
    
    private func onActiveChatChanged() {
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

        if let activeChat = chatViewModel.activeChat, let host = activeChat.host, let baseURL = URL(string: host) {
            self.ollamaKit = OllamaKit(baseURL: baseURL)
            self.chatViewModel.fetchModels(self.ollamaKit)
        }
    }
    
    private func copyAction(_ content: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
    }
    
    private func generateAction() {
        guard let activeChat = chatViewModel.activeChat, !activeChat.model.isEmpty, chatViewModel.isHostReachable else { return }

        if messageViewModel.loading == .generate {
            messageViewModel.cancelGeneration()
        } else {
            let prompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !prompt.isEmpty else {
                self.prompt = ""
                return
            }

            guard let activeChat = chatViewModel.activeChat else { return }
            
            // Create a message with the display prompt (without PIRP instructions)
            let displayPrompt = prompt.components(separatedBy: "\n\nFor your reference, here is how to structure PIRP Clinical Note Language.")[0]
            messageViewModel.generate(ollamaKit, activeChat: activeChat, prompt: displayPrompt)
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
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard messageViewModel.messages.count > 0 else { return }
        guard let lastMessage = messageViewModel.messages.last else { return }
        
        DispatchQueue.main.async {
            proxy.scrollTo(lastMessage, anchor: .bottom)
        }
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
                            .foregroundStyle(.foreground)
                            .fontWeight(.bold)
                            .padding(8)
                    }
                    .background(.background)
                    .buttonStyle(.borderless)
                    .clipShape(.circle)
                    .colorInvert()
                    
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
                            .foregroundStyle(.foreground)
                            .fontWeight(.bold)
                            .padding(8)
                    }
                    .background(.background)
                    .buttonStyle(.borderless)
                    .clipShape(.circle)
                    .colorInvert()
                }
                
                // Chat Field
                TextEditor(text: $prompt)
                    .font(.system(size: fontSize))
                    .frame(height: max(40, textHeight))
                    .scrollContentBackground(.hidden)
                    .background(Color(.textBackgroundColor))
                    .cornerRadius(8)
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
                        .foregroundStyle(.foreground)
                        .fontWeight(.bold)
                        .padding(8)
                }
                .background(.background)
                .buttonStyle(.borderless)
                .clipShape(.circle)
                .colorInvert()
                .disabled(prompt.isEmpty && messageViewModel.loading != .generate)
            }
            .padding(8)
            .background(Color(.textBackgroundColor))
            .clipShape(Capsule())
            
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

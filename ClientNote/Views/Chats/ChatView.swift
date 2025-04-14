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
                        content: message.prompt,
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
            
            messageViewModel.generate(ollamaKit, activeChat: activeChat, prompt: prompt)
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
    
    var body: some View {
        VStack {
            HStack {
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
                
                // Chat Field
                TextField("Write your message here", text: $prompt)
                    .textFieldStyle(.roundedBorder)
                    .focused($isFocused)
                    .font(Font.system(size: fontSize))
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
    }
}

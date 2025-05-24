//
//  AppView.swift
//  ClientNote
//
//  Created by Kevin Keller on 04/13/25.
//

import SwiftUI
import SwiftData
import Defaults

struct AppView: View {
    @Environment(ChatViewModel.self) private var chatViewModel
    
    var body: some View {
        Group {
            if chatViewModel.isDPKNYMode {
                // DPKNY mode: Simple full-screen chat without sidebar
                ChatView()
                    .background(Color.euniBackground)
            } else {
                // Normal mode: Split view with sidebar
                NavigationSplitView {
                    SidebarView()
                        .navigationSplitViewColumnWidth(min: 256, ideal: 256)
                } detail: {
                    ChatView()
                }
                .background(Color.euniBackground)
            }
        }
    }
}

#Preview("App View") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Chat.self, Message.self, configurations: config)
    
    let chatViewModel = ChatViewModel(modelContext: container.mainContext)
    let messageViewModel = MessageViewModel(modelContext: container.mainContext, chatViewModel: chatViewModel)
    chatViewModel.setMessageViewModel(messageViewModel)
    let codeHighlighter = CodeHighlighter(colorScheme: .light, fontSize: 13, enabled: false)
    
    return AppView()
        .environment(chatViewModel)
        .environment(messageViewModel)
        .environment(codeHighlighter)
        .modelContainer(container)
}

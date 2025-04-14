//
//  AppView.swift
//  Ollamac
//
//  Created by Kevin Hermawan on 03/11/23.
//

import SwiftUI
import SwiftData

struct AppView: View {
    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 256, ideal: 256)
        } detail: {
            ChatView()
        }
    }
}

#Preview("App View") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Chat.self, Message.self, configurations: config)
    
    let chatViewModel = ChatViewModel(modelContext: container.mainContext)
    let messageViewModel = MessageViewModel(modelContext: container.mainContext)
    let codeHighlighter = CodeHighlighter(colorScheme: .light, fontSize: 13, enabled: false)
    
    return AppView()
        .environment(chatViewModel)
        .environment(messageViewModel)
        .environment(codeHighlighter)
        .modelContainer(container)
}

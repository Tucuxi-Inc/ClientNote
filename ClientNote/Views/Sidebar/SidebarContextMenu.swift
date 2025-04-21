import SwiftUI

struct SidebarContextMenu: View {
    private let chatViewModel: ChatViewModel
    
    init(chatViewModel: ChatViewModel) {
        self.chatViewModel = chatViewModel
    }
    
    var body: some View {
        @Bindable var chatViewModelBindable = chatViewModel
        
        Button("Rename") {
            chatViewModelBindable.isRenameChatPresented = true
        }
        .disabled(chatViewModel.selectedChats.count > 1)
        .foregroundColor(Color.euniPrimary)
        
        Button("Delete") {
            chatViewModelBindable.isDeleteConfirmationPresented = true
        }
        .keyboardShortcut(.delete, modifiers: [.shift, .command])
        .foregroundColor(Color.euniError)
    }
}

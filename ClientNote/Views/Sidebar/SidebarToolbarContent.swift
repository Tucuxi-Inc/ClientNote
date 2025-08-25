import SwiftUI

struct SidebarToolbarContent: ToolbarContent {
    @Environment(ChatViewModel.self) private var chatViewModel
    
    private func getActivityTypeFromTask(_ task: String) -> ActivityType {
        switch task {
        case "Create a Client Session Note":
            return .sessionNote
        case "Create a Treatment Plan":
            return .treatmentPlan
        case "Brainstorm":
            return .brainstorm
        case "Record Therapy Session":
            return .recordSession
        default:
            return .sessionNote
        }
    }
    
    var body: some ToolbarContent {
        ToolbarItemGroup {
            Spacer()
            
            Button(action: {
                chatViewModel.createNewActivity()
            }) {
                Label("New Activity", systemImage: "square.and.pencil")
                    .foregroundColor(Color.euniPrimary)
            }
            .keyboardShortcut("n")
            .customTooltip("Create new activity", delay: 0.3)
        }
    }
}

import Defaults
import SwiftUI
import ViewCondition

struct SidebarView: View {
    @Environment(ChatViewModel.self) private var chatViewModel
    @Environment(MessageViewModel.self) private var messageViewModel
    
    var body: some View {
        @Bindable var chatViewModelBindable = chatViewModel
        
        VStack(spacing: 0) {
            // Activity Type Label
            Text("Activity Type")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(Color.euniText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 4)
            
            // Activity type segmented control
            Picker("", selection: $chatViewModelBindable.selectedActivityType) {
                ForEach(ActivityType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            .background(Color.euniFieldBackground.opacity(0.5))
            
            Divider()
            
            // Activities list with selection
            List(selection: $chatViewModelBindable.selectedActivityID) {
                ForEach(chatViewModel.filteredActivities) { activity in
                    SidebarListItemView(activity: activity)
                        .tag(activity.id)
                        .listRowBackground(Color.euniFieldBackground.opacity(0.5))
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(Color.euniFieldBackground.opacity(0.5))
            .onChange(of: chatViewModelBindable.selectedActivityID) { _, _ in
                chatViewModel.onActivitySelected()
            }
            .toolbar {
                SidebarToolbarContent()
            }
        }
        .background(Color.euniFieldBackground.opacity(0.5))
    }
}

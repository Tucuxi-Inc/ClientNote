import Defaults
import SwiftUI
import ViewCondition

struct SidebarView: View {
    @Environment(ChatViewModel.self) private var chatViewModel
    @Environment(MessageViewModel.self) private var messageViewModel
    
    @State private var selectedActivitiesToDelete = Set<UUID>()
    @State private var showDeleteConfirmation = false
    @State private var isSelectionMode = false
    
    var body: some View {
        @Bindable var chatViewModelBindable = chatViewModel
        
        VStack(spacing: 0) {
            // Activity Type Label and Controls
            HStack {
                Text("Activity Type")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(Color.euniText)
                
                Spacer()
                
                // Toggle selection mode button
                Button(action: {
                    isSelectionMode.toggle()
                    if !isSelectionMode {
                        selectedActivitiesToDelete.removeAll()
                    }
                }) {
                    Text(isSelectionMode ? "Done" : "Select")
                }
                .buttonStyle(.borderless)
            }
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
            
            // Activities list
            List {
                ForEach(chatViewModel.filteredActivities) { activity in
                    HStack {
                        if isSelectionMode {
                            Toggle(isOn: Binding(
                                get: { selectedActivitiesToDelete.contains(activity.id) },
                                set: { isSelected in
                                    if isSelected {
                                        selectedActivitiesToDelete.insert(activity.id)
                                    } else {
                                        selectedActivitiesToDelete.remove(activity.id)
                                    }
                                }
                            )) {
                                EmptyView()
                            }
                            .toggleStyle(.checkbox)
                        }
                        
                        SidebarListItemView(activity: activity)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if isSelectionMode {
                                    if selectedActivitiesToDelete.contains(activity.id) {
                                        selectedActivitiesToDelete.remove(activity.id)
                                    } else {
                                        selectedActivitiesToDelete.insert(activity.id)
                                    }
                                } else {
                                    chatViewModel.selectedActivityID = activity.id
                                    chatViewModel.onActivitySelected()
                                }
                            }
                    }
                    .listRowBackground(Color.euniFieldBackground.opacity(0.5))
                    .contextMenu {
                        Button(role: .destructive) {
                            selectedActivitiesToDelete = [activity.id]
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(Color.euniFieldBackground.opacity(0.5))
            
            // Delete button for selected items
            if isSelectionMode && !selectedActivitiesToDelete.isEmpty {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete Selected", systemImage: "trash")
                        .foregroundColor(.red)
                }
                .padding()
            }
        }
        .alert("Delete Activities", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                selectedActivitiesToDelete.removeAll()
            }
            Button("Delete", role: .destructive) {
                deleteSelectedActivities()
            }
        } message: {
            Text("Are you sure you want to delete \(selectedActivitiesToDelete.count) selected \(selectedActivitiesToDelete.count == 1 ? "activity" : "activities")? This cannot be undone.")
        }
    }
    
    private func deleteSelectedActivities() {
        guard let clientIndex = chatViewModel.clients.firstIndex(where: { $0.id == chatViewModel.selectedClientID }) else { return }
        
        // Store the IDs to delete
        let idsToDelete = selectedActivitiesToDelete
        
        // Clear selection state first
        selectedActivitiesToDelete.removeAll()
        isSelectionMode = false
        
        // Reset selected activity if it was deleted
        if let selectedID = chatViewModel.selectedActivityID,
           idsToDelete.contains(selectedID) {
            // Find the next available activity
            let remainingActivities = chatViewModel.filteredActivities.filter { !idsToDelete.contains($0.id) }
            chatViewModel.selectedActivityID = remainingActivities.first?.id
        }
        
        // Remove the activities from the client
        chatViewModel.clients[clientIndex].activities.removeAll { activity in
            idsToDelete.contains(activity.id)
        }
        
        // Save the updated client data
        chatViewModel.saveClient(chatViewModel.clients[clientIndex])
        
        // Trigger activity selection update if needed
        if chatViewModel.selectedActivityID != nil {
            chatViewModel.onActivitySelected()
        }
    }
}

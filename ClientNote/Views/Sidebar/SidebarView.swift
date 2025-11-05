import Defaults
import SwiftUI
import ViewCondition

struct SidebarView: View {
    @Environment(ChatViewModel.self) private var chatViewModel
    @Environment(MessageViewModel.self) private var messageViewModel
    
    @State private var selectedActivitiesToDelete = Set<UUID>()
    @State private var showDeleteConfirmation = false
    @State private var isSelectionMode = false
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    /// Filtered activities based on search text
    private var searchFilteredActivities: [ClientActivity] {
        if searchText.isEmpty {
            return chatViewModel.filteredActivities
        }
        return chatViewModel.filteredActivities.filter { activity in
            activity.title.localizedCaseInsensitiveContains(searchText) ||
            activity.content.localizedCaseInsensitiveContains(searchText)
        }
    }

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

            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search activities...", text: $searchText)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, .spacingM)
            .padding(.vertical, .spacingS)
            .background(Color.euniFieldBackground)
            .cornerRadius(.cornerRadiusS)
            .padding(.horizontal, .spacingL)
            .padding(.vertical, .spacingS)
            .onKeyPress(.init("k"), modifiers: .command) { _ in
                isSearchFocused = true
                return .handled
            }

            Divider()
            
            // Activities list
            List {
                if searchFilteredActivities.isEmpty {
                    // Empty state when no activities match search
                    VStack(spacing: .spacingM) {
                        Image(systemName: searchText.isEmpty ? "doc.text" : "magnifyingglass")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text(searchText.isEmpty ? "No activities yet" : "No matching activities")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.spacingXXL)
                }

                ForEach(searchFilteredActivities) { activity in
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

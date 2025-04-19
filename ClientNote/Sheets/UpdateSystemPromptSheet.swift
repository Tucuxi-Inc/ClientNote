import Defaults
import SwiftUI

struct UpdateSystemPromptSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    @Default(.fontSize) private var fontSize

    @State private var prompt: String
    
    private let action: (_ prompt: String) -> Void
    
    init(prompt: String, action: @escaping (_ prompt: String) -> Void) {
        self.prompt = prompt
        self.action = action
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                TextEditor(text: $prompt)
                    .textEditorStyle(.plain)
                    .scrollIndicators(.never)
                    .font(Font.system(size: fontSize))
                    .foregroundColor(Color.euniText)
                    .background(Color.euniFieldBackground)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 10)
            .frame(minWidth: 512, minHeight: 256)
            .navigationTitle("Update System Prompt")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel, action: { dismiss() })
                        .foregroundColor(Color.euniSecondary)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        action(prompt)
                        dismiss()
                    }
                    .foregroundColor(Color.euniPrimary)
                }
            }
        }
        .background(Color.euniBackground)
    }
}

import Defaults
import SwiftUI
import ViewCondition

struct UserMessageView: View {
    @Default(.fontSize) private var fontSize

    private let windowWidth = NSApplication.shared.windows.first?.frame.width ?? 0
    private let content: String
    private let copyAction: (_ content: String) -> Void
    
    init(content: String, copyAction: @escaping (_ content: String) -> Void) {
        self.content = content
        self.copyAction = copyAction
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("You")
                .font(Font.system(size: fontSize).weight(.semibold))
                .foregroundStyle(Color.euniSecondary)
            
            Text(content)
                .font(.system(size: fontSize))
                .foregroundColor(Color.euniText)
                .textSelection(.enabled)
            
            HStack(spacing: 16) {
                MessageButton("Copy", systemImage: "doc.on.doc", action: { copyAction(content) })
            }
        }
        .padding(12)
        .background(Color.euniFieldBackground)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.euniBorder, lineWidth: 1)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

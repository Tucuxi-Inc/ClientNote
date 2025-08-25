import SwiftUI

struct Box<Content: View>: View {
    private let content: () -> Content
    private let action: (() -> Void)?
    
    init(action: (() -> Void)? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.content = content
        self.action = action
    }
    
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                content()
            }
            .frame(maxWidth: .infinity)
            .padding(8)
        }
        .interactiveCard(action: action)
    }
}

import SwiftUI

struct InteractiveCard<Content: View>: View {
    let content: Content
    let action: (() -> Void)?
    @State private var isHovered = false
    @State private var isPressed = false
    
    init(action: (() -> Void)? = nil, @ViewBuilder content: () -> Content) {
        self.action = action
        self.content = content()
    }
    
    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .shadow(
                        color: .black.opacity(isHovered ? 0.15 : 0.08),
                        radius: isHovered ? 8 : 4,
                        x: 0,
                        y: isHovered ? 4 : 2
                    )
            )
            .scaleEffect(isPressed ? 0.98 : (isHovered ? 1.02 : 1.0))
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .animation(.easeOut(duration: 0.1), value: isPressed)
            .onHover { hovering in
                isHovered = hovering
            }
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = false
                    }
                    action?()
                }
            }
    }
}

extension View {
    func interactiveCard(action: (() -> Void)? = nil) -> some View {
        InteractiveCard(action: action) {
            self
        }
    }
}
import SwiftUI

public struct AccessControlView<Content: View>: View {
    let content: Content
    
    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    public var body: some View {
        // In free version, always allow access
        content
    }
}

struct AccessControlView_Previews: PreviewProvider {
    static var previews: some View {
        AccessControlView {
            Text("Content that requires purchase")
        }
    }
} 
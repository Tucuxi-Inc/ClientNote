import SwiftUI

struct MessageButton: View {
    private let title: String
    private let systemImage: String
    private let action: () -> Void
    
    init(_ title: String, systemImage: String, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundColor(Color.euniSecondary)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .tint(Color.euniPrimary)
    }
}

import SwiftUI

public struct CircleButton: View {
    private let systemImage: String
    private let action: () -> Void
    
    public init(systemImage: String, action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .foregroundColor(Color.euniText)
                .fontWeight(.bold)
                .padding(8)
        }
        .background(Color.euniFieldBackground)
        .buttonStyle(.borderless)
        .clipShape(.circle)
        .overlay(
            Circle()
                .stroke(Color.euniBorder, lineWidth: 1)
        )
    }
}

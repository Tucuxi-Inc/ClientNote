import SwiftUI

struct SectionFooter: View {
    private let text: String
    
    init(_ text: String) {
        self.text = text
    }
    
    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundColor(Color.euniSecondary)
    }
}

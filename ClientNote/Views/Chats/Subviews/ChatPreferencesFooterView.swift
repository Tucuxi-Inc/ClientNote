import SwiftUI

struct ChatPreferencesFooterView: View {
    private let text: String
    
    init(_ text: String) {
        self.text = text
    }
    
    var body: some View {
        VStack {
            Text(text)
                .multilineTextAlignment(.leading)
                .foregroundColor(Color.euniSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

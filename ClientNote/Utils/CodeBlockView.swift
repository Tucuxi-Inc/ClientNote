import MarkdownUI
import SwiftUI

struct CodeBlockView: View {
    @Environment(CodeHighlighter.self) private var codeHighlighter

    let configuration: CodeBlockConfiguration
    @State private var isCopied = false
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(configuration.language?.capitalized ?? "")
                    .foregroundColor(Color.euniText)
                
                Spacer()
                
                Button(action: copyCodeAction) {
                    Text(isCopied ? "Copied!" : "Copy Code")
                        .foregroundColor(Color.euniText)
                        .frame(width: 80)
                        .padding(4)
                }
                .buttonStyle(.plain)
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.euniBorder, lineWidth: 1)
                )
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.euniFieldBackground)

            configuration.label
                .padding(.top, 8)
                .padding(.bottom)
                .padding(.horizontal)
                .monospaced()
        }
        .background(Color.euniFieldBackground)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.euniBorder, lineWidth: 0.2)
        )
    }

    var headerBackground: some View {
        Color.euniFieldBackground
    }

    var borderColor: Color {
        Color.euniBorder
    }

    var codeBackground: some View {
        Color.euniFieldBackground
    }
    
    private func copyCodeAction() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(configuration.content, forType: .string)
        
        withAnimation {
            isCopied = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                isCopied = false
            }
        }
    }
}

extension CodeBlockConfiguration: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(language)
        hasher.combine(content)
    }
    
    public static func == (lhs: CodeBlockConfiguration, rhs: CodeBlockConfiguration) -> Bool {
        return lhs.language == rhs.language && lhs.content == rhs.content
    }
}

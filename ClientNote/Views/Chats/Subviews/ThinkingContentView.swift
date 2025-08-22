//
//  ThinkingContentView.swift
//  ClientNote
//
//  Collapsible thinking content for AI responses
//

import SwiftUI
import MarkdownUI
import Defaults

struct ThinkingContentView: View {
    @Default(.fontSize) private var fontSize
    
    let content: String
    let isStreaming: Bool
    @State private var isExpanded: Bool = false
    
    private var parsedContent: (thinking: String, regular: String) {
        parseThinkingContent(content)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Show regular content first
            if !parsedContent.regular.isEmpty {
                Markdown(parsedContent.regular)
                    .textSelection(.enabled)
                    .markdownTextStyle(\.text) {
                        FontSize(CGFloat(fontSize))
                        ForegroundColor(Color.euniText)
                    }
                    .markdownTextStyle(\.code) {
                        FontSize(CGFloat(fontSize))
                        FontFamily(.system(.monospaced))
                    }
                    .markdownTheme(Theme.clientNote)
            }
            
            // Show thinking section if present
            if !parsedContent.thinking.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    // Clickable thinking header
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                .font(.system(size: fontSize - 2, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            Text(isStreaming ? "<thinking...>" : "<thinking>")
                                .font(.system(size: fontSize, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .contentShape(Rectangle())
                    
                    // Expandable thinking content
                    if isExpanded {
                        VStack(alignment: .leading, spacing: 4) {
                            Markdown(parsedContent.thinking)
                                .textSelection(.enabled)
                                .markdownTextStyle(\.text) {
                                    FontSize(CGFloat(fontSize - 1))
                                    ForegroundColor(Color.secondary)
                                }
                                .markdownTextStyle(\.code) {
                                    FontSize(CGFloat(fontSize - 1))
                                    FontFamily(.system(.monospaced))
                                }
                                .markdownTheme(Theme.clientNote)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.secondary.opacity(0.05))
                        .cornerRadius(6)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .top)),
                            removal: .opacity
                        ))
                    }
                }
            }
        }
    }
    
    private func parseThinkingContent(_ text: String) -> (thinking: String, regular: String) {
        let openingTag = "<think>"
        let closingTag = "</think>"
        
        var thinkingContent = ""
        var regularContent = ""
        var insideThinkBlock = false
        var currentThinkingBlock = ""
        
        text.enumerateLines { line, stop in
            switch true {
            case line.contains(openingTag):
                insideThinkBlock = true
                let cleanedLine = line.replacingOccurrences(of: openingTag, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleanedLine.isEmpty {
                    currentThinkingBlock += cleanedLine + "\n"
                }
            case line.contains(closingTag):
                insideThinkBlock = false
                let cleanedLine = line.replacingOccurrences(of: closingTag, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleanedLine.isEmpty {
                    currentThinkingBlock += cleanedLine + "\n"
                }
                thinkingContent += currentThinkingBlock
                currentThinkingBlock = ""
            case insideThinkBlock:
                currentThinkingBlock += line + "\n"
            default:
                regularContent += line + "\n"
            }
        }
        
        // Handle case where thinking block is not closed (streaming)
        if insideThinkBlock && !currentThinkingBlock.isEmpty {
            thinkingContent += currentThinkingBlock
        }
        
        return (
            thinking: thinkingContent.trimmingCharacters(in: .whitespacesAndNewlines),
            regular: regularContent.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}


#Preview {
    ThinkingContentView(
        content: """
        <think>
        The user is asking about anxiety management. I should provide a structured response that includes:
        1. Validation of their experience
        2. Evidence-based techniques
        3. Specific actionable steps
        </think>
        
        I understand you're dealing with anxiety about work interactions. Here are some effective strategies:
        
        **Cognitive Techniques:**
        - Challenge negative assumptions
        - Practice grounding exercises
        
        **Behavioral Approaches:**
        - Start with low-stakes interactions
        - Use breathing techniques before meetings
        """,
        isStreaming: false
    )
    .padding()
}
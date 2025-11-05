//
//  AssistantMessageView.swift
//  ClientNote
//
//  Created by Kevin Hermawan on 8/2/24.
//

import Defaults
import MarkdownUI
import SwiftUI
import ViewCondition
import RegexBuilder

struct AssistantMessageView: View {
    @Default(.fontSize) private var fontSize

    private let content: String
    private let isGenerating: Bool
    private let isLastMessage: Bool
    private let copyAction: (_ content: String) -> Void
    private let regenerateAction: () -> Void

    @Environment(CodeHighlighter.self) private var codeHighlighter
    @AppStorage("experimentalCodeHighlighting") private var experimentalCodeHighlighting = false

    init(content: String, isGenerating: Bool, isLastMessage: Bool, copyAction: @escaping (_ content: String) -> Void, regenerateAction: @escaping () -> Void) {
        self.content = content
        self.isGenerating = isGenerating
        self.isLastMessage = isLastMessage
        self.copyAction = copyAction
        self.regenerateAction = regenerateAction
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: .spacingS) {
            Text("Assistant")
                .font(Font.system(size: fontSize).weight(.semibold))
                .foregroundStyle(Color.euniSecondary)

            if isGenerating && content.isEmpty {
                // Enhanced thinking indicator with animation and descriptive text
                HStack(spacing: .spacingM) {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(1.2)

                    Text("Analyzing your request...")
                        .font(.system(size: fontSize))
                        .foregroundStyle(Color.euniSecondary)
                        .opacity(0.8)
                }
                .padding(.vertical, .spacingS)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
				Markdown(convertThinkTagsToMarkdownQuote(in: content))
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
                    .markdownCodeSyntaxHighlighter(experimentalCodeHighlighting ? codeHighlighter : .plainText)
                    .id(codeHighlighter.stateHashValue)

                HStack(spacing: 16) {
                    MessageButton("Copy", systemImage: "doc.on.doc", action: { copyAction(content) })
                    
                    MessageButton("Regenerate", systemImage: "arrow.triangle.2.circlepath", action: regenerateAction)
                        .keyboardShortcut("r", modifiers: [.command])
                        .visible(if: isLastMessage, removeCompletely: true)
                }
                .hide(if: isLastMessage && isGenerating)
            }
        }
        .padding(.spacingM)
        .background(Color.euniFieldBackground)
        .cornerRadius(.cornerRadiusM)
        .overlay(
            RoundedRectangle(cornerRadius: .cornerRadiusM)
                .stroke(Color.euniBorder, lineWidth: .borderStandard)
        )
        .overlay(alignment: .leading) {
            // Left accent border for visual distinction
            RoundedRectangle(cornerRadius: .cornerRadiusM)
                .fill(Color.euniPrimary)
                .frame(width: 3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
	
	func convertThinkTagsToMarkdownQuote(in text: String) -> String  {
		let openingTag = "<think>"
		let closingTag = "</think>"
		
		// Disregard any markup if this does not start with with the appropriate tag
		guard text.starts(with: openingTag) else { return text }
		
		// Check if a think tag is present, but empty and remove it from the contents if appropriate
		let emptyThinkBlockRegex = Regex {
			openingTag
			Capture {
				OneOrMore(.anyNonNewline.inverted)
			}
			closingTag
		}
		
		if let tagRange = text.firstRange(of: emptyThinkBlockRegex) {
			var newText = text
			newText.removeSubrange(tagRange)
			return newText
		}
		
		var result = ""
		var insideThinkBlock = false

		text.enumerateLines { line, stop in
			switch true {
			case line.contains(openingTag):
				insideThinkBlock = true
				result.append("> \(line.replaceAndTrim(string: openingTag))\n")
			case line.contains(closingTag):
				insideThinkBlock = false
				result.append("> \(line.replaceAndTrim(string: closingTag))\n")
			case insideThinkBlock:
				result.append("> \(line)\n")
			default:
				result.append("\(line)\n")
			}
		}
		
		return result
	}
}



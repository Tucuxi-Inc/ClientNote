import Defaults
import Highlightr
import MarkdownUI
import SwiftUI

@Observable
class CodeHighlighter: CodeSyntaxHighlighter {
    private let highlightr: Highlightr
    var fontSize: Double {
        didSet {
            recalcState()
        }
    }
    var enabled: Bool {
        didSet {
            recalcState()
        }
    }
    var colorScheme: ColorScheme = .light {
        didSet {
            recalcState()
        }
    }
    private(set) var stateHashValue: Int = 0

    init(colorScheme: ColorScheme, fontSize: Double, enabled: Bool) {
        guard let highlightrInstance = Highlightr() else {
            fatalError("Failed to initialize Highlightr")
        }
        self.highlightr = highlightrInstance
        self.highlightr.setTheme(to: "atom-one-light")
        self.fontSize = fontSize
        self.colorScheme = .light
        self.enabled = enabled

        recalcState()
    }

    func highlightCode(_ code: String, language: String?) -> Text {
        guard enabled else {
            return Text(code)
        }

        let highlightedCode: NSAttributedString?

        if let language, !language.isEmpty {
            highlightedCode = highlightr.highlight(code, as: language)
        } else {
            highlightedCode = highlightr.highlight(code)
        }

        guard let highlightedCode else { return Text(code) }

        var attributedCode = AttributedString(highlightedCode)
        attributedCode.font = .system(size: fontSize, design: .monospaced)

        return Text(attributedCode)
    }

    func set(colorScheme: ColorScheme, fontSize: Double, enabled: Bool) {
        self.highlightr.setTheme(to: "atom-one-light")
        self.colorScheme = .light
        self.fontSize = fontSize
        self.enabled = enabled
        recalcState()
    }

    private func recalcState() {
        var hasher = Hasher()
        hasher.combine(fontSize)
        hasher.combine(colorScheme)
        hasher.combine(enabled)
        stateHashValue = hasher.finalize()
    }
}

//
//  Theme+ClientNote.swift
//  ClientNote
//
//  Created by Kevin Hermawan on 8/10/24.
//

import Foundation
import MarkdownUI
import SwiftUI

class ThemeCache {
    static let shared = ThemeCache()
    private var cachedTheme: Theme?
    private var cachedCodeBlocks: [CodeBlockConfiguration: CodeBlockView] = [:]
    
    func getTheme() -> Theme {
        if let existingTheme = cachedTheme {
            return existingTheme
        } else {
            let newTheme = Theme()
                .text {
                    ForegroundColor(.primary)
                    BackgroundColor(.clear)
                }
                .code {
                    FontFamilyVariant(.monospaced)
                    FontSize(.em(0.85))
                    BackgroundColor(.secondary.opacity(0.1))
                }
                .strong {
                    FontWeight(.semibold)
                }
                .link {
                    ForegroundColor(.accent)
                }
                .heading1 { configuration in
                    VStack(alignment: .leading, spacing: 8) {
                        configuration.label
                            .font(.title)
                            .fontWeight(.bold)
                    }
                }
                .heading2 { configuration in
                    VStack(alignment: .leading, spacing: 8) {
                        configuration.label
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                }
                .heading3 { configuration in
                    VStack(alignment: .leading, spacing: 8) {
                        configuration.label
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                }
                .heading4 { configuration in
                    VStack(alignment: .leading, spacing: 8) {
                        configuration.label
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                }
                .heading5 { configuration in
                    VStack(alignment: .leading, spacing: 8) {
                        configuration.label
                            .font(.subheadline)
                            .fontWeight(.bold)
                    }
                }
                .heading6 { configuration in
                    VStack(alignment: .leading, spacing: 8) {
                        configuration.label
                            .font(.subheadline)
                            .fontWeight(.bold)
                    }
                }
                .paragraph { configuration in
                    configuration.label
                        .fixedSize(horizontal: false, vertical: true)
                }
                .blockquote { configuration in
                    HStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.secondary.opacity(0.2))
                            .frame(width: 4)
                        
                        configuration.label
                            .padding(.leading, 8)
                    }
                }
                .codeBlock { configuration in
                    CodeBlockView(configuration: configuration)
                }
            
            cachedTheme = newTheme
            
            return newTheme
        }
    }
    
//    private func getCodeBlockView(for configuration: CodeBlockConfiguration) -> CodeBlockView {
//        if let cachedView = cachedCodeBlocks[configuration] {
//            return cachedView
//        } else {
//            let newView = CodeBlockView(configuration: configuration)
//            cachedCodeBlocks[configuration] = newView
//            
//            return newView
//        }
//    }
}

extension Theme {
    static var clientNote: Theme {
        ThemeCache.shared.getTheme()
    }
}

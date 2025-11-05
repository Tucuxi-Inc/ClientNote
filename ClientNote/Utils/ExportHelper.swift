//
//  ExportHelper.swift
//  ClientNote
//
//  Created by AI Assistant
//  Helper functions for exporting notes and data
//

import SwiftUI
import AppKit

// MARK: - Export Format

enum ExportFormat: String, CaseIterable {
    case txt = "Plain Text"
    case rtf = "Rich Text"
    case pdf = "PDF Document"
    case markdown = "Markdown"

    var fileExtension: String {
        switch self {
        case .txt: return "txt"
        case .rtf: return "rtf"
        case .pdf: return "pdf"
        case .markdown: return "md"
        }
    }

    var utType: String {
        switch self {
        case .txt: return "public.plain-text"
        case .rtf: return "public.rtf"
        case .pdf: return "com.adobe.pdf"
        case .markdown: return "net.daringfireball.markdown"
        }
    }
}

// MARK: - Export Helper

class ExportHelper {
    static let shared = ExportHelper()

    private init() {}

    // MARK: - Export Note

    /// Export a note to a file
    /// - Parameters:
    ///   - content: The note content to export
    ///   - format: The export format
    ///   - fileName: The desired file name (without extension)
    /// - Returns: Success or failure
    func exportNote(
        content: String,
        format: ExportFormat,
        fileName: String
    ) async throws -> URL {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName)
            .appendingPathExtension(format.fileExtension)

        switch format {
        case .txt, .markdown:
            try content.write(to: fileURL, atomically: true, encoding: .utf8)

        case .rtf:
            let attributedString = NSAttributedString(string: content)
            let rtfData = try attributedString.data(
                from: NSRange(location: 0, length: attributedString.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            )
            try rtfData.write(to: fileURL)

        case .pdf:
            try await exportToPDF(content: content, fileURL: fileURL)
        }

        return fileURL
    }

    // MARK: - Export to PDF

    private func exportToPDF(content: String, fileURL: URL) async throws {
        await MainActor.run {
            let pdfData = NSMutableData()
            let printInfo = NSPrintInfo()
            printInfo.paperSize = NSSize(width: 612, height: 792) // US Letter
            printInfo.topMargin = 72
            printInfo.bottomMargin = 72
            printInfo.leftMargin = 72
            printInfo.rightMargin = 72

            // Create attributed string with formatting
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.textColor
            ]
            let attributedString = NSAttributedString(string: content, attributes: attributes)

            // Create text view for rendering
            let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 468, height: 648))
            textView.textStorage?.setAttributedString(attributedString)

            // Create PDF
            guard let pdfRepresentation = textView.dataWithPDF(inside: textView.bounds) else {
                return
            }

            pdfData.append(pdfRepresentation)
            try? pdfData.write(to: fileURL)
        }
    }

    // MARK: - Show Save Panel

    /// Show a save panel to choose export location
    /// - Parameters:
    ///   - fileName: Default file name
    ///   - format: Export format
    /// - Returns: Selected URL or nil if cancelled
    func showSavePanel(
        fileName: String,
        format: ExportFormat
    ) async -> URL? {
        await MainActor.run {
            let savePanel = NSSavePanel()
            savePanel.nameFieldStringValue = "\(fileName).\(format.fileExtension)"
            savePanel.allowedContentTypes = [.init(filenameExtension: format.fileExtension)!]
            savePanel.canCreateDirectories = true
            savePanel.title = "Export Note"
            savePanel.message = "Choose a location to save the exported note"

            let response = savePanel.runModal()
            return response == .OK ? savePanel.url : nil
        }
    }

    // MARK: - Export with Panel

    /// Complete export workflow with save panel
    /// - Parameters:
    ///   - content: Note content to export
    ///   - fileName: Default file name
    ///   - format: Export format
    func exportWithPanel(
        content: String,
        fileName: String,
        format: ExportFormat
    ) async throws {
        // Show save panel
        guard let destinationURL = await showSavePanel(fileName: fileName, format: format) else {
            throw ExportError.cancelled
        }

        // Export to temporary file
        let tempURL = try await exportNote(content: content, format: format, fileName: fileName)

        // Move to destination
        try FileManager.default.moveItem(at: tempURL, to: destinationURL)
    }

    // MARK: - Bulk Export

    /// Export multiple notes to a zip file
    /// - Parameters:
    ///   - notes: Dictionary of file names to content
    ///   - format: Export format
    ///   - archiveName: Name of the zip file
    func bulkExport(
        notes: [String: String],
        format: ExportFormat,
        archiveName: String
    ) async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Export all notes to temp directory
        for (fileName, content) in notes {
            let noteURL = try await exportNote(
                content: content,
                format: format,
                fileName: fileName
            )
            let destURL = tempDir.appendingPathComponent("\(fileName).\(format.fileExtension)")
            try FileManager.default.copyItem(at: noteURL, to: destURL)
        }

        // Create zip file
        let zipURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(archiveName).zip")

        // Note: Zipping requires external library or shell command
        // This is a placeholder for the implementation
        // In production, use a library like ZIPFoundation

        return zipURL
    }
}

// MARK: - Export Error

enum ExportError: LocalizedError {
    case cancelled
    case fileCreationFailed
    case unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Export was cancelled"
        case .fileCreationFailed:
            return "Failed to create export file"
        case .unsupportedFormat:
            return "This export format is not supported"
        }
    }
}

// MARK: - Export Button View

/// A reusable export button with format selection
struct ExportButton: View {
    let content: String
    let fileName: String
    @State private var selectedFormat: ExportFormat = .txt
    @State private var isExporting = false
    @State private var showError: AppError?

    var body: some View {
        Menu {
            ForEach(ExportFormat.allCases, id: \.self) { format in
                Button(format.rawValue) {
                    selectedFormat = format
                    Task {
                        await exportNote()
                    }
                }
            }
        } label: {
            Label("Export", systemImage: "square.and.arrow.up")
        }
        .disabled(isExporting)
        .errorBanner(error: $showError)
    }

    private func exportNote() async {
        isExporting = true
        defer { isExporting = false }

        do {
            try await ExportHelper.shared.exportWithPanel(
                content: content,
                fileName: fileName,
                format: selectedFormat
            )
        } catch ExportError.cancelled {
            // User cancelled, no error needed
        } catch {
            showError = .fileOperationError("Failed to export: \(error.localizedDescription)")
        }
    }
}

// MARK: - Usage Example

/*
 Usage in ChatPreferencesView or similar:

 ExportButton(
     content: chatViewModel.currentActivityContent,
     fileName: "Session Note - \(Date().formatted())"
 )
 */

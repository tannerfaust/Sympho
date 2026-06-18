//
//  DevCaptureExporter.swift
//  Sympho
//

import Foundation
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

enum DevCaptureExportFormat: String {
    case markdown
    case csv

    var fileExtension: String {
        switch self {
        case .markdown: return "md"
        case .csv: return "csv"
        }
    }

    var contentType: UTType {
        switch self {
        case .markdown: return .plainText
        case .csv: return .commaSeparatedText
        }
    }
}

enum DevCaptureExporter {
    static func markdown(for captures: [DevCapture]) -> String {
        guard !captures.isEmpty else {
            return "# Sympho Dev Captures\n\n_No captures yet._\n"
        }

        var lines = ["# Sympho Dev Captures", ""]
        let formatter = ISO8601DateFormatter()

        for capture in captures {
            lines.append("## \(capture.kind.displayName): \(capture.title)")
            lines.append("")
            lines.append("- **Created:** \(formatter.string(from: capture.createdAt))")
            lines.append("- **Assignee:** \(capture.assignee.displayName)")
            lines.append("- **Section:** \(capture.contextSection)")
            if !capture.contextSummary.isEmpty {
                lines.append("- **Context:** \(capture.contextSummary)")
            }
            lines.append("")
            if !capture.bodyText.isEmpty {
                lines.append(capture.bodyText)
                lines.append("")
            }
            lines.append("---")
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    static func csv(for captures: [DevCapture]) -> String {
        let headers = [
            "id", "created_at", "kind", "assignee", "title", "body",
            "section", "context_summary",
            "domain", "track", "module", "node", "project"
        ]
        var lines = [headers.joined(separator: ",")]
        let formatter = ISO8601DateFormatter()

        for capture in captures {
            let row = [
                capture.id.uuidString,
                formatter.string(from: capture.createdAt),
                capture.kind.displayName,
                capture.assignee.displayName,
                capture.title,
                capture.bodyText,
                capture.contextSection,
                capture.contextSummary,
                capture.contextDomainTitle ?? "",
                capture.contextTrackTitle ?? "",
                capture.contextModuleTitle ?? "",
                capture.contextNodeTitle ?? "",
                capture.contextProjectTitle ?? ""
            ]
            lines.append(row.map(csvEscaped).joined(separator: ","))
        }

        return lines.joined(separator: "\n")
    }

    #if os(macOS)
    @discardableResult
    static func export(_ captures: [DevCapture], format: DevCaptureExportFormat) -> Bool {
        let panel = NSSavePanel()
        panel.title = "Export Dev Captures"
        panel.nameFieldStringValue = "sympho-dev-captures.\(format.fileExtension)"
        panel.allowedContentTypes = [format.contentType]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return false }

        let content: String
        switch format {
        case .markdown: content = markdown(for: captures)
        case .csv: content = csv(for: captures)
        }

        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            return true
        } catch {
            print("Could not export dev captures: \(error.localizedDescription)")
            return false
        }
    }
    #endif

    private static func csvEscaped(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}

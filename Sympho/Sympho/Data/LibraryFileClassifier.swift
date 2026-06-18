//
//  LibraryFileClassifier.swift
//  Sympho
//

import Foundation
import UniformTypeIdentifiers

enum LibraryFileClassifier {
    static let importableContentTypes: [UTType] = [
        .data,
        .content,
        .image,
        .pdf,
        .movie,
        .audiovisualContent,
        .text,
        .plainText
    ]

    static func contentType(for url: URL) -> UTType {
        if let values = try? url.resourceValues(forKeys: [.contentTypeKey]),
           let contentType = values.contentType {
            return contentType
        }

        return UTType(filenameExtension: url.pathExtension) ?? .data
    }

    static func resourceType(forFile url: URL) -> ResourceType {
        let type = contentType(for: url)
        let ext = url.pathExtension.lowercased()

        if type.conforms(to: .movie) || type.conforms(to: .audiovisualContent) {
            return .video
        }

        if type.conforms(to: .plainText) || type.conforms(to: .text) || ext == "md" {
            return .note
        }

        if ["html", "htm", "webloc"].contains(ext) {
            return .url
        }

        return .pdf
    }

    static func iconName(forFile url: URL) -> String {
        let type = contentType(for: url)
        let ext = url.pathExtension.lowercased()

        if type.conforms(to: .image) {
            return "photo.fill"
        }

        if type.conforms(to: .movie) || type.conforms(to: .audiovisualContent) {
            return "play.rectangle.fill"
        }

        if type.conforms(to: .pdf) {
            return "doc.richtext.fill"
        }

        if type.conforms(to: .plainText) || type.conforms(to: .text) || ext == "md" {
            return "note.text"
        }

        return "doc.fill"
    }

    static func fileSizeLabel(for url: URL) -> String? {
        guard
            let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
            let size = values.fileSize
        else {
            return url.pathExtension.isEmpty ? nil : url.pathExtension.uppercased()
        }

        return formattedByteSize(Int64(size))
    }

    static func formattedByteSize(_ byteSize: Int64?) -> String? {
        guard let byteSize, byteSize > 0 else { return nil }

        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        return formatter.string(fromByteCount: byteSize)
    }
}

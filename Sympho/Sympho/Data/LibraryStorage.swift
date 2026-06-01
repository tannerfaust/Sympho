//
//  LibraryStorage.swift
//  Sympho
//

import Foundation
import UniformTypeIdentifiers

enum LibraryStorage {
    private static let bookmarkKey = "libraryWorkspaceBookmark"

    static var workspaceURL: URL? {
        #if os(macOS)
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }

        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return nil
        }

        if isStale {
            try? setWorkspace(url)
        }

        return url
        #else
        return nil
        #endif
    }

    static var workspaceName: String? {
        workspaceURL?.lastPathComponent
    }

    static var repositoryInfo: LibraryRepositoryInfo? {
        guard let workspaceURL else { return nil }

        return withWorkspaceAccess {
            let gitFolder = workspaceURL.appendingPathComponent(".git", isDirectory: true)
            let headURL = gitFolder.appendingPathComponent("HEAD")
            guard let head = try? String(contentsOf: headURL, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines) else {
                return nil
            }

            let branchPrefix = "ref: refs/heads/"
            let branch = head.hasPrefix(branchPrefix)
                ? String(head.dropFirst(branchPrefix.count))
                : String(head.prefix(10))

            let configURL = gitFolder.appendingPathComponent("config")
            let config = (try? String(contentsOf: configURL, encoding: .utf8)) ?? ""

            return LibraryRepositoryInfo(
                branch: branch,
                remoteURL: originRemote(in: config)
            )
        }
    }

    static func setWorkspace(_ url: URL) throws {
        #if os(macOS)
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let bookmark = try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.standard.set(bookmark, forKey: bookmarkKey)
        #endif
    }

    static func clearWorkspace() {
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
    }

    static func importFile(from sourceURL: URL, entryID: UUID, entryTitle: String) throws -> ImportedLibraryFile {
        let destinationRoot: URL
        let storageKind: String

        if let workspaceURL {
            destinationRoot = workspaceURL
            storageKind = "workspace"
        } else {
            destinationRoot = try internalLibraryRoot()
            storageKind = "internal"
        }

        let hasRootAccess = destinationRoot.startAccessingSecurityScopedResource()
        defer {
            if hasRootAccess {
                destinationRoot.stopAccessingSecurityScopedResource()
            }
        }

        let entryFolder = destinationRoot
            .appendingPathComponent("Entries", isDirectory: true)
            .appendingPathComponent(entryFolderName(title: entryTitle, id: entryID), isDirectory: true)
        try FileManager.default.createDirectory(at: entryFolder, withIntermediateDirectories: true)

        let destinationURL = uniqueDestination(for: sourceURL.lastPathComponent, in: entryFolder)
        let hasSourceAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if hasSourceAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

        let relativePath = destinationURL.path.replacingOccurrences(
            of: destinationRoot.path + "/",
            with: ""
        )

        return ImportedLibraryFile(
            displayName: sourceURL.lastPathComponent,
            storedPath: relativePath,
            storageKind: storageKind,
            contentType: UTType(filenameExtension: sourceURL.pathExtension)?.identifier ?? UTType.data.identifier
        )
    }

    static func saveMarkdownNote(_ markdown: String, entryID: UUID, entryTitle: String) throws -> ImportedLibraryFile {
        let destinationRoot: URL
        let storageKind: String

        if let workspaceURL {
            destinationRoot = workspaceURL
            storageKind = "workspace"
        } else {
            destinationRoot = try internalLibraryRoot()
            storageKind = "internal"
        }

        let hasRootAccess = destinationRoot.startAccessingSecurityScopedResource()
        defer {
            if hasRootAccess {
                destinationRoot.stopAccessingSecurityScopedResource()
            }
        }

        let entryFolder = destinationRoot
            .appendingPathComponent("Entries", isDirectory: true)
            .appendingPathComponent(entryFolderName(title: entryTitle, id: entryID), isDirectory: true)
        try FileManager.default.createDirectory(at: entryFolder, withIntermediateDirectories: true)

        let filename = "\(sanitizedFilename(entryTitle)).md"
        let destinationURL = uniqueDestination(for: filename, in: entryFolder)
        try markdown.write(to: destinationURL, atomically: true, encoding: .utf8)

        return ImportedLibraryFile(
            displayName: destinationURL.lastPathComponent,
            storedPath: relativePath(for: destinationURL, from: destinationRoot),
            storageKind: storageKind,
            contentType: "net.daringfireball.markdown"
        )
    }

    static func updateMarkdownNote(_ markdown: String, attachment: LibraryAttachment) throws {
        guard let url = resolvedURL(for: attachment) else {
            throw LibraryStorageError.missingFile
        }

        let workspace = attachment.storageKind == "workspace" ? workspaceURL : nil
        let hasAccess = workspace?.startAccessingSecurityScopedResource() == true
        defer {
            if hasAccess {
                workspace?.stopAccessingSecurityScopedResource()
            }
        }

        try markdown.write(to: url, atomically: true, encoding: .utf8)
    }

    static func resolvedURL(for attachment: LibraryAttachment) -> URL? {
        let root = attachment.storageKind == "workspace"
            ? workspaceURL
            : try? internalLibraryRoot()
        return root?.appendingPathComponent(attachment.storedPath)
    }

    static func data(at url: URL) -> Data? {
        withWorkspaceAccess {
            try? Data(contentsOf: url)
        }
    }

    static func withWorkspaceAccess<T>(_ operation: () -> T) -> T {
        let workspace = workspaceURL
        let hasAccess = workspace?.startAccessingSecurityScopedResource() == true
        defer {
            if hasAccess {
                workspace?.stopAccessingSecurityScopedResource()
            }
        }

        return operation()
    }

    static func legacyResolvedURL(for resource: Resource) -> URL? {
        guard let relativePath = resource.fileRelativePath else { return nil }

        if let url = URL(string: resource.urlString), url.isFileURL {
            return url
        }

        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }

        return appSupport.appendingPathComponent(relativePath)
    }

    private static func internalLibraryRoot() throws -> URL {
        let root = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        .appendingPathComponent("SymphoStorage", isDirectory: true)
        .appendingPathComponent("Library", isDirectory: true)

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private static func uniqueDestination(for filename: String, in folder: URL) -> URL {
        let fileManager = FileManager.default
        let original = folder.appendingPathComponent(filename)
        guard fileManager.fileExists(atPath: original.path) else { return original }

        let extensionName = original.pathExtension
        let baseName = original.deletingPathExtension().lastPathComponent

        for index in 2...999 {
            let candidateName = extensionName.isEmpty
                ? "\(baseName) \(index)"
                : "\(baseName) \(index).\(extensionName)"
            let candidate = folder.appendingPathComponent(candidateName)
            if !fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        return folder.appendingPathComponent("\(UUID().uuidString)_\(filename)")
    }

    private static func relativePath(for url: URL, from root: URL) -> String {
        url.path.replacingOccurrences(of: root.path + "/", with: "")
    }

    private static func sanitizedFilename(_ title: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " -_"))
        let cleaned = title.unicodeScalars
            .map { allowed.contains($0) ? Character(String($0)) : "-" }
        let name = String(cleaned).trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Untitled Note" : name
    }

    private static func entryFolderName(title: String, id: UUID) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " -_"))
        let cleaned = title.unicodeScalars
            .map { allowed.contains($0) ? Character(String($0)) : "-" }
        let normalized = String(cleaned)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "  ", with: " ")
        let name = normalized.isEmpty ? "Untitled Entry" : normalized
        return "\(name) -- \(id.uuidString.prefix(8))"
    }

    private static func originRemote(in config: String) -> String? {
        var isOriginSection = false

        for line in config.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("[") {
                isOriginSection = trimmed == "[remote \"origin\"]"
            } else if isOriginSection, trimmed.hasPrefix("url = ") {
                return String(trimmed.dropFirst("url = ".count))
            }
        }

        return nil
    }
}

enum LibraryStorageError: LocalizedError {
    case missingFile

    var errorDescription: String? {
        switch self {
        case .missingFile:
            return "The saved file could not be found. Choose the correct Library folder in Settings and try again."
        }
    }
}

struct ImportedLibraryFile {
    let displayName: String
    let storedPath: String
    let storageKind: String
    let contentType: String
}

struct LibraryRepositoryInfo {
    let branch: String
    let remoteURL: String?
}

//
//  LibraryStorage.swift
//  Sympho
//

import Foundation
import CryptoKit
import UniformTypeIdentifiers

enum LibraryStorage {
    private static let bookmarkKey = "libraryWorkspaceBookmark"
    private static let workspaceStorageKind = "workspace"
    private static let internalStorageKind = "internal"

    // Resolving a security-scoped bookmark touches the filesystem and the sandbox
    // daemon, so it is far too slow to repeat on every access. SwiftUI reads
    // `workspaceURL` from inside list/grid card bodies (via `resolvedURL`), which
    // re-evaluate on render, hover, and scroll — without this cache that storm of
    // synchronous resolutions freezes the UI. The cache is keyed on the exact
    // stored bookmark `Data`, so `setWorkspace`/`clearWorkspace` invalidate it
    // automatically. Guarded by a lock because thumbnail generation reads it off
    // the main thread.
    private static let cacheLock = NSLock()
    private static var cachedWorkspace: (bookmark: Data, url: URL)?

    static var workspaceURL: URL? {
        #if os(macOS)
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else {
            cacheLock.lock()
            cachedWorkspace = nil
            cacheLock.unlock()
            return nil
        }

        cacheLock.lock()
        if let cached = cachedWorkspace, cached.bookmark == data {
            let url = cached.url
            cacheLock.unlock()
            return url
        }
        cacheLock.unlock()

        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            cacheLock.lock()
            cachedWorkspace = nil
            cacheLock.unlock()
            return nil
        }

        if isStale {
            try? setWorkspace(url)
        }

        // Re-read so the cache key matches whatever is now persisted (a stale
        // bookmark was just refreshed by `setWorkspace`).
        let storedBookmark = UserDefaults.standard.data(forKey: bookmarkKey) ?? data
        cacheLock.lock()
        cachedWorkspace = (storedBookmark, url)
        cacheLock.unlock()

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
        guard sourceURL.isFileURL else {
            throw LibraryStorageError.unsupportedURL
        }

        let sourceURL = sourceURL.standardizedFileURL

        let hasSourceAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if hasSourceAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        try validateImportableFile(at: sourceURL)

        let attachmentID = UUID()
        let destinationRoot = try activeStorageRoot()
        let storageKind = activeStorageKind()
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

        let destinationName = sanitizedStoredFilename(sourceURL.lastPathComponent, fallback: "Attachment")
        let destinationURL = uniqueDestination(for: destinationName, in: entryFolder)
        let temporaryURL = entryFolder.appendingPathComponent(".\(attachmentID.uuidString).importing", isDirectory: false)

        try? FileManager.default.removeItem(at: temporaryURL)
        do {
            try FileManager.default.copyItem(at: sourceURL, to: temporaryURL)
            try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)
        } catch {
            try? FileManager.default.removeItem(at: temporaryURL)
            throw LibraryStorageError.copyFailed(sourceURL.lastPathComponent, error.localizedDescription)
        }

        let relativePath = destinationURL.path.replacingOccurrences(
            of: destinationRoot.path + "/",
            with: ""
        )
        let metadata = try fileMetadata(at: destinationURL, fallbackURL: sourceURL)

        return ImportedLibraryFile(
            id: attachmentID,
            displayName: sourceURL.lastPathComponent,
            storedPath: relativePath,
            storageKind: storageKind,
            contentType: metadata.contentType.identifier,
            byteSize: metadata.byteSize,
            sha256: metadata.sha256,
            remoteStorageKey: remoteStorageKey(entryID: entryID, attachmentID: attachmentID, filename: destinationName)
        )
    }

    static func saveMarkdownNote(_ markdown: String, entryID: UUID, entryTitle: String) throws -> ImportedLibraryFile {
        let attachmentID = UUID()
        let destinationRoot = try activeStorageRoot()
        let storageKind = activeStorageKind()

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
        let metadata = try fileMetadata(at: destinationURL, fallbackURL: destinationURL)

        return ImportedLibraryFile(
            id: attachmentID,
            displayName: destinationURL.lastPathComponent,
            storedPath: relativePath(for: destinationURL, from: destinationRoot),
            storageKind: storageKind,
            contentType: "net.daringfireball.markdown",
            byteSize: metadata.byteSize,
            sha256: metadata.sha256,
            remoteStorageKey: remoteStorageKey(entryID: entryID, attachmentID: attachmentID, filename: destinationURL.lastPathComponent)
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

        let metadata = try fileMetadata(at: url, fallbackURL: url)
        attachment.byteSize = metadata.byteSize
        attachment.sha256 = metadata.sha256
        attachment.contentType = "net.daringfireball.markdown"
        attachment.syncState = .local
    }

    static func resolvedURL(for attachment: LibraryAttachment) -> URL? {
        let root = attachment.storageKind == workspaceStorageKind
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

    static func scopedAccess(forResolvedURL url: URL) -> LibraryStorageAccess {
        let standardizedURL = url.standardizedFileURL
        guard let workspaceURL else {
            return LibraryStorageAccess(url: nil)
        }

        let standardizedWorkspace = workspaceURL.standardizedFileURL
        let workspacePath = standardizedWorkspace.path
        let filePath = standardizedURL.path
        guard filePath == workspacePath || filePath.hasPrefix(workspacePath + "/") else {
            return LibraryStorageAccess(url: nil)
        }

        return LibraryStorageAccess(url: standardizedWorkspace)
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

    private static func activeStorageRoot() throws -> URL {
        if let workspaceURL {
            return workspaceURL
        }

        return try internalLibraryRoot()
    }

    private static func activeStorageKind() -> String {
        workspaceURL == nil ? internalStorageKind : workspaceStorageKind
    }

    private static func validateImportableFile(at url: URL) throws {
        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .isPackageKey])

        if values.isDirectory == true || values.isPackage == true {
            throw LibraryStorageError.unsupportedDirectory
        }

        if values.isRegularFile == false {
            throw LibraryStorageError.unsupportedFile
        }

        guard FileManager.default.isReadableFile(atPath: url.path) else {
            throw LibraryStorageError.unreadableFile(url.lastPathComponent)
        }
    }

    private static func fileMetadata(at url: URL, fallbackURL: URL) throws -> LibraryFileMetadata {
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .contentTypeKey])
        let byteSize = Int64(values.fileSize ?? 0)
        let fallbackContentType = try? fallbackURL.resourceValues(forKeys: [.contentTypeKey]).contentType
        let contentType = values.contentType
            ?? fallbackContentType
            ?? UTType(filenameExtension: fallbackURL.pathExtension)
            ?? UTType.data
        let sha256 = try sha256HexDigest(for: url)

        return LibraryFileMetadata(contentType: contentType, byteSize: byteSize, sha256: sha256)
    }

    private static func sha256HexDigest(for url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer {
            try? handle.close()
        }

        var hasher = SHA256()
        while true {
            guard let data = try handle.read(upToCount: 1024 * 1024), !data.isEmpty else {
                break
            }
            hasher.update(data: data)
        }

        return hasher.finalize()
            .map { String(format: "%02x", $0) }
            .joined()
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

    private static func sanitizedStoredFilename(_ filename: String, fallback: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " -_().[]"))
        let cleaned = filename.unicodeScalars
            .map { allowed.contains($0) ? Character(String($0)) : "-" }
        let name = String(cleaned).trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? fallback : name
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

    private static func remoteStorageKey(entryID: UUID, attachmentID: UUID, filename: String) -> String {
        "resources/\(entryID.uuidString.lowercased())/attachments/\(attachmentID.uuidString.lowercased())/\(filename)"
    }
}

enum LibraryStorageError: LocalizedError {
    case missingFile
    case unsupportedURL
    case unsupportedDirectory
    case unsupportedFile
    case unreadableFile(String)
    case copyFailed(String, String)

    var errorDescription: String? {
        switch self {
        case .missingFile:
            return "The saved file could not be found. Choose the correct Library folder in Settings and try again."
        case .unsupportedURL:
            return "Sympho can only import local files."
        case .unsupportedDirectory:
            return "Folders and app packages cannot be imported as Library files."
        case .unsupportedFile:
            return "This item is not a regular file Sympho can copy."
        case .unreadableFile(let filename):
            return "\(filename) is not readable. Check the file permissions and try again."
        case .copyFailed(let filename, let reason):
            return "\(filename) could not be copied: \(reason)"
        }
    }
}

struct ImportedLibraryFile {
    let id: UUID
    let displayName: String
    let storedPath: String
    let storageKind: String
    let contentType: String
    let byteSize: Int64
    let sha256: String
    let remoteStorageKey: String
}

struct LibraryRepositoryInfo {
    let branch: String
    let remoteURL: String?
}

struct LibraryFileMetadata {
    let contentType: UTType
    let byteSize: Int64
    let sha256: String
}

final class LibraryStorageAccess {
    private let url: URL?
    private let didStartAccessing: Bool

    init(url: URL?) {
        self.url = url
        self.didStartAccessing = url?.startAccessingSecurityScopedResource() ?? false
    }

    deinit {
        if didStartAccessing {
            url?.stopAccessingSecurityScopedResource()
        }
    }
}

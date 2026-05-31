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

    static func importFile(from sourceURL: URL, entryID: UUID) throws -> ImportedLibraryFile {
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
            .appendingPathComponent(entryID.uuidString, isDirectory: true)
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
}

struct ImportedLibraryFile {
    let displayName: String
    let storedPath: String
    let storageKind: String
    let contentType: String
}

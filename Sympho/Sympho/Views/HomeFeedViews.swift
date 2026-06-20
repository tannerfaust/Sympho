//
//  HomeFeedViews.swift
//  Sympho
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import QuickLookThumbnailing
#if os(macOS)
import AppKit
#endif

// MARK: - Feed Item

enum HomeFeedItemKind: Hashable {
    case resource
    case node
    case project
}

struct HomeFeedItem: Identifiable {
    let id: UUID
    let kind: HomeFeedItemKind
    let title: String
    let subtitle: String
    let activityDate: Date
    let isPinned: Bool
    let resource: Resource?
    let node: Node?
    let project: Project?

    static func from(resource: Resource) -> HomeFeedItem {
        HomeFeedItem(
            id: resource.id,
            kind: .resource,
            title: resource.title,
            subtitle: resource.homeFeedSubtitle,
            activityDate: resource.homeActivityDate,
            isPinned: resource.isPinned,
            resource: resource,
            node: nil,
            project: nil
        )
    }

    static func from(node: Node) -> HomeFeedItem {
        HomeFeedItem(
            id: node.id,
            kind: .node,
            title: node.title,
            subtitle: node.homeFeedSubtitle,
            activityDate: node.homeActivityDate,
            isPinned: node.isPinned,
            resource: nil,
            node: node,
            project: nil
        )
    }

    static func from(project: Project) -> HomeFeedItem {
        HomeFeedItem(
            id: project.id,
            kind: .project,
            title: project.title,
            subtitle: project.homeFeedSubtitle,
            activityDate: project.updatedAt,
            isPinned: project.isPinned,
            resource: nil,
            node: nil,
            project: project
        )
    }

    var typeLabel: String {
        switch kind {
        case .resource:
            return resource?.homeFeedTypeLabel ?? "Reference"
        case .node:
            return "Note"
        case .project:
            return "Project"
        }
    }

    var typeIconName: String {
        switch kind {
        case .resource:
            return resource?.homeFeedIconName ?? "doc.text"
        case .node:
            return "circle.hexagonpath"
        case .project:
            return "folder"
        }
    }
}

// MARK: - Preview Card

struct HomePreviewCard: View {
    @Environment(\.modelContext) private var modelContext

    let item: HomeFeedItem
    let showsPinBadge: Bool
    let onOpen: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .topTrailing) {
                    HomePreviewSurface(item: item)

                    if showsPinBadge || item.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(SymphoTheme.secondaryText)
                            .padding(6)
                            .background {
                                Circle()
                                    .fill(SymphoTheme.primaryCanvas.opacity(0.92))
                                    .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
                            }
                            .padding(8)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(SymphoTheme.primaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(item.subtitle)
                        .font(.system(size: 10.5))
                        .foregroundStyle(SymphoTheme.secondaryText)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Label(item.typeLabel, systemImage: item.typeIconName)
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(SymphoTheme.tertiaryText)

                        Spacer(minLength: 0)

                        Text(item.activityDate.homeFeedRelativeLabel)
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(SymphoTheme.tertiaryText)
                    }
                }
                .padding(.horizontal, 2)
            }
            .frame(width: 196, alignment: .leading)
            .padding(10)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(SymphoTheme.primaryCanvas)
                    .shadow(color: .black.opacity(isHovered ? 0.1 : 0.05), radius: isHovered ? 10 : 6, y: isHovered ? 4 : 2)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                isHovered ? SymphoTheme.dividerColor.opacity(0.95) : SymphoTheme.dividerColor,
                                lineWidth: 1
                            )
                    }
            }
            .contentShape(.rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .contextMenu {
            Button(item.isPinned ? "Unpin from Home" : "Pin to Home", systemImage: item.isPinned ? "pin.slash" : "pin") {
                togglePin()
            }
            Button("Open", systemImage: "arrow.up.right", action: onOpen)
        }
    }

    private func togglePin() {
        withAnimation(.snappy(duration: 0.18)) {
            switch item.kind {
            case .resource:
                item.resource?.isPinned.toggle()
                item.resource?.updatedAt = Date()
                item.resource?.isSynced = false
            case .node:
                item.node?.isPinned.toggle()
                item.node?.updatedAt = Date()
                item.node?.isSynced = false
            case .project:
                item.project?.isPinned.toggle()
                item.project?.updatedAt = Date()
                item.project?.isSynced = false
            }
            try? modelContext.save()
        }
    }
}

// MARK: - Preview Surface

private struct HomePreviewSurface: View {
    let item: HomeFeedItem

    var body: some View {
        Group {
            switch item.kind {
            case .resource:
                if let resource = item.resource {
                    HomeResourcePreview(resource: resource)
                } else {
                    HomePreviewPlaceholder(iconName: "doc.text", label: "Reference")
                }
            case .node:
                if let node = item.node {
                    HomeNodePreview(node: node)
                } else {
                    HomePreviewPlaceholder(iconName: "circle.hexagonpath", label: "Note")
                }
            case .project:
                if let project = item.project {
                    HomeProjectPreview(project: project)
                } else {
                    HomePreviewPlaceholder(iconName: "folder", label: "Project")
                }
            }
        }
        .frame(height: 118)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(SymphoTheme.dividerColor.opacity(0.65), lineWidth: 1)
        }
    }
}

private struct HomeResourcePreview: View {
    let resource: Resource

    var body: some View {
        if let thumbnailURL = resource.youtubeThumbnailURL {
            HomeRemoteThumbnail(url: thumbnailURL, fallbackIcon: "play.rectangle")
                .overlay(alignment: .center) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(.black.opacity(0.58), in: .circle)
                }
                .overlay(alignment: .bottomLeading) {
                    HomePreviewBadge(title: "VIDEO", iconName: "play.rectangle")
                }
        } else if let attachment = resource.homeRepresentativeAttachment {
            HomeAttachmentThumbnail(attachment: attachment)
                .overlay(alignment: .bottomLeading) {
                    HomePreviewBadge(title: attachment.typeLabel, iconName: attachment.iconName)
                }
        } else if !resource.bodyText.isEmpty {
            ZStack(alignment: .topLeading) {
                SymphoTheme.secondarySurface.opacity(0.55)

                Text(resource.bodyText)
                    .font(SymphoNoteTypography.previewFont)
                    .foregroundStyle(SymphoTheme.secondaryText)
                    .lineSpacing(2)
                    .multilineTextAlignment(.leading)
                    .padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .overlay(alignment: .bottomLeading) {
                HomePreviewBadge(title: "NOTE", iconName: "note.text")
            }
        } else {
            HomePreviewPlaceholder(iconName: resource.resourceType.iconName, label: resource.homeFeedTypeLabel)
        }
    }
}

private struct HomeNodePreview: View {
    let resource: Resource?
    let node: Node

    init(node: Node) {
        self.node = node
        self.resource = node.resources.first(where: { !$0.isDeletedLocally })
    }

    var body: some View {
        if let resource {
            HomeResourcePreview(resource: resource)
        } else if !node.desc.isEmpty {
            ZStack(alignment: .topLeading) {
                SymphoTheme.secondarySurface.opacity(0.55)

                Text(node.desc)
                    .font(SymphoNoteTypography.previewFont)
                    .foregroundStyle(SymphoTheme.secondaryText)
                    .lineSpacing(2)
                    .lineLimit(6)
                    .padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .overlay(alignment: .bottomLeading) {
                HomePreviewBadge(title: "NOTE", iconName: "circle.hexagonpath")
            }
        } else {
            HomePreviewPlaceholder(iconName: "circle.hexagonpath", label: "Learning node")
        }
    }
}

private struct HomeProjectPreview: View {
    let project: Project

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    SymphoTheme.secondarySurface.opacity(0.75),
                    SymphoTheme.elevatedCanvas.opacity(0.55)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 8) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(SymphoTheme.secondaryText)

                if !project.desc.isEmpty {
                    Text(project.desc)
                        .font(.system(size: 10.5))
                        .foregroundStyle(SymphoTheme.secondaryText)
                        .lineLimit(3)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                }
            }
            .padding(.vertical, 10)
        }
        .overlay(alignment: .bottomLeading) {
            HomePreviewBadge(title: "PROJECT", iconName: "folder")
        }
    }
}

private struct HomePreviewPlaceholder: View {
    let iconName: String
    let label: String

    var body: some View {
        ZStack {
            SymphoTheme.secondarySurface.opacity(0.55)

            VStack(spacing: 7) {
                Image(systemName: iconName)
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(SymphoTheme.secondaryText)

                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(SymphoTheme.tertiaryText)
            }
        }
    }
}

private struct HomePreviewBadge: View {
    let title: String
    let iconName: String

    var body: some View {
        Label(title, systemImage: iconName)
            .font(.system(size: 8.5, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(.black.opacity(0.56), in: .capsule)
            .padding(7)
    }
}

private struct HomeRemoteThumbnail: View {
    let url: URL
    let fallbackIcon: String

    @State private var image: PlatformImage?

    var body: some View {
        Group {
            if let image {
                Image(platformImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                HomePreviewPlaceholder(iconName: fallbackIcon, label: "Loading…")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .task(id: url) {
            image = await HomeRemoteThumbnailCache.shared.image(for: url)
        }
    }
}

private struct HomeAttachmentThumbnail: View {
    let attachment: HomeDisplayAttachment

    @State private var thumbnail: PlatformImage?

    var body: some View {
        ZStack {
            SymphoTheme.secondarySurface.opacity(0.55)

            if let thumbnail {
                Image(platformImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                Image(systemName: attachment.iconName)
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(SymphoTheme.secondaryText)
            }
        }
        .task(id: attachment.id) {
            guard let url = attachment.url else { return }
            thumbnail = await HomeThumbnailCache.shared.thumbnail(for: url, contentType: attachment.contentType)
        }
    }
}

// MARK: - Attachments & Thumbnails

struct HomeDisplayAttachment: Identifiable {
    let id: UUID
    let name: String
    let contentType: String
    let url: URL?

    var isImage: Bool { UTType(contentType)?.conforms(to: .image) == true }
    var isVideo: Bool { UTType(contentType)?.conforms(to: .movie) == true }

    var iconName: String {
        if isImage { return "photo" }
        if isVideo { return "film" }
        if UTType(contentType)?.conforms(to: .pdf) == true { return "doc.richtext" }
        return "doc"
    }

    var typeLabel: String {
        if isImage { return "IMAGE" }
        if isVideo { return "VIDEO" }
        if UTType(contentType)?.conforms(to: .pdf) == true { return "PDF" }
        return "FILE"
    }
}

@MainActor
private final class HomeRemoteThumbnailCache {
    static let shared = HomeRemoteThumbnailCache()

    private let cache = NSCache<NSURL, PlatformImage>()
    private var inFlight: [URL: Task<PlatformImage?, Never>] = [:]
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpMaximumConnectionsPerHost = 4
        configuration.timeoutIntervalForRequest = 12
        return URLSession(configuration: configuration)
    }()

    private init() {
        cache.countLimit = 32
    }

    func image(for url: URL) async -> PlatformImage? {
        if let cached = cache.object(forKey: url as NSURL) { return cached }
        if let task = inFlight[url] { return await task.value }

        let task = Task { () -> PlatformImage? in
            guard let (data, _) = try? await session.data(from: url),
                  let image = PlatformImage(data: data) else { return nil }
            return image
        }
        inFlight[url] = task
        let image = await task.value
        inFlight[url] = nil
        if let image { cache.setObject(image, forKey: url as NSURL) }
        return image
    }
}

@MainActor
private final class HomeThumbnailCache {
    static let shared = HomeThumbnailCache()

    private let cache = NSCache<NSURL, PlatformImage>()
    private var requests: [URL: Task<PlatformImage?, Never>] = [:]

    private init() {
        cache.countLimit = 64
    }

    func thumbnail(for url: URL, contentType: String) async -> PlatformImage? {
        if let cached = cache.object(forKey: url as NSURL) { return cached }
        if let request = requests[url] { return await request.value }

        let request = Task { await generateThumbnail(for: url, contentType: contentType) }
        requests[url] = request
        let image = await request.value
        requests[url] = nil
        if let image { cache.setObject(image, forKey: url as NSURL) }
        return image
    }

    private func generateThumbnail(for url: URL, contentType: String) async -> PlatformImage? {
        let type = UTType(contentType) ?? UTType(filenameExtension: url.pathExtension)
        if type?.conforms(to: .image) == true {
            return LibraryStorage.withWorkspaceAccess {
                guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]) else { return nil }
                return symphoDownsampledImage(data: data, maxPixelSize: 420)
            }
        }

        guard type?.conforms(to: .pdf) == true || type?.conforms(to: .movie) == true else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            // Keep the security-scoped workspace permission active for Quick Look's
            // entire asynchronous read, not only while scheduling the request.
            let access = LibraryStorage.scopedAccess(forResolvedURL: url)
            let request = QLThumbnailGenerator.Request(
                fileAt: url,
                size: CGSize(width: 420, height: 240),
                scale: PlatformScreen.scale,
                representationTypes: .thumbnail
            )
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { thumbnail, _ in
                withExtendedLifetime(access) {
                    continuation.resume(returning: thumbnail?.platformImage)
                }
            }
        }
    }
}

// MARK: - Model Helpers

extension Resource {
    var homeActivityDate: Date { lastOpenedAt ?? updatedAt }

    var homeFeedSubtitle: String {
        if let domain { return domain.title }
        if !bodyText.isEmpty { return bodyText.linePreview(maxLength: 56) }
        if let attachment = homeRepresentativeAttachment { return attachment.name }
        if !urlString.isEmpty, let url = URL(string: urlString), !url.isFileURL { return url.host ?? urlString }
        return "Saved reference"
    }

    var homeFeedTypeLabel: String {
        if youtubeThumbnailURL != nil { return "Video" }
        if let attachment = homeRepresentativeAttachment {
            switch attachment.typeLabel {
            case "PDF": return "PDF"
            case "IMAGE": return "Image"
            case "VIDEO": return "Video"
            default: return "Document"
            }
        }
        switch resourceType {
        case .pdf: return "PDF"
        case .url: return "Link"
        case .video: return "Video"
        case .note: return "Note"
        }
    }

    var homeFeedIconName: String {
        if youtubeThumbnailURL != nil { return "play.rectangle" }
        return homeRepresentativeAttachment?.iconName ?? resourceType.iconName
    }

    var homeRepresentativeAttachment: HomeDisplayAttachment? {
        if let attachment = attachments.sorted(by: { $0.homePreviewPriority < $1.homePreviewPriority }).first,
           let url = LibraryStorage.resolvedURL(for: attachment) {
            return HomeDisplayAttachment(
                id: attachment.id,
                name: attachment.displayName,
                contentType: attachment.contentType,
                url: url
            )
        }

        guard let legacyURL = LibraryStorage.legacyResolvedURL(for: self) else { return nil }
        return HomeDisplayAttachment(
            id: id,
            name: legacyURL.lastPathComponent,
            contentType: UTType(filenameExtension: legacyURL.pathExtension)?.identifier ?? UTType.data.identifier,
            url: legacyURL
        )
    }

    func markHomeOpened() {
        lastOpenedAt = Date()
        updatedAt = Date()
        isSynced = false
    }
}

extension Node {
    var homeActivityDate: Date { lastOpenedAt ?? updatedAt }

    var homeFeedSubtitle: String {
        if let module {
            let domain = module.track?.domain?.title ?? module.domain?.title
            if let domain { return "\(domain) › \(module.title)" }
            return module.title
        }
        if let project { return project.title }
        if !desc.isEmpty { return desc.linePreview(maxLength: 56) }
        return status.displayName
    }

    func markHomeOpened() {
        lastOpenedAt = Date()
        updatedAt = Date()
        isSynced = false
    }
}

extension Project {
    var homeFeedSubtitle: String {
        if !desc.isEmpty { return desc.linePreview(maxLength: 56) }
        let count = nodes.filter { !$0.isDeletedLocally }.count
        return count == 0 ? "Workspace" : "\(count) node\(count == 1 ? "" : "s")"
    }
}

private extension LibraryAttachment {
    var homePreviewPriority: Int {
        guard let type = UTType(contentType) else { return 3 }
        if type.conforms(to: .image) { return 0 }
        if type.conforms(to: .movie) { return 1 }
        if type.conforms(to: .pdf) { return 2 }
        return 3
    }
}

private extension Date {
    var homeFeedRelativeLabel: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

private extension String {
    func linePreview(maxLength: Int) -> String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        guard trimmed.count > maxLength else { return trimmed }
        return String(trimmed.prefix(maxLength - 1)) + "…"
    }
}

enum HomeFeedRecorder {
    static func markOpened(_ item: HomeFeedItem, in context: ModelContext) {
        switch item.kind {
        case .resource:
            item.resource?.markHomeOpened()
        case .node:
            item.node?.markHomeOpened()
        case .project:
            item.project?.updatedAt = Date()
            item.project?.isSynced = false
        }
        try? context.save()
    }
}

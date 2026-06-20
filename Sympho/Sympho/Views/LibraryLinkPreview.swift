//
//  LibraryLinkPreview.swift
//  Sympho
//
//  Rich link previews for Library URL entries. Uses LinkPresentation to fetch
//  Open Graph-style metadata (title, preview image, favicon) over the network.
//

import SwiftUI
import LinkPresentation

struct LibraryLinkMetadata {
    var title: String?
    var image: PlatformImage?
    var icon: PlatformImage?
    var host: String?
}

@MainActor
final class LinkMetadataService {
    static let shared = LinkMetadataService()

    private var cache: [URL: LibraryLinkMetadata] = [:]
    private var inFlight: [URL: Task<LibraryLinkMetadata, Never>] = [:]

    private init() {}

    func metadata(for url: URL) async -> LibraryLinkMetadata {
        if let cached = cache[url] { return cached }
        if let task = inFlight[url] { return await task.value }

        let task = Task<LibraryLinkMetadata, Never> { await Self.fetch(url) }
        inFlight[url] = task
        let result = await task.value
        inFlight[url] = nil
        cache[url] = result
        return result
    }

    private static func fetch(_ url: URL) async -> LibraryLinkMetadata {
        let fetched: LPLinkMetadata? = await withCheckedContinuation { continuation in
            let provider = LPMetadataProvider()
            provider.timeout = 10
            provider.startFetchingMetadata(for: url) { metadata, _ in
                // Keep the provider alive until its completion handler runs.
                withExtendedLifetime(provider) {
                    continuation.resume(returning: metadata)
                }
            }
        }

        guard let fetched else {
            return LibraryLinkMetadata(title: nil, image: nil, icon: nil, host: url.host)
        }

        async let image = loadImage(fetched.imageProvider)
        async let icon = loadImage(fetched.iconProvider)

        return LibraryLinkMetadata(
            title: fetched.title,
            image: await image,
            icon: await icon,
            host: url.host
        )
    }

    private static func loadImage(_ provider: NSItemProvider?) async -> PlatformImage? {
        guard let provider, provider.canLoadObject(ofClass: PlatformImage.self) else { return nil }
        return await withCheckedContinuation { continuation in
            provider.loadObject(ofClass: PlatformImage.self) { object, _ in
                continuation.resume(returning: object as? PlatformImage)
            }
        }
    }
}

/// Preview surface for a saved web link: OG image if available, otherwise
/// favicon + host, otherwise a link glyph.
struct LibraryLinkThumbnail: View {
    let url: URL

    @State private var metadata: LibraryLinkMetadata?
    @State private var didLoad = false

    var body: some View {
        ZStack {
            if let image = metadata?.image {
                Image(platformImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                fallback
            }
        }
        .task(id: url) {
            guard !didLoad else { return }
            didLoad = true
            metadata = await LinkMetadataService.shared.metadata(for: url)
        }
    }

    private var fallback: some View {
        ZStack {
            SymphoTheme.secondarySurface.opacity(0.55)

            VStack(spacing: 8) {
                if let icon = metadata?.icon {
                    Image(platformImage: icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                } else {
                    Image(systemName: "link")
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(SymphoTheme.secondaryText)
                }

                if let host = metadata?.host ?? url.host {
                    Text(host)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(SymphoTheme.secondaryText)
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                }
            }
        }
    }
}

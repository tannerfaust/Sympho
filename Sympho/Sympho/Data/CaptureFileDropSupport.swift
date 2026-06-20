//
//  CaptureFileDropSupport.swift
//  Sympho
//

import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#endif

extension Notification.Name {
    static let openQuickCaptureWithFiles = Notification.Name("openQuickCaptureWithFiles")
}

enum CaptureFileDropLoader {
    static func normalizedFileURLs(_ urls: [URL]) -> [URL] {
        urls
            .filter(\.isFileURL)
            .map { $0.standardizedFileURL }
    }

    #if os(macOS)
    static func urls(from draggingInfo: NSDraggingInfo) -> [URL] {
        var results: [URL] = []

        if let items = draggingInfo.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] {
            results.append(contentsOf: items)
        }

        if let names = draggingInfo.draggingPasteboard.propertyList(
            forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")
        ) as? [String] {
            results.append(contentsOf: names.map { URL(fileURLWithPath: $0) })
        }

        return normalizedFileURLs(results)
    }
    #endif

    static func load(from providers: [NSItemProvider], completion: @escaping ([URL]) -> Void) {
        guard !providers.isEmpty else {
            completion([])
            return
        }

        let group = DispatchGroup()
        var collected: [URL] = []
        let lock = NSLock()

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    defer { group.leave() }
                    if let url = item as? URL {
                        lock.lock()
                        collected.append(url)
                        lock.unlock()
                        return
                    }
                    if let data = item as? Data,
                       let url = URL(dataRepresentation: data, relativeTo: nil) {
                        lock.lock()
                        collected.append(url)
                        lock.unlock()
                    }
                }
                continue
            }

            group.enter()
            provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                defer { group.leave() }
                guard
                    let data,
                    let string = String(data: data, encoding: .utf8),
                    let url = URL(string: string)
                else {
                    return
                }
                lock.lock()
                collected.append(url)
                lock.unlock()
            }
        }

        group.notify(queue: .main) {
            completion(normalizedFileURLs(collected))
        }
    }
}

#if os(macOS)
struct GlobalCaptureFileDropLayer: NSViewRepresentable {
    @Binding var isTargeted: Bool
    let onDrop: ([URL]) -> Void

    func makeNSView(context: Context) -> CaptureDropView {
        let view = CaptureDropView()
        view.onDrop = onDrop
        view.onTargetChange = { isTargeted = $0 }
        return view
    }

    func updateNSView(_ nsView: CaptureDropView, context: Context) {
        nsView.onDrop = onDrop
        nsView.onTargetChange = { isTargeted = $0 }
    }

    final class CaptureDropView: NSView {
        var onDrop: (([URL]) -> Void)?
        var onTargetChange: ((Bool) -> Void)?

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            autoresizingMask = [.width, .height]
            registerForDraggedTypes([.fileURL, NSPasteboard.PasteboardType("NSFilenamesPboardType")])
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidMoveToSuperview() {
            super.viewDidMoveToSuperview()
            if let superview {
                frame = superview.bounds
            }
        }

        override func layout() {
            super.layout()
            if let superview {
                frame = superview.bounds
            }
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }

        override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
            let urls = CaptureFileDropLoader.urls(from: sender)
            guard !urls.isEmpty else { return [] }
            onTargetChange?(true)
            return .copy
        }

        override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
            draggingEntered(sender)
        }

        override func draggingExited(_ sender: NSDraggingInfo?) {
            onTargetChange?(false)
        }

        override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
            onTargetChange?(false)
            let urls = CaptureFileDropLoader.urls(from: sender)
            guard !urls.isEmpty else { return false }
            onDrop?(urls)
            return true
        }
    }
}

struct GlobalCaptureDropOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.05)
                .ignoresSafeArea()

            VStack(spacing: 10) {
                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 28, weight: .medium))
                Text("Drop to capture")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(SymphoTheme.primaryText)
            .padding(.horizontal, 28)
            .padding(.vertical, 22)
            .glassEffect(.regular, in: .rect(cornerRadius: 18))
            .shadow(color: .black.opacity(0.12), radius: 24, y: 10)
        }
        .allowsHitTesting(false)
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }
}
#endif

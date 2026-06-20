//
//  LibraryFilePreview.swift
//  Sympho
//

import SwiftUI
import UniformTypeIdentifiers

import PDFKit
#if os(macOS)
import AppKit
#endif

struct LibraryPreviewFile: Identifiable, Hashable {
    let id: UUID
    let title: String
    let contentType: String
    let url: URL
    let byteSize: Int64?

    var resolvedType: UTType {
        UTType(contentType) ?? UTType(filenameExtension: url.pathExtension) ?? .data
    }

    var isPDF: Bool {
        resolvedType.conforms(to: .pdf) || url.pathExtension.lowercased() == "pdf"
    }

    var isImage: Bool {
        resolvedType.conforms(to: .image)
    }

    var isTextLike: Bool {
        resolvedType.conforms(to: .plainText)
            || resolvedType.conforms(to: .text)
            || url.pathExtension.lowercased() == "md"
    }

    var isPreviewable: Bool {
        isPDF || isImage || isTextLike
    }

    var iconName: String {
        if isImage { return "photo" }
        if isPDF { return "doc.richtext" }
        if isTextLike { return "note.text" }
        if resolvedType.conforms(to: .movie) || resolvedType.conforms(to: .audiovisualContent) { return "film" }
        return "doc"
    }

    var typeLabel: String {
        if isImage { return "Image" }
        if isPDF { return "PDF" }
        if isTextLike { return "Text" }
        if resolvedType.conforms(to: .movie) || resolvedType.conforms(to: .audiovisualContent) { return "Video" }
        return "File"
    }

    var sizeLabel: String? {
        LibraryFileClassifier.formattedByteSize(byteSize)
    }
}

enum LibraryFileActions {
    static func openExternally(_ url: URL) {
        #if os(macOS)
        let access = LibraryStorage.scopedAccess(forResolvedURL: url)
        NSWorkspace.shared.open(url)
        withExtendedLifetime(access) {}
        #endif
    }

    static func revealInFinder(_ url: URL) {
        #if os(macOS)
        let access = LibraryStorage.scopedAccess(forResolvedURL: url)
        NSWorkspace.shared.activateFileViewerSelecting([url])
        withExtendedLifetime(access) {}
        #endif
    }
}

struct LibraryFilePreviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    let file: LibraryPreviewFile

    @State private var pdfCommand: LibraryPDFCommand?

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            previewBody
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        #if os(macOS)
        .frame(minWidth: 780, minHeight: 620)
        #endif
        .background(SymphoTheme.primaryCanvas)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: file.iconName)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(SymphoTheme.primaryText)
                .frame(width: 42, height: 42)
                .glassEffect(.regular, in: .rect(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 3) {
                Text(file.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SymphoTheme.primaryText)
                    .lineLimit(1)

                HStack(spacing: 7) {
                    Text(file.typeLabel)
                    if let sizeLabel = file.sizeLabel {
                        Text(sizeLabel)
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(SymphoTheme.secondaryText)
            }

            Spacer()

            if file.isPDF {
                pdfControls
                Divider()
                    .frame(height: 24)
            }

            Button {
                LibraryFileActions.revealInFinder(file.url)
            } label: {
                Image(systemName: "folder")
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .help("Show in Finder")

            Button {
                LibraryFileActions.openExternally(file.url)
            } label: {
                Image(systemName: "arrow.up.right.square")
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .help("Open externally")

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .help("Close")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var pdfControls: some View {
        HStack(spacing: 4) {
            Button {
                pdfCommand = LibraryPDFCommand(action: .previousPage)
            } label: {
                Image(systemName: "chevron.up")
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .help("Previous page")

            Button {
                pdfCommand = LibraryPDFCommand(action: .nextPage)
            } label: {
                Image(systemName: "chevron.down")
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .help("Next page")

            Button {
                pdfCommand = LibraryPDFCommand(action: .zoomOut)
            } label: {
                Image(systemName: "minus.magnifyingglass")
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .help("Zoom out")

            Button {
                pdfCommand = LibraryPDFCommand(action: .zoomIn)
            } label: {
                Image(systemName: "plus.magnifyingglass")
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .help("Zoom in")

            Button {
                pdfCommand = LibraryPDFCommand(action: .fit)
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .help("Fit page")
        }
    }

    @ViewBuilder
    private var previewBody: some View {
        if file.isPDF {
            LibraryPDFPreview(file: file, command: $pdfCommand)
        } else if file.isImage {
            LibraryImagePreviewContent(file: file)
        } else if file.isTextLike {
            LibraryTextPreviewContent(file: file)
        } else {
            LibraryGenericFilePreview(file: file)
        }
    }
}

struct LibraryPDFCommand: Equatable {
    enum Action: Equatable {
        case zoomIn
        case zoomOut
        case fit
        case previousPage
        case nextPage
        case find(String)
    }

    let id = UUID()
    let action: Action
}

private struct LibraryPDFPreview: View {
    let file: LibraryPreviewFile
    @Binding var command: LibraryPDFCommand?

    @State private var pageCount = 0
    @State private var loadError: String?
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(SymphoTheme.tertiaryText)

                TextField("Find in PDF", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .onSubmit {
                        command = LibraryPDFCommand(action: .find(searchText))
                    }

                Button {
                    command = LibraryPDFCommand(action: .find(searchText))
                } label: {
                    Image(systemName: "arrow.down.circle")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .disabled(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help("Find next")

                Spacer()

                if pageCount > 0 {
                    Text("\(pageCount) page\(pageCount == 1 ? "" : "s")")
                        .font(.system(size: 11))
                        .foregroundStyle(SymphoTheme.secondaryText)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 42)
            .background(SymphoTheme.elevatedCanvas.opacity(0.42))

            ZStack {
                LibraryPDFKitView(
                    url: file.url,
                    command: $command,
                    loadError: $loadError,
                    pageCount: $pageCount
                )

                if let loadError {
                    LibraryPreviewErrorView(message: loadError)
                }
            }
        }
    }
}

private struct LibraryPDFKitView: PlatformViewRepresentable {
    let url: URL
    @Binding var command: LibraryPDFCommand?
    @Binding var loadError: String?
    @Binding var pageCount: Int

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func makePDFView() -> PDFView {
        let pdfView = PDFView()
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.displaysPageBreaks = true
        pdfView.autoScales = true
        pdfView.backgroundColor = .clear
        return pdfView
    }

    private func sync(_ pdfView: PDFView, context: Context) {
        context.coordinator.loadIfNeeded(
            url: url,
            into: pdfView,
            pageCount: $pageCount,
            loadError: $loadError
        )

        if let command, context.coordinator.lastCommandID != command.id {
            context.coordinator.apply(command, to: pdfView)
            context.coordinator.lastCommandID = command.id
        }
    }

    #if os(macOS)
    func makeNSView(context: Context) -> PDFView { makePDFView() }
    func updateNSView(_ pdfView: PDFView, context: Context) { sync(pdfView, context: context) }
    #else
    func makeUIView(context: Context) -> PDFView { makePDFView() }
    func updateUIView(_ pdfView: PDFView, context: Context) { sync(pdfView, context: context) }
    #endif

    final class Coordinator {
        var currentURL: URL?
        var lastCommandID: UUID?

        func loadIfNeeded(
            url: URL,
            into pdfView: PDFView,
            pageCount: Binding<Int>,
            loadError: Binding<String?>
        ) {
            guard currentURL != url else { return }

            currentURL = url

            // PDFKit can lazily read a URL after this update pass has returned. Loading
            // the bytes while the workspace permission is active avoids intermittent
            // sandbox failures when PDFKit later renders or searches another page.
            guard let data = LibraryStorage.data(at: url),
                  let document = PDFDocument(data: data) else {
                pdfView.document = nil
                publish(pageCount: 0, loadError: "Sympho could not load this PDF.", pageCountBinding: pageCount, errorBinding: loadError)
                return
            }

            pdfView.document = document
            pdfView.autoScales = true
            publish(pageCount: document.pageCount, loadError: nil, pageCountBinding: pageCount, errorBinding: loadError)
        }

        func apply(_ command: LibraryPDFCommand, to pdfView: PDFView) {
            switch command.action {
            case .zoomIn:
                pdfView.scaleFactor = min(pdfView.scaleFactor * 1.18, pdfView.maxScaleFactor)
            case .zoomOut:
                pdfView.scaleFactor = max(pdfView.scaleFactor / 1.18, pdfView.minScaleFactor)
            case .fit:
                pdfView.autoScales = true
            case .previousPage:
                pdfView.goToPreviousPage(nil)
            case .nextPage:
                pdfView.goToNextPage(nil)
            case .find(let query):
                find(query, in: pdfView)
            }
        }

        private func find(_ query: String, in pdfView: PDFView) {
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty,
                  let selection = pdfView.document?.findString(trimmed, withOptions: [.caseInsensitive]).first else {
                return
            }

            pdfView.setCurrentSelection(selection, animate: true)
            pdfView.scrollSelectionToVisible(nil)
        }

        private func publish(
            pageCount: Int,
            loadError: String?,
            pageCountBinding: Binding<Int>,
            errorBinding: Binding<String?>
        ) {
            DispatchQueue.main.async {
                pageCountBinding.wrappedValue = pageCount
                errorBinding.wrappedValue = loadError
            }
        }
    }
}

private struct LibraryImagePreviewContent: View {
    let file: LibraryPreviewFile

    @State private var image: PlatformImage?
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            SymphoTheme.secondarySurface.opacity(0.36)

            if let image {
                Image(platformImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(18)
            } else if let errorMessage {
                LibraryPreviewErrorView(message: errorMessage)
            } else {
                ProgressView()
            }
        }
        .task(id: file.url) {
            guard let data = LibraryStorage.data(at: file.url),
                  let loadedImage = PlatformImage(data: data) else {
                errorMessage = "Sympho could not load this image."
                return
            }

            image = loadedImage
        }
    }
}

private struct LibraryTextPreviewContent: View {
    let file: LibraryPreviewFile

    @State private var text: String?
    @State private var errorMessage: String?
    @State private var isTruncated = false

    private let maxPreviewBytes = 1_500_000

    var body: some View {
        VStack(spacing: 0) {
            if isTruncated {
                Text("Previewing the first \(LibraryFileClassifier.formattedByteSize(Int64(maxPreviewBytes)) ?? "1.5 MB").")
                    .font(.system(size: 11))
                    .foregroundStyle(SymphoTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .frame(height: 34)
                    .background(SymphoTheme.elevatedCanvas.opacity(0.42))
            }

            ScrollView {
                if let text {
                    Text(text)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(SymphoTheme.primaryText)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(18)
                } else if let errorMessage {
                    LibraryPreviewErrorView(message: errorMessage)
                        .frame(maxWidth: .infinity, minHeight: 320)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 320)
                }
            }
        }
        .task(id: file.url) {
            loadText()
        }
    }

    private func loadText() {
        let access = LibraryStorage.scopedAccess(forResolvedURL: file.url)
        defer {
            withExtendedLifetime(access) {}
        }

        do {
            let handle = try FileHandle(forReadingFrom: file.url)
            defer {
                try? handle.close()
            }

            let data = try handle.read(upToCount: maxPreviewBytes) ?? Data()
            isTruncated = (file.byteSize ?? 0) > Int64(maxPreviewBytes)
            text = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
        } catch {
            errorMessage = "Sympho could not load this text file."
        }
    }
}

private struct LibraryGenericFilePreview: View {
    let file: LibraryPreviewFile

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: file.iconName)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(SymphoTheme.secondaryText)

            Text("Preview is not available for this file type.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(SymphoTheme.primaryText)

            Button {
                LibraryFileActions.openExternally(file.url)
            } label: {
                Label("Open Externally", systemImage: "arrow.up.right.square")
            }
            .buttonStyle(SymphoSecondaryButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SymphoTheme.secondarySurface.opacity(0.36))
    }
}

private struct LibraryPreviewErrorView: View {
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(SymphoTheme.secondaryText)

            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(SymphoTheme.primaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .padding(24)
        .background(SymphoTheme.primaryCanvas.opacity(0.92), in: .rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(SymphoTheme.dividerColor, lineWidth: 1)
        }
    }
}

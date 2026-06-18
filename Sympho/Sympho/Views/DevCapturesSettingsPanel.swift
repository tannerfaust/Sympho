//
//  DevCapturesSettingsPanel.swift
//  Sympho
//

import SwiftUI
import SwiftData

struct DevCapturesSettingsPanel: View {
    @Environment(\.modelContext) private var modelContext

    @Query(
        filter: #Predicate<DevCapture> { !$0.isDeletedLocally },
        sort: \DevCapture.createdAt,
        order: .reverse
    )
    private var captures: [DevCapture]

    @State private var selectedCapture: DevCapture?
    @State private var exportMessage: String?

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("\(captures.count) capture\(captures.count == 1 ? "" : "s")")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(SymphoTheme.secondaryText)

                Spacer()

                Button("Export Markdown") {
                    export(.markdown)
                }
                .buttonStyle(SymphoSecondaryButtonStyle())
                .disabled(captures.isEmpty)

                Button("Export CSV") {
                    export(.csv)
                }
                .buttonStyle(SymphoSecondaryButtonStyle())
                .disabled(captures.isEmpty)
            }

            if let exportMessage {
                Text(exportMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(SymphoTheme.secondaryText)
            }

            if captures.isEmpty {
                Text("No dev captures yet. Use Dev Capture in the sidebar to log bugs, ideas, and notes with automatic context.")
                    .font(.system(size: 11))
                    .foregroundStyle(SymphoTheme.secondaryText)
            } else {
                VStack(spacing: 0) {
                    ForEach(captures) { capture in
                        captureRow(capture)

                        if capture.id != captures.last?.id {
                            Divider()
                                .padding(.leading, 36)
                        }
                    }
                }
            }
        }
        .sheet(item: $selectedCapture) { capture in
            DevCaptureDetailSheet(capture: capture) {
                deleteCapture(capture)
            }
        }
    }

    private func captureRow(_ capture: DevCapture) -> some View {
        Button {
            selectedCapture = capture
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: capture.kind.iconName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(SymphoTheme.secondaryText)
                    .frame(width: 22, height: 22)
                    .background(SymphoTheme.elevatedCanvas.opacity(0.7), in: .circle)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(capture.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(SymphoTheme.primaryText)
                            .lineLimit(1)

                        Text(capture.kind.displayName)
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(SymphoTheme.tertiaryText)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(SymphoTheme.elevatedCanvas.opacity(0.8)))
                    }

                    if !capture.contextSummary.isEmpty {
                        Text(capture.contextSummary)
                            .font(.system(size: 10.5))
                            .foregroundStyle(SymphoTheme.secondaryText)
                            .lineLimit(1)
                    }

                    Text(dateFormatter.string(from: capture.createdAt))
                        .font(.system(size: 10))
                        .foregroundStyle(SymphoTheme.tertiaryText)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(SymphoTheme.tertiaryText)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func export(_ format: DevCaptureExportFormat) {
        #if os(macOS)
        if DevCaptureExporter.export(captures, format: format) {
            exportMessage = "Exported \(captures.count) capture\(captures.count == 1 ? "" : "s") as .\(format.fileExtension)."
        } else {
            exportMessage = "Export cancelled."
        }
        #endif
    }

    private func deleteCapture(_ capture: DevCapture) {
        capture.isDeletedLocally = true
        capture.updatedAt = Date()
        try? modelContext.save()
        selectedCapture = nil
    }
}

private struct DevCaptureDetailSheet: View {
    @Environment(\.dismiss) private var dismiss

    let capture: DevCapture
    let onDelete: () -> Void

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label(capture.kind.displayName, systemImage: capture.kind.iconName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SymphoTheme.secondaryText)

                Spacer()

                Text(capture.assignee.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(SymphoTheme.tertiaryText)
            }

            Text(capture.title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(SymphoTheme.primaryText)

            VStack(alignment: .leading, spacing: 4) {
                detailLine("Created", dateFormatter.string(from: capture.createdAt))
                detailLine("Section", capture.contextSection)
                if !capture.contextSummary.isEmpty {
                    detailLine("Context", capture.contextSummary)
                }
            }

            if !capture.bodyText.isEmpty {
                Text(capture.bodyText)
                    .font(.system(size: 13))
                    .foregroundStyle(SymphoTheme.primaryText)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(SymphoTheme.elevatedCanvas.opacity(0.55), in: .rect(cornerRadius: 10))
            }

            HStack {
                Button("Delete", role: .destructive) {
                    onDelete()
                    dismiss()
                }
                .buttonStyle(SymphoSecondaryButtonStyle())

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(SymphoPrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        #if os(macOS)
        .frame(width: 480)
        #endif
    }

    private func detailLine(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(SymphoTheme.tertiaryText)
                .frame(width: 58, alignment: .leading)

            Text(value)
                .font(.system(size: 11))
                .foregroundStyle(SymphoTheme.secondaryText)
                .textSelection(.enabled)
        }
    }
}

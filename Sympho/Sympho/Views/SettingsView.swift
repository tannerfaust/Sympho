//
//  SettingsView.swift
//  Sympho
//

import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

struct SettingsView: View {
    @State private var showsWorkspacePicker = false
    @State private var workspaceName = LibraryStorage.workspaceName
    @State private var repositoryInfo = LibraryStorage.repositoryInfo
    @State private var showsCompactTitle = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                header
                libraryStorageSection
                gitSection
            }
            .padding(.horizontal, SymphoTheme.outerPadding)
            .padding(.top, 18)
            .padding(.bottom, SymphoTheme.outerPadding)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top > 38
        } action: { _, newValue in
            withAnimation(.easeInOut(duration: 0.16)) {
                showsCompactTitle = newValue
            }
        }
        .safeAreaBar(edge: .top, spacing: 0) {
            Text("Settings")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(SymphoTheme.primaryText)
                .opacity(showsCompactTitle ? 1 : 0)
                .frame(maxWidth: .infinity)
                .frame(height: 26)
                .offset(y: -2)
                .accessibilityHidden(!showsCompactTitle)
        }
        .fileImporter(
            isPresented: $showsWorkspacePicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let folder = urls.first else { return }
            guard (try? LibraryStorage.setWorkspace(folder)) != nil else { return }
            refreshStorageState()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Settings")
                .editorialHeader()

            Text("Storage and versioning for your Sympho workspace.")
                .metadataSans()
        }
    }

    private var libraryStorageSection: some View {
        SettingsSection(title: "Library Folder", iconName: "folder") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: workspaceName == nil ? "internaldrive" : "folder")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(SymphoTheme.primaryText)
                        .frame(width: 42, height: 42)
                        .glassEffect(.regular, in: .rect(cornerRadius: 13))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(workspaceName ?? "Internal Storage")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(SymphoTheme.primaryText)

                        Text(workspaceName == nil ? "Files are stored inside Sympho." : "New Library files are copied into named folders inside Entries.")
                            .font(.system(size: 11))
                            .foregroundStyle(SymphoTheme.secondaryText)
                    }

                    Spacer()
                }

                HStack(spacing: 8) {
                    Button("Choose Folder") {
                        showsWorkspacePicker = true
                    }
                    .buttonStyle(SymphoSecondaryButtonStyle())

                    if workspaceName != nil {
                        Button("Show in Finder") {
                            openWorkspaceFolder()
                        }
                        .buttonStyle(SymphoSecondaryButtonStyle())

                        Button("Use Internal Storage") {
                            LibraryStorage.clearWorkspace()
                            refreshStorageState()
                        }
                        .buttonStyle(SymphoSecondaryButtonStyle())
                    }
                }
            }
        }
    }

    private var gitSection: some View {
        SettingsSection(title: "Git Versioning", iconName: "point.3.connected.trianglepath.dotted") {
            if let repositoryInfo {
                VStack(alignment: .leading, spacing: 12) {
                    settingsFact(label: "Status", value: "Repository detected", iconName: "checkmark.circle")
                    settingsFact(label: "Branch", value: repositoryInfo.branch, iconName: "arrow.triangle.branch")

                    if let remoteURL = repositoryInfo.remoteURL {
                        settingsFact(label: "Remote", value: remoteURL, iconName: "link")
                    }

                    Text("Sympho stores files inside the selected repository. Git commits and remote syncing remain under your control.")
                        .font(.system(size: 11))
                        .foregroundStyle(SymphoTheme.secondaryText)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(workspaceName == nil ? "Choose a Library folder to use Git versioning." : "No Git repository was found in this Library folder.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(SymphoTheme.primaryText)

                    Text("Initialize the selected folder with Git outside Sympho. This page will show its branch and remote automatically.")
                        .font(.system(size: 11))
                        .foregroundStyle(SymphoTheme.secondaryText)
                }
            }
        }
    }

    private func settingsFact(label: String, value: String, iconName: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: iconName)
                .foregroundStyle(SymphoTheme.secondaryText)
                .frame(width: 18)

            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(SymphoTheme.secondaryText)
                .frame(width: 54, alignment: .leading)

            Text(value)
                .font(.system(size: 12))
                .foregroundStyle(SymphoTheme.primaryText)
                .lineLimit(1)
                .textSelection(.enabled)
        }
    }

    private func refreshStorageState() {
        workspaceName = LibraryStorage.workspaceName
        repositoryInfo = LibraryStorage.repositoryInfo
    }

    private func openWorkspaceFolder() {
        #if os(macOS)
        guard let url = LibraryStorage.workspaceURL else { return }
        _ = LibraryStorage.withWorkspaceAccess {
            NSWorkspace.shared.open(url)
        }
        #endif
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    let iconName: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: iconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(SymphoTheme.primaryText)

            content
                .padding(15)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(SymphoTheme.elevatedCanvas.opacity(0.56))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(SymphoTheme.dividerColor, lineWidth: 1)
                }
        }
    }
}

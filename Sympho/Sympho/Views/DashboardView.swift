//
//  DashboardView.swift
//  Sympho
//
//  Created by Tanner Fause on 30.05.2026.
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    var onOpenDomain: (Domain) -> Void = { _ in }

    @Query(filter: #Predicate<Node> { $0.statusValue == "active" && !$0.isDeletedLocally },
           sort: \Node.updatedAt, order: .reverse)
    private var activeNodes: [Node]

    @Query(filter: #Predicate<Domain> { !$0.isArchived && !$0.isDeletedLocally },
           sort: [SortDescriptor(\Domain.sortIndex), SortDescriptor(\Domain.title)])
    private var domains: [Domain]

    @Query(filter: #Predicate<Project> { $0.isPinned && !$0.isDeletedLocally },
           sort: \Project.updatedAt, order: .reverse)
    private var pinnedProjects: [Project]

    @Query(filter: #Predicate<Track> { !$0.isDeletedLocally },
           sort: \Track.updatedAt, order: .reverse)
    private var allTracks: [Track]

    private var visibleTracks: [Track] {
        allTracks.filter { track in
            guard let domain = track.domain else { return false }
            return !domain.isArchived && !domain.isDeletedLocally
        }
    }

    @State private var selectedNodeForDetails: Node? = nil
    @State private var captureText = ""

    private let domainColumns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {

                // ── 1. Hero: primary active node ────────────────────
                if let primary = activeNodes.first {
                    HomeHeroCard(node: primary) {
                        selectedNodeForDetails = primary
                    }
                }

                // ── 2. Tracks: horizontal scroll ────────────────────
                if !visibleTracks.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(visibleTracks) { track in
                                HomeTrackCard(track: track) {
                                    if let domain = track.domain {
                                        onOpenDomain(domain)
                                    }
                                }
                            }
                        }
                    }
                }

                // ── 3. Pinned projects ──────────────────────────────
                if !pinnedProjects.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(pinnedProjects) { project in
                            HomePinnedCard(project: project)
                        }
                    }
                }

                // ── 4. Domains grid ─────────────────────────────────
                if !domains.isEmpty {
                    LazyVGrid(columns: domainColumns, spacing: 14) {
                        ForEach(domains) { domain in
                            HomeDomainCard(domain: domain) {
                                onOpenDomain(domain)
                            }
                        }
                    }
                }

                // ── 5. Capture ──────────────────────────────────────
                capturePill
            }
            .padding(36)
        }
        .sheet(item: $selectedNodeForDetails) { node in
            NodeDetailSheet(node: node)
        }
    }

    // MARK: - Capture Pill

    private var capturePill: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(SymphoTheme.tertiaryText)

            TextField("Capture a note or link…", text: $captureText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .onSubmit { handleCapture() }
        }
        .padding(.horizontal, 18)
        .frame(height: 42)
        .glassEffect(.regular.interactive(), in: .capsule)
    }

    private func handleCapture() {
        let trimmed = captureText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let isLink = trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://")

        let node = Node(
            title: isLink ? "Link: \(trimmed)" : trimmed,
            desc: "",
            isOrphan: true
        )

        if isLink {
            let res = Resource(title: "Captured Link", urlString: trimmed, resourceType: .url)
            modelContext.insert(res)
            node.resources.append(res)
        }

        modelContext.insert(node)
        try? modelContext.save()
        captureText = ""
    }
}

// MARK: - Hero Card (Primary Focus)

private struct HomeHeroCard: View {
    @Environment(\.modelContext) private var modelContext
    let node: Node
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // Breadcrumb
            if let path = breadcrumb {
                Text(path)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(SymphoTheme.tertiaryText)
            }

            // Title — larger, the hero of the page
            Text(node.title)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(SymphoTheme.primaryText)
                .lineLimit(2)
                .kerning(-0.3)

            // Description
            if !node.desc.isEmpty {
                Text(node.desc)
                    .font(.system(size: 13))
                    .foregroundStyle(SymphoTheme.secondaryText)
                    .lineSpacing(3)
                    .lineLimit(3)
            }

            // Attached resources
            let resources = node.resources.filter { !$0.isDeletedLocally }
            if !resources.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(resources) { res in
                            if let url = URL(string: res.urlString) {
                                Link(destination: url) {
                                    HStack(spacing: 5) {
                                        Image(systemName: res.resourceType.iconName)
                                            .font(.system(size: 10))
                                        Text(res.title)
                                            .lineLimit(1)
                                    }
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(SymphoTheme.primaryText)
                                    .padding(.vertical, 5)
                                    .padding(.horizontal, 9)
                                    .glassEffect(.regular.interactive(), in: .capsule)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }

            // Actions
            HStack {
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        node.status = .mastered
                        node.isSynced = false
                        try? modelContext.save()
                    }
                } label: {
                    Label("Mastered", systemImage: "checkmark")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.glass)
                .controlSize(.small)

                Spacer()

                Button(action: onOpen) {
                    HStack(spacing: 3) {
                        Text("Open")
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 9))
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(SymphoTheme.secondaryText)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }

    private var breadcrumb: String? {
        if let module = node.module {
            let domain = module.track?.domain?.title ?? module.domain?.title ?? ""
            return domain.isEmpty ? module.title : "\(domain) › \(module.title)"
        }
        if let project = node.project {
            return project.title
        }
        return nil
    }
}

// MARK: - Track Card (Horizontal Scroll)

private struct HomeTrackCard: View {
    let track: Track
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 8) {

                // Parent domain
                if let domain = track.domain {
                    Text(domain.title)
                        .font(.system(size: 10))
                        .foregroundStyle(SymphoTheme.tertiaryText)
                        .lineLimit(1)
                }

                // Track title
                Text(track.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(SymphoTheme.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)

                // Progress fraction
                let nodes = track.allNodes
                let mastered = nodes.filter { $0.status == .mastered }.count
                if !nodes.isEmpty {
                    Text("\(mastered)/\(nodes.count)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(SymphoTheme.tertiaryText)
                }
            }
            .frame(width: 220, alignment: .leading)
            .padding(16)
            .frame(height: 120)
            .contentShape(.rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
    }
}

// MARK: - Pinned Project Card

private struct HomePinnedCard: View {
    let project: Project

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "folder.fill")
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(SymphoTheme.secondaryText)
                .frame(width: 32, height: 32)
                .glassEffect(.regular, in: .circle)

            VStack(alignment: .leading, spacing: 2) {
                Text(project.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(SymphoTheme.primaryText)
                    .lineLimit(1)

                if !project.desc.isEmpty {
                    Text(project.desc)
                        .font(.system(size: 12))
                        .foregroundStyle(SymphoTheme.secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            let activeCount = project.nodes.filter { !$0.isDeletedLocally && $0.status == .active }.count
            let totalCount  = project.nodes.filter { !$0.isDeletedLocally }.count
            if totalCount > 0 {
                Text("\(activeCount)/\(totalCount)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(SymphoTheme.tertiaryText)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(SymphoTheme.tertiaryText)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
    }
}

// MARK: - Domain Card with Progress Ring

private struct HomeDomainCard: View {
    let domain: Domain
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 0) {

                // Progress ring with domain icon inside
                ZStack {
                    DomainProgressRing(progress: progress)

                    Image(systemName: DomainIcon.validated(domain.iconName))
                        .font(.system(size: 15, weight: .light))
                        .foregroundStyle(SymphoTheme.primaryText)
                }
                .padding(.bottom, 16)

                Spacer(minLength: 0)

                // Title
                Text(domain.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(SymphoTheme.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 110)
            .padding(20)
            .contentShape(.rect(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18))
    }

    private var progress: Double {
        let nodes = domain.allNodes
        guard !nodes.isEmpty else { return 0 }
        return Double(nodes.filter { $0.status == .mastered }.count) / Double(nodes.count)
    }
}

// MARK: - Progress Ring

private struct DomainProgressRing: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(SymphoTheme.dividerColor, lineWidth: 2.5)

            if progress > 0 {
                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(
                        SymphoTheme.colorMastered,
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.5), value: progress)
            }
        }
        .frame(width: 40, height: 40)
    }
}

#Preview {
    DashboardView()
}

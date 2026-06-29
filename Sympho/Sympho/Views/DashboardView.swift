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
    var onOpenTrack: (Track) -> Void = { _ in }
    var onOpenResource: (Resource) -> Void = { _ in }
    var onOpenNode: (Node) -> Void = { _ in }
    var onOpenProject: (Project) -> Void = { _ in }

    @Query(filter: #Predicate<Node> { $0.statusValue == "active" && !$0.isDeletedLocally },
           sort: \Node.updatedAt, order: .reverse)
    private var activeNodes: [Node]

    @Query(filter: #Predicate<Domain> { !$0.isArchived && !$0.isDeletedLocally },
           sort: [SortDescriptor(\Domain.sortIndex), SortDescriptor(\Domain.title)])
    private var domains: [Domain]

    @Query(filter: #Predicate<Resource> { !$0.isDeletedLocally },
           sort: \Resource.updatedAt, order: .reverse)
    private var allResources: [Resource]

    @Query(filter: #Predicate<Node> { !$0.isDeletedLocally },
           sort: \Node.updatedAt, order: .reverse)
    private var allNodes: [Node]

    @Query(filter: #Predicate<Project> { !$0.isDeletedLocally },
           sort: \Project.updatedAt, order: .reverse)
    private var allProjects: [Project]

    @Query(filter: #Predicate<Track> { !$0.isDeletedLocally },
           sort: \Track.updatedAt, order: .reverse)
    private var allTracks: [Track]

    private var visibleTracks: [Track] {
        allTracks.filter { track in
            guard let domain = track.domain else { return false }
            return !domain.isArchived && !domain.isDeletedLocally
        }
    }

    private var recentItems: [HomeFeedItem] {
        let nodeAttachedResourceIDs = Set(
            allNodes.flatMap { node in
                node.resources.filter { !$0.isDeletedLocally }.map(\.id)
            }
        )
        let resources = allResources
            .filter { !$0.isPinned && !nodeAttachedResourceIDs.contains($0.id) }
            .map(HomeFeedItem.from(resource:))
        let nodes = allNodes
            .filter { !$0.isPinned && (!$0.desc.isEmpty || !$0.resources.isEmpty) }
            .map(HomeFeedItem.from(node:))

        return (resources + nodes)
            .sorted { $0.activityDate > $1.activityDate }
            .prefix(12)
            .map { $0 }
    }

    private var pinnedItems: [HomeFeedItem] {
        let resources = allResources.filter(\.isPinned).map(HomeFeedItem.from(resource:))
        let nodes = allNodes.filter(\.isPinned).map(HomeFeedItem.from(node:))
        let projects = allProjects.filter(\.isPinned).map(HomeFeedItem.from(project:))

        return (resources + nodes + projects)
            .sorted { $0.activityDate > $1.activityDate }
    }

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
                        openNode(primary)
                    }
                }

                // ── 2. Recent ───────────────────────────────────────
                if !recentItems.isEmpty {
                    homeFeedSection(
                        title: "Recent",
                        subtitle: "Picked up where you left off",
                        items: recentItems,
                        showsPinBadge: false
                    )
                }

                // ── 3. Pinned ───────────────────────────────────────
                if !pinnedItems.isEmpty {
                    homeFeedSection(
                        title: "Pinned",
                        subtitle: "\(pinnedItems.count) saved shortcut\(pinnedItems.count == 1 ? "" : "s")",
                        items: pinnedItems,
                        showsPinBadge: true
                    )
                }

                // ── 4. Tracks: horizontal scroll ────────────────────
                if !visibleTracks.isEmpty {
                    tracksSection
                }

                // ── 5. Domains grid ─────────────────────────────────
                if !domains.isEmpty {
                    LazyVGrid(columns: domainColumns, spacing: 14) {
                        ForEach(domains) { domain in
                            HomeDomainCard(domain: domain) {
                                onOpenDomain(domain)
                            }
                        }
                    }
                }

                // ── 6. Capture ──────────────────────────────────────
                capturePill
            }
            .padding(36)
        }
    }

    private func homeFeedSection(
        title: String,
        subtitle: String,
        items: [HomeFeedItem],
        showsPinBadge: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .editorialSubtitle()

                Text(subtitle)
                    .captionSans()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(items) { item in
                        HomePreviewCard(item: item, showsPinBadge: showsPinBadge) {
                            openFeedItem(item)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()
        }
    }

    private func openFeedItem(_ item: HomeFeedItem) {
        HomeFeedRecorder.markOpened(item, in: modelContext)

        switch item.kind {
        case .resource:
            if let resource = item.resource { onOpenResource(resource) }
        case .node:
            if let node = item.node { openNode(node) }
        case .project:
            if let project = item.project { onOpenProject(project) }
        }
    }

    private func openNode(_ node: Node) {
        onOpenNode(node)
    }

    // MARK: - Tracks Section

    private var tracksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Tracks")
                    .editorialSubtitle()

                Text("\(visibleTracks.count) learning path\(visibleTracks.count == 1 ? "" : "s")")
                    .captionSans()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(visibleTracks) { track in
                        HomeTrackCard(track: track) {
                            onOpenTrack(track)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()
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
                SymphoNoteBody(text: node.desc, font: SymphoNoteTypography.previewFont)
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

    @State private var isHovered = false

    private var nodes: [Node] { track.allNodes }
    private var masteredCount: Int { nodes.filter { $0.status == .mastered }.count }
    private var progress: Double { track.progress }

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    if let domain = track.domain {
                        Text(domain.title)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(SymphoTheme.tertiaryText)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(SymphoTheme.tertiaryText)
                }

                Text(track.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(SymphoTheme.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)

                if !nodes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(SymphoTheme.dividerColor.opacity(0.55))

                                Capsule()
                                    .fill(SymphoTheme.colorMastered.opacity(0.85))
                                    .frame(width: geometry.size.width * CGFloat(progress))
                            }
                        }
                        .frame(height: 3)

                        Text("\(masteredCount)/\(nodes.count) mastered")
                            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(SymphoTheme.tertiaryText)
                    }
                }
            }
            .frame(width: 220, alignment: .leading)
            .padding(16)
            .frame(height: 128)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(SymphoTheme.primaryCanvas)
                    .shadow(color: .black.opacity(isHovered ? 0.1 : 0.05), radius: isHovered ? 10 : 6, y: isHovered ? 4 : 2)
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                isHovered ? SymphoTheme.dividerColor.opacity(0.9) : SymphoTheme.dividerColor,
                                lineWidth: 1
                            )
                    }
            }
            .contentShape(.rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Domain Card with Progress Ring

private struct HomeDomainCard: View {
    let domain: Domain
    let onOpen: () -> Void

    @State private var isHovered = false

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
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(SymphoTheme.primaryCanvas)
                    .shadow(color: .black.opacity(isHovered ? 0.1 : 0.05), radius: isHovered ? 10 : 6, y: isHovered ? 4 : 2)
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(
                                isHovered ? SymphoTheme.dividerColor.opacity(0.9) : SymphoTheme.dividerColor,
                                lineWidth: 1
                            )
                    }
            }
            .contentShape(.rect(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
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

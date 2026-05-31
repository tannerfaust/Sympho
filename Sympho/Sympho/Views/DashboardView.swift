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
    
    // SwiftData Queries
    @Query(filter: #Predicate<Node> { $0.statusValue == "active" && !$0.isDeletedLocally }, sort: \Node.updatedAt, order: .reverse)
    private var activeNodes: [Node]
    
    @Query(filter: #Predicate<Node> { ($0.isOrphan || ($0.module == nil && $0.project == nil)) && !$0.isDeletedLocally })
    private var orphanNodes: [Node]
    
    @Query(
        filter: #Predicate<Domain> { !$0.isArchived && !$0.isDeletedLocally },
        sort: [SortDescriptor(\Domain.sortIndex), SortDescriptor(\Domain.title)]
    )
    private var domains: [Domain]
    
    @Query(filter: #Predicate<Project> { $0.isPinned && !$0.isDeletedLocally }, sort: \Project.updatedAt, order: .reverse)
    private var pinnedProjects: [Project]
    
    @State private var selectedNodeForDetails: Node? = nil
    @State private var inlineCaptureText: String = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SymphoTheme.sectionSpacing) {
                // Header (Sans-Serif, letter-spaced)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Command Center")
                        .editorialHeader()
                    Text("Resume your active learning paths and workspaces.")
                        .metadataSans()
                }
                .padding(.top, 16)
                
                // 1. Inbox Captures Alert Banner (Only shows if there are unprocessed items)
                if !orphanNodes.isEmpty {
                    inboxAlertBanner
                }
                
                // 2. Primary Focus Area
                VStack(alignment: .leading, spacing: 14) {
                    Text("Active Focus Target")
                        .editorialTitle()
                    
                    if let primaryNode = activeNodes.first {
                        FocusTargetBlock(node: primaryNode) {
                            selectedNodeForDetails = primaryNode
                        }
                    } else {
                        emptyFocusView
                    }
                }
                
                MinimalDivider()
                
                // 3. Grid of Workspaces & Secondary Items
                HStack(alignment: .top, spacing: SymphoTheme.gridSpacing) {
                    // Left Side: Active Queue & Domains
                    VStack(alignment: .leading, spacing: SymphoTheme.sectionSpacing) {
                        // Active Queue
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Active Learning Queue")
                                .editorialTitle()
                            
                            if activeNodes.count <= 1 {
                                Text("No other active items in your queue.")
                                    .captionSans()
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(activeNodes.dropFirst()) { node in
                                        FlatQueueRow(node: node) {
                                            selectedNodeForDetails = node
                                        }
                                        if node.id != activeNodes.last?.id {
                                            MinimalDivider()
                                        }
                                    }
                                }
                            }
                        }
                        
                        MinimalDivider()
                        
                        // Domain activity
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Study Domains")
                                .editorialTitle()
                            
                            if domains.isEmpty {
                                Text("No domains created. Set them up in Domains.")
                                    .captionSans()
                            } else {
                                VStack(spacing: 4) {
                                    ForEach(domains) { domain in
                                        FlatDomainActivityRow(domain: domain) {
                                            onOpenDomain(domain)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Right Side: Pinned Projects & Inline Capture
                    VStack(alignment: .leading, spacing: SymphoTheme.sectionSpacing) {
                        // Pinned Workspaces
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Pinned Workspaces")
                                .editorialTitle()
                            
                            if pinnedProjects.isEmpty {
                                Text("No pinned projects. Pin a project to place it here.")
                                    .captionSans()
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(SymphoTheme.dividerColor.opacity(0.4))
                                    .cornerRadius(SymphoTheme.cornerRadius)
                            } else {
                                VStack(spacing: 8) {
                                    ForEach(pinnedProjects) { project in
                                        FlatProjectCard(project: project)
                                    }
                                }
                            }
                        }
                        
                        // Quick Capture Input Box
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Quick Capture")
                                .editorialTitle()
                            
                            VStack(spacing: 10) {
                                TextField("Add note or link...", text: $inlineCaptureText, onCommit: handleCapture)
                                    .textFieldStyle(.plain)
                                    .padding(10)
                                    .background(SymphoTheme.elevatedCanvas.opacity(0.62))
                                    .cornerRadius(SymphoTheme.cornerRadius)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: SymphoTheme.cornerRadius)
                                            .stroke(SymphoTheme.dividerColor, lineWidth: 1)
                                    )
                                
                                Button(action: handleCapture) {
                                    Text("Capture to Inbox")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(SymphoTheme.primaryAction)
                                        .cornerRadius(SymphoTheme.cornerRadius)
                                }
                                .buttonStyle(.plain)
                                .disabled(inlineCaptureText.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                        }
                    }
                    .frame(width: 260)
                }
            }
            .padding(SymphoTheme.outerPadding)
        }
        .sheet(item: $selectedNodeForDetails) { node in
            NodeDetailSheet(node: node)
        }
    }
    
    // MARK: - Inbox Alert Banner View
    
    private var inboxAlertBanner: some View {
        HStack {
            Image(systemName: "tray.and.arrow.down")
                .foregroundColor(SymphoTheme.primaryText)
                .font(.headline)
            
            Text("You have **\(orphanNodes.count)** unprocessed items in your Inbox.")
                .bodySans()
            
            Spacer()
            
            Text("Process Now")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
            .background(SymphoTheme.primaryAction)
                .cornerRadius(4)
        }
        .padding(12)
        .background(SymphoTheme.elevatedCanvas.opacity(0.62))
        .cornerRadius(SymphoTheme.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: SymphoTheme.cornerRadius)
                .stroke(SymphoTheme.dividerColor, lineWidth: 1)
        )
    }
    
    // MARK: - Empty Focus View
    
    private var emptyFocusView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No active learning targets.")
                .font(.system(size: 13, weight: .medium).italic())
                .foregroundColor(SymphoTheme.secondaryText)
            Text("Activate nodes within Domains to surface them here.")
                .captionSans()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SymphoTheme.elevatedCanvas.opacity(0.62))
        .cornerRadius(SymphoTheme.cornerRadius)
    }
    
    // MARK: - Actions
    
    private func handleCapture() {
        let trimmed = inlineCaptureText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let isLink = trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://")
        
        let node = Node(
            title: isLink ? "Link: \(trimmed)" : trimmed,
            desc: "Dashboard capture",
            isOrphan: true
        )
        
        if isLink {
            let res = Resource(title: "Captured Link", urlString: trimmed, resourceType: .url)
            modelContext.insert(res)
            node.resources.append(res)
        }
        
        modelContext.insert(node)
        try? modelContext.save()
        inlineCaptureText = ""
    }
}

// MARK: - Subcomponents (Flat & Shadowless HIG)

struct FocusTargetBlock: View {
    @Environment(\.modelContext) private var modelContext
    let node: Node
    var onOpenDetails: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Category Path
            HStack {
                if let module = node.module {
                    Text("\(module.track?.domain?.title ?? module.domain?.title ?? "Syllabus")  ›  \(module.title)".uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(SymphoTheme.secondaryText)
                } else if let project = node.project {
                    Text("PROJECT  ›  \(project.title)".uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(SymphoTheme.secondaryText)
                }
                Spacer()
                
                if node.priority == .critical {
                    Text("CRITICAL DEBT")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(SymphoTheme.colorCritical)
                }
            }
            
            // Title & Desc
            VStack(alignment: .leading, spacing: 4) {
                Text(node.title)
                    .font(.system(size: 20, weight: .regular, design: .default))
                    .foregroundColor(SymphoTheme.primaryText)
                
                if !node.desc.isEmpty {
                    Text(node.desc)
                        .bodySans()
                        .foregroundColor(SymphoTheme.secondaryText)
                }
            }
            
            // Connected Resources
            let resources = node.resources.filter { !$0.isDeletedLocally }
            if !resources.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(resources) { res in
                            if let url = URL(string: res.urlString) {
                                Link(destination: url) {
                                    HStack(spacing: 6) {
                                        Image(systemName: res.resourceType.iconName)
                                        Text(res.title)
                                            .lineLimit(1)
                                    }
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(SymphoTheme.primaryText)
                                    .padding(.vertical, 5)
                                    .padding(.horizontal, 9)
                                    .background(SymphoTheme.elevatedCanvas.opacity(0.72))
                                    .cornerRadius(4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            
            MinimalDivider()
            
            // Actions
            HStack {
                Button(action: {
                    withAnimation {
                        node.status = .mastered
                        node.isSynced = false
                        try? modelContext.save()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                        Text("Mark Concept Mastered")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.vertical, 7)
                    .padding(.horizontal, 14)
                    .background(SymphoTheme.primaryAction)
                    .cornerRadius(SymphoTheme.cornerRadius)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button(action: onOpenDetails) {
                    Text("Open Workspace details")
                        .font(.system(size: 11))
                        .foregroundColor(SymphoTheme.secondaryText)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(SymphoTheme.elevatedCanvas.opacity(0.50))
        .cornerRadius(SymphoTheme.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: SymphoTheme.cornerRadius)
                .stroke(SymphoTheme.dividerColor, lineWidth: 1)
        )
    }
}

struct FlatQueueRow: View {
    @Environment(\.modelContext) private var modelContext
    let node: Node
    var onOpen: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "circle")
                .foregroundColor(SymphoTheme.secondaryText)
                .font(.system(size: 13))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(node.title)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(SymphoTheme.primaryText)
                
                if let module = node.module {
                    Text(module.title)
                        .font(.system(size: 10))
                        .foregroundColor(SymphoTheme.secondaryText)
                }
            }
            
            Spacer()
            
            Button("Complete") {
                withAnimation {
                    node.status = .mastered
                    node.isSynced = false
                    try? modelContext.save()
                }
            }
            .font(.system(size: 10, weight: .medium))
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(SymphoTheme.dividerColor)
            .cornerRadius(4)
            
            Button(action: onOpen) {
                Image(systemName: "arrow.up.right.square")
                    .foregroundColor(SymphoTheme.secondaryText)
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
    }
}

struct FlatDomainActivityRow: View {
    let domain: Domain
    var onOpen: () -> Void
    
    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 10) {
                Image(systemName: DomainIcon.validated(domain.iconName))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(SymphoTheme.primaryText)
                    .frame(width: 22, height: 22)
                    .background {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(SymphoTheme.elevatedCanvas.opacity(0.72))
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(domain.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(SymphoTheme.primaryText)
                        .lineLimit(1)

                    if let activeNode = latestActiveNode {
                        Text(activeNode.title)
                            .font(.system(size: 11))
                            .foregroundStyle(SymphoTheme.secondaryText)
                            .lineLimit(1)
                    } else {
                        Text("No active focus")
                            .font(.system(size: 11))
                            .foregroundStyle(SymphoTheme.tertiaryText)
                    }
                }

                Spacer(minLength: 8)

                Text("\(activeNodes.count)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SymphoTheme.secondaryText)

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(SymphoTheme.tertiaryText)
            }
            .padding(.vertical, 7)
        }
        .buttonStyle(.plain)
    }

    private var activeNodes: [Node] {
        domain.allNodes
            .filter { $0.status == .active }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var latestActiveNode: Node? {
        activeNodes.first
    }
}

struct FlatProjectCard: View {
    let project: Project
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(project.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(SymphoTheme.primaryText)
                
                Spacer()
                
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundColor(SymphoTheme.secondaryText)
            }
            
            if !project.desc.isEmpty {
                Text(project.desc)
                    .font(.system(size: 11))
                    .foregroundColor(SymphoTheme.secondaryText)
                    .lineLimit(1)
            }
            
            HStack(spacing: 8) {
                Text("\(project.nodes.filter { !$0.isDeletedLocally }.count) nodes")
                Text("•")
                Text("\(project.resources.filter { !$0.isDeletedLocally }.count) materials")
            }
            .font(.system(size: 10))
            .foregroundColor(SymphoTheme.secondaryText)
        }
        .padding(12)
        .background(SymphoTheme.elevatedCanvas.opacity(0.50))
        .cornerRadius(SymphoTheme.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: SymphoTheme.cornerRadius)
                .stroke(SymphoTheme.dividerColor, lineWidth: 1)
        )
    }
}

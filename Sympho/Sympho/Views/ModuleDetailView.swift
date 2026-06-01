//
//  ModuleDetailView.swift
//  Sympho
//
//  Created by Antigravity on 31.05.2026.
//

import SwiftUI
import SwiftData

struct ModuleDetailView: View {
    @Environment(\.modelContext) private var modelContext
    
    let module: Module
    var onBack: () -> Void
    var onSelectNode: (Node) -> Void
    
    @State private var isEditingModule = false
    @State private var editedTitle = ""
    @State private var editedDesc = ""
    @State private var showsEditModuleSheet = false
    @State private var editNodeTarget: Node?
    
    // Inline creation
    @State private var showInlineAddNode = false
    @State private var newNodeInlineTitle = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SymphoTheme.sectionSpacing) {
                // Navigation and Header (Decluttered Apple Notes Style)
                VStack(alignment: .leading, spacing: 12) {
                    Button(action: onBack) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text(parentPageTitle)
                        }
                        .font(.caption)
                        .foregroundColor(SymphoTheme.secondaryText)
                    }
                    .buttonStyle(.plain)
                    
                    HStack(alignment: .top, spacing: 14) {
                        // Module visual indicator (Monochrome Cube icon)
                        Image(systemName: "cube")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundStyle(SymphoTheme.primaryText)
                            .frame(width: 44, height: 44)
                            .background {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(SymphoTheme.elevatedCanvas.opacity(0.62))
                            }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            if isEditingModule {
                                TextField("Module Title", text: $editedTitle)
                                    .font(.system(size: 24, weight: .bold))
                                    .textFieldStyle(.plain)
                                    .padding(.bottom, 2)
                                
                                TextField("Module Description", text: $editedDesc)
                                    .font(.system(size: 13))
                                    .textFieldStyle(.plain)
                                    .foregroundColor(SymphoTheme.secondaryText)
                            } else {
                                HStack(alignment: .center, spacing: 10) {
                                    Text(module.title)
                                        .editorialHeader()
                                    
                                    Button(action: {
                                        editedTitle = module.title
                                        editedDesc = module.desc
                                        isEditingModule = true
                                    }) {
                                        Image(systemName: "pencil")
                                            .font(.caption)
                                            .foregroundColor(SymphoTheme.secondaryText)
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                if !module.desc.isEmpty {
                                    Text(module.desc)
                                        .bodySans()
                                        .foregroundColor(SymphoTheme.secondaryText)
                                }
                            }
                        }

                        Spacer(minLength: 0)

                        SymphoOverflowMenu(
                            onEdit: { showsEditModuleSheet = true },
                            onDelete: { deleteModule() }
                        )
                    }
                }
                
                MinimalDivider()
                
                // Liquid Glass Prompt Banner (Clean input bar)
                if let domain = module.domain ?? module.track?.domain {
                    LiquidGlassPromptBanner(
                        domain: domain,
                        track: module.track,
                        module: module,
                        onNodeCreated: { _ in }
                    )
                }
                
                // Learning Nodes Section
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Learning Nodes")
                            .editorialSubtitle()
                        
                        Spacer()
                        
                        Button(action: {
                            withAnimation(.snappy(duration: 0.15)) {
                                showInlineAddNode.toggle()
                            }
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(SymphoTheme.primaryText)
                        }
                        .buttonStyle(.plain)
                        .help("Add new node")
                    }
                    
                    if showInlineAddNode {
                        HStack(spacing: 8) {
                            TextField("Node Title...", text: $newNodeInlineTitle, onCommit: saveNodeInline)
                                .textFieldStyle(.plain)
                                .padding(8)
                                .background(SymphoTheme.elevatedCanvas.opacity(0.5))
                                .cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(SymphoTheme.dividerColor, lineWidth: 1))
                            
                            Button("Save") {
                                saveNodeInline()
                            }
                            .buttonStyle(SymphoPrimaryButtonStyle())
                        }
                        .transition(.opacity)
                    }
                    
                    if activeNodes.isEmpty {
                        Text("No learning nodes. Click the plus button to add.")
                            .font(.system(size: 11).italic())
                            .foregroundColor(SymphoTheme.secondaryText)
                            .padding(.vertical, 4)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(activeNodes) { node in
                                nodeRowView(for: node)
                            }
                        }
                    }
                }
            }
            .padding(SymphoTheme.outerPadding)
        }
        .sheet(isPresented: $showsEditModuleSheet) {
            SymphoItemEditSheet(subject: .module(module)) {
                showsEditModuleSheet = false
            }
        }
        .sheet(item: $editNodeTarget) { node in
            SymphoItemEditSheet(subject: .node(node)) {
                editNodeTarget = nil
            }
        }
    }
    
    private func saveNodeInline() {
        let title = newNodeInlineTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        
        let newNode = Node(
            title: title,
            desc: "",
            status: .backlog,
            priority: .normal,
            module: module
        )
        modelContext.insert(newNode)
        module.nodes.append(newNode)
        module.isSynced = false
        try? modelContext.save()
        
        newNodeInlineTitle = ""
        showInlineAddNode = false
    }
    
    private var parentPageTitle: String {
        if let track = module.track {
            return track.title
        } else if let domain = module.domain {
            return domain.title
        }
        return "Back"
    }
    
    private var activeNodes: [Node] {
        module.nodes.filter { !$0.isDeletedLocally }
    }
    
    // MARK: - Node Card Row View
    
    @ViewBuilder
    private func nodeRowView(for node: Node) -> some View {
        Button(action: { onSelectNode(node) }) {
            HStack(spacing: 16) {
                // Large status button
                Button(action: { cycleNodeStatus(node) }) {
                    Image(systemName: nodeStatusIcon(node.status))
                        .font(.system(size: 15))
                        .foregroundColor(nodeStatusColor(node.status))
                }
                .buttonStyle(.plain)
                .help("Cycle node status (Backlog -> Active -> Mastered)")
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(node.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(SymphoTheme.primaryText)
                        
                        if node.priority == .critical {
                            Text("CRITICAL BLOCKER")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(SymphoTheme.colorCritical)
                                .cornerRadius(3)
                        }
                    }
                    
                    if !node.desc.isEmpty {
                        Text(node.desc)
                            .font(.system(size: 11))
                            .foregroundColor(SymphoTheme.secondaryText)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Resources count
                let activeResources = node.resources.filter { !$0.isDeletedLocally }
                if !activeResources.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "paperclip")
                        Text("\(activeResources.count)")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(SymphoTheme.secondaryText)
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(SymphoTheme.secondaryText.opacity(0.7))
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(SymphoTheme.elevatedCanvas.opacity(0.6))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(SymphoTheme.dividerColor, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Edit", systemImage: "pencil") { editNodeTarget = node }

            Button(node.priority == .critical ? "Set Priority Normal" : "Set Priority Critical Blocker") {
                node.priority = (node.priority == .critical ? .normal : .critical)
                node.isSynced = false
                try? modelContext.save()
            }
            
            Menu("Change Status") {
                Button("Backlog") { setNodeStatus(node, to: .backlog) }
                Button("Active") { setNodeStatus(node, to: .active) }
                Button("Mastered") { setNodeStatus(node, to: .mastered) }
            }
            
            Divider()
            
            Button(role: .destructive) {
                node.isDeletedLocally = true
                node.isSynced = false
                try? modelContext.save()
            } label: {
                Label("Delete Node", systemImage: "trash")
            }
        }
    }
    
    // MARK: - Actions
    
    private func cycleNodeStatus(_ node: Node) {
        let nextStatus: NodeStatus
        switch node.status {
        case .backlog: nextStatus = .active
        case .active: nextStatus = .mastered
        case .mastered: nextStatus = .backlog
        }
        setNodeStatus(node, to: nextStatus)
    }
    
    private func setNodeStatus(_ node: Node, to status: NodeStatus) {
        node.status = status
        node.isSynced = false
        try? modelContext.save()
    }

    private func deleteModule() {
        module.isDeletedLocally = true
        module.isSynced = false
        module.updatedAt = Date()
        try? modelContext.save()
        onBack()
    }
    
    private func nodeStatusIcon(_ status: NodeStatus) -> String {
        switch status {
        case .backlog: return "circle"
        case .active: return "play.circle.fill"
        case .mastered: return "checkmark.circle.fill"
        }
    }
    
    private func nodeStatusColor(_ status: NodeStatus) -> Color {
        switch status {
        case .backlog: return SymphoTheme.secondaryText
        case .active: return SymphoTheme.colorActive
        case .mastered: return SymphoTheme.colorMastered
        }
    }
}

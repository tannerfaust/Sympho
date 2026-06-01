//
//  NodeDetailView.swift
//  Sympho
//
//  Created by Antigravity on 31.05.2026.
//

import SwiftUI
import SwiftData

struct NodeDetailView: View {
    @Environment(\.modelContext) private var modelContext
    
    let node: Node
    var onBack: () -> Void
    
    @State private var isEditing = false
    @State private var editedTitle = ""
    @State private var editedDesc = ""
    
    @State private var newResourceTitle = ""
    @State private var newResourceURL = ""
    @State private var newResourceType: ResourceType = .url
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Navigation Bar
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text(node.module?.title ?? "Module")
                    }
                    .font(.caption)
                    .foregroundColor(SymphoTheme.secondaryText)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                if isEditing {
                    HStack(spacing: 8) {
                        Button("Cancel") {
                            isEditing = false
                        }
                        .buttonStyle(SymphoSecondaryButtonStyle())
                        
                        Button("Save") {
                            node.title = editedTitle
                            node.desc = editedDesc
                            node.isSynced = false
                            try? modelContext.save()
                            isEditing = false
                        }
                        .buttonStyle(SymphoPrimaryButtonStyle())
                        .disabled(editedTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } else {
                    SymphoOverflowMenu(
                        onEdit: { beginEditing() },
                        onDelete: { deleteNode() }
                    )
                }
            }
            .padding(.horizontal, SymphoTheme.outerPadding)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            MinimalDivider()
            
            // Workspace body
            HStack(alignment: .top, spacing: 0) {
                // Left Column: Parameters & Details (60%)
                ScrollView {
                    VStack(alignment: .leading, spacing: SymphoTheme.sectionSpacing) {
                        // Title and Description Card
                        VStack(alignment: .leading, spacing: 12) {
                            if isEditing {
                                TextField("Node Title", text: $editedTitle)
                                    .font(.system(size: 20, weight: .bold))
                                    .textFieldStyle(.plain)
                                    .padding(8)
                                    .background(SymphoTheme.elevatedCanvas.opacity(0.5))
                                    .cornerRadius(6)
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(SymphoTheme.dividerColor, lineWidth: 1))
                                
                                TextField("Write what you need to master here...", text: $editedDesc, axis: .vertical)
                                    .font(.system(size: 13))
                                    .textFieldStyle(.plain)
                                    .lineLimit(4...6)
                                    .padding(8)
                                    .background(SymphoTheme.elevatedCanvas.opacity(0.5))
                                    .cornerRadius(6)
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(SymphoTheme.dividerColor, lineWidth: 1))
                            } else {
                                Text(node.title)
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(SymphoTheme.primaryText)
                                
                                if !node.desc.isEmpty {
                                    Text(node.desc)
                                        .bodySans()
                                        .foregroundStyle(SymphoTheme.primaryText)
                                } else {
                                    Text("No description provided. Add details to document your learning milestones.")
                                        .font(.system(.body, design: .default).italic())
                                        .foregroundColor(SymphoTheme.secondaryText)
                                }
                            }
                        }
                        
                        MinimalDivider()
                        
                        // Status control chips (Redesigned - strictly monochrome)
                        VStack(alignment: .leading, spacing: 10) {
                            Text("LEARNING STATUS")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(SymphoTheme.tertiaryText)
                            
                            HStack(spacing: 8) {
                                ForEach(NodeStatus.allCases) { status in
                                    let isSelected = (node.status == status)
                                    Button(action: {
                                        withAnimation(.snappy(duration: 0.12)) {
                                            node.status = status
                                            node.isSynced = false
                                            try? modelContext.save()
                                        }
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                                .font(.system(size: 11))
                                            Text(status.displayName)
                                        }
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(isSelected ? SymphoTheme.primaryCanvas : SymphoTheme.primaryText)
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 12)
                                        .background {
                                            RoundedRectangle(cornerRadius: 14)
                                                .fill(isSelected ? SymphoTheme.primaryText : SymphoTheme.elevatedCanvas.opacity(0.5))
                                        }
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(isSelected ? .clear : SymphoTheme.dividerColor, lineWidth: 1)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        
                        // Blocker level control chips (Redesigned - strictly monochrome)
                        VStack(alignment: .leading, spacing: 10) {
                            Text("BLOCKER LEVEL")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(SymphoTheme.tertiaryText)
                            
                            HStack(spacing: 8) {
                                ForEach(NodePriority.allCases) { priority in
                                    let isSelected = (node.priority == priority)
                                    Button(action: {
                                        withAnimation(.snappy(duration: 0.12)) {
                                            node.priority = priority
                                            node.isSynced = false
                                            try? modelContext.save()
                                        }
                                    }) {
                                        Text(priority.displayName)
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(isSelected ? SymphoTheme.primaryCanvas : SymphoTheme.primaryText)
                                            .padding(.vertical, 6)
                                            .padding(.horizontal, 12)
                                            .background {
                                                RoundedRectangle(cornerRadius: 14)
                                                    .fill(isSelected ? SymphoTheme.primaryText : SymphoTheme.elevatedCanvas.opacity(0.5))
                                            }
                                            .overlay {
                                                RoundedRectangle(cornerRadius: 14)
                                                    .stroke(isSelected ? .clear : SymphoTheme.dividerColor, lineWidth: 1)
                                            }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(SymphoTheme.outerPadding)
                }
                .frame(maxWidth: .infinity)
                
                MinimalDivider()
                    .frame(width: 1)
                    .ignoresSafeArea()
                
                // Right Column: Converged Learning Assets (40%)
                ScrollView {
                    VStack(alignment: .leading, spacing: SymphoTheme.sectionSpacing) {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Converged Assets")
                                .editorialSubtitle()
                            
                            let activeResources = node.resources.filter { !$0.isDeletedLocally }
                            if activeResources.isEmpty {
                                Text("No materials attached yet. Link assets to support this node.")
                                    .font(.system(size: 11))
                                    .foregroundColor(SymphoTheme.secondaryText)
                                    .padding(.vertical, 4)
                            } else {
                                VStack(spacing: 8) {
                                    ForEach(activeResources) { res in
                                        ResourceRow(resource: res, onRemove: {
                                            removeResource(res)
                                        })
                                    }
                                }
                            }
                        }
                        
                        MinimalDivider()
                        
                        // Add Asset Form
                        VStack(alignment: .leading, spacing: 10) {
                            Text("LINK A NEW ASSET")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(SymphoTheme.tertiaryText)
                            
                            Picker("Asset Type", selection: $newResourceType) {
                                ForEach(ResourceType.allCases) { type in
                                    Label(type.displayName, systemImage: type.iconName).tag(type)
                                }
                            }
                            .pickerStyle(.menu)
                            .font(.system(size: 11))
                            
                            TextField("Asset Title (e.g. Reference Video)", text: $newResourceTitle)
                                .textFieldStyle(.plain)
                                .padding(8)
                                .background(SymphoTheme.elevatedCanvas.opacity(0.5))
                                .cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(SymphoTheme.dividerColor, lineWidth: 1))
                            
                            TextField("URL or relative file path...", text: $newResourceURL)
                                .textFieldStyle(.plain)
                                .padding(8)
                                .background(SymphoTheme.elevatedCanvas.opacity(0.5))
                                .cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(SymphoTheme.dividerColor, lineWidth: 1))
                            
                            HStack {
                                Spacer()
                                Button(action: addResource) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "link")
                                        Text("Converge Asset")
                                    }
                                }
                                .buttonStyle(SymphoPrimaryButtonStyle())
                                .disabled(newResourceTitle.trimmingCharacters(in: .whitespaces).isEmpty || newResourceURL.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                        }
                        .padding(14)
                        .background {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(SymphoTheme.elevatedCanvas.opacity(0.4))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(SymphoTheme.dividerColor, lineWidth: 1)
                        }
                    }
                    .padding(SymphoTheme.outerPadding)
                }
                .frame(width: 320)
            }
        }
        .background(SymphoTheme.primaryCanvas)
    }
    
    // MARK: - Resource Operations
    
    private func addResource() {
        let trimmedTitle = newResourceTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = newResourceURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !trimmedURL.isEmpty else { return }
        
        let resource = Resource(
            title: trimmedTitle,
            urlString: trimmedURL,
            resourceType: newResourceType,
            domain: node.module?.domain ?? node.module?.track?.domain
        )
        
        modelContext.insert(resource)
        node.resources.append(resource)
        node.isSynced = false
        
        try? modelContext.save()
        
        newResourceTitle = ""
        newResourceURL = ""
    }
    
    private func removeResource(_ resource: Resource) {
        resource.isDeletedLocally = true
        resource.isSynced = false
        node.isSynced = false
        try? modelContext.save()
    }

    private func beginEditing() {
        editedTitle = node.title
        editedDesc = node.desc
        isEditing = true
    }

    private func deleteNode() {
        node.isDeletedLocally = true
        node.isSynced = false
        node.updatedAt = Date()
        try? modelContext.save()
        onBack()
    }
}

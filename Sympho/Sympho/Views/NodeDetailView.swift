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
    var backTitle: String = "Back"
    var onBack: () -> Void
    
    @State private var isEditing = false
    @State private var editedTitle = ""
    @State private var editedDesc = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Navigation Bar
            HStack {
                SymphoGlassBackButton(title: backTitle, action: onBack)
                
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
                                
                                MarkdownNoteEditor(
                                    text: $editedDesc,
                                    documentId: node.id.uuidString,
                                    placeholder: "Write what you need to master here..."
                                )
                                .frame(minHeight: 220)
                                .background(SymphoTheme.elevatedCanvas.opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(SymphoTheme.dividerColor, lineWidth: 1))
                            } else {
                                Text(node.title)
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(SymphoTheme.primaryText)
                                
                                SymphoNoteBody(
                                    text: node.desc,
                                    placeholder: "No description provided. Add details to document your learning milestones."
                                )
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
                
                // Right Column: Materials
                ScrollView {
                    NodeMaterialsSection(node: node)
                        .padding(SymphoTheme.outerPadding)
                }
                .frame(width: 320)
            }
        }
        .background(SymphoTheme.primaryCanvas)
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

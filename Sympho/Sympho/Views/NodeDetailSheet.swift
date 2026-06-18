//
//  NodeDetailSheet.swift
//  Sympho
//
//  Created by Tanner Fause on 30.05.2026.
//

import SwiftUI
import SwiftData

struct NodeDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let node: Node
    
    @State private var isEditing = false
    @State private var editedTitle: String = ""
    @State private var editedDesc: String = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: SymphoTheme.sectionSpacing) {
                        // Title and Description Block
                        VStack(alignment: .leading, spacing: 10) {
                            if isEditing {
                                TextField("Title", text: $editedTitle)
                                    .font(.system(.title2, design: .default))
                                    .textFieldStyle(.roundedBorder)
                                
                                MarkdownNoteEditor(
                                    text: $editedDesc,
                                    documentId: node.id.uuidString,
                                    placeholder: "Notes"
                                )
                                .frame(minHeight: 180)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(SymphoTheme.dividerColor, lineWidth: 1)
                                )
                            } else {
                                Text(node.title)
                                    .font(.system(.title2, design: .default))
                                    .fontWeight(.bold)
                                    .foregroundColor(SymphoTheme.primaryText)
                                
                                SymphoNoteBody(
                                    text: node.desc,
                                    placeholder: "No description provided."
                                )
                            }
                        }
                        
                        MinimalDivider()
                        
                        // Status & Priority Management
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Learning Parameters")
                                .editorialSubtitle()
                            
                            HStack(spacing: SymphoTheme.gridSpacing) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("STATUS")
                                        .font(.caption)
                                        .foregroundColor(SymphoTheme.secondaryText)
                                    
                                    Picker("Status", selection: Binding(
                                        get: { node.status },
                                        set: { node.status = $0; node.isSynced = false; try? modelContext.save() }
                                    )) {
                                        ForEach(NodeStatus.allCases) { status in
                                            Text(status.displayName).tag(status)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("BLOCKER LEVEL")
                                        .font(.caption)
                                        .foregroundColor(SymphoTheme.secondaryText)
                                    
                                    Picker("Priority", selection: Binding(
                                        get: { node.priority },
                                        set: { node.priority = $0; node.isSynced = false; try? modelContext.save() }
                                    )) {
                                        ForEach(NodePriority.allCases) { priority in
                                            Text(priority.displayName).tag(priority)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                }
                            }
                            .padding()
                            .background(SymphoTheme.secondarySurface)
                            .cornerRadius(SymphoTheme.cornerRadius)
                        }
                        
                        MinimalDivider()
                        
                        NodeMaterialsSection(node: node)
                    }
                    .padding(SymphoTheme.outerPadding)
                }
                
                MinimalDivider()
                
                // Footer
                HStack {
                    if isEditing {
                        Button("Cancel") {
                            isEditing = false
                        }
                        Spacer()
                        Button("Save") {
                            node.title = editedTitle
                            node.desc = editedDesc
                            node.isSynced = false
                            try? modelContext.save()
                            isEditing = false
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button {
                            node.isPinned.toggle()
                            node.updatedAt = Date()
                            node.isSynced = false
                            try? modelContext.save()
                        } label: {
                            Image(systemName: node.isPinned ? "pin.fill" : "pin")
                        }
                        .buttonStyle(.plain)
                        .help(node.isPinned ? "Unpin from Home" : "Pin to Home")

                        Button("Edit Details") {
                            editedTitle = node.title
                            editedDesc = node.desc
                            isEditing = true
                        }
                        Spacer()
                        Button("Done") { dismiss() }
                            .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
            }
            .navigationTitle(node.title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        #if os(macOS)
        .frame(width: 520, height: 600)
        #endif
    }
}

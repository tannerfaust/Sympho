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
    @State private var newResourceTitle: String = ""
    @State private var newResourceURL: String = ""
    @State private var newResourceType: ResourceType = .url
    
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
                                
                                TextEditor(text: $editedDesc)
                                    .frame(height: 80)
                                    .padding(4)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(SymphoTheme.dividerColor, lineWidth: 1)
                                    )
                            } else {
                                Text(node.title)
                                    .font(.system(.title2, design: .default))
                                    .fontWeight(.bold)
                                    .foregroundColor(SymphoTheme.primaryText)
                                
                                if !node.desc.isEmpty {
                                    Text(node.desc)
                                        .bodySans()
                                } else {
                                    Text("No description provided.")
                                        .font(.system(.body, design: .default).italic())
                                        .foregroundColor(SymphoTheme.secondaryText)
                                }
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
                        
                        // Linked Resources Section (Resource Convergence Job)
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Converged Learning Assets")
                                .editorialSubtitle()
                            
                            let activeResources = node.resources.filter { !$0.isDeletedLocally }
                            if activeResources.isEmpty {
                                Text("No materials attached. Save links, documents or PDFs to support your study sessions.")
                                    .captionSans()
                                    .padding(.vertical, 8)
                            } else {
                                ForEach(activeResources) { res in
                                    ResourceRow(resource: res, onRemove: {
                                        removeResource(res)
                                    })
                                }
                            }
                            
                            // Add Resource Form
                            VStack(alignment: .leading, spacing: 10) {
                                Text("LINK NEW ASSET")
                                    .font(.caption)
                                    .foregroundColor(SymphoTheme.secondaryText)
                                    .padding(.top, 8)
                                
                                HStack(spacing: 8) {
                                    Picker("Type", selection: $newResourceType) {
                                        ForEach(ResourceType.allCases) { type in
                                            Image(systemName: type.iconName).tag(type)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .frame(width: 80)
                                    
                                    TextField("Asset Title (e.g. YouTube Video)", text: $newResourceTitle)
                                        .textFieldStyle(.roundedBorder)
                                }
                                
                                HStack(spacing: 8) {
                                    TextField("Asset URL or file location...", text: $newResourceURL)
                                        .textFieldStyle(.roundedBorder)
                                    
                                    Button(action: addResource) {
                                        Text("Add")
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 6)
                                            .background(SymphoTheme.primaryAction)
                                            .cornerRadius(6)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(newResourceTitle.isEmpty || newResourceURL.isEmpty)
                                }
                            }
                            .padding()
                            .background(SymphoTheme.elevatedCanvas.opacity(0.62))
                            .cornerRadius(SymphoTheme.cornerRadius)
                            .overlay(
                                RoundedRectangle(cornerRadius: SymphoTheme.cornerRadius)
                                    .stroke(SymphoTheme.dividerColor, lineWidth: 1)
                            )
                        }
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
            .navigationTitle("Learning Unit Workspace")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        #if os(macOS)
        .frame(width: 520, height: 600)
        #endif
    }
    
    // MARK: - Helper Methods
    
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
        // Soft delete the resource link or mark the resource as deleted
        resource.isDeletedLocally = true
        resource.isSynced = false
        node.isSynced = false
        try? modelContext.save()
    }
}

// MARK: - Resource Row Component

struct ResourceRow: View {
    let resource: Resource
    var onRemove: () -> Void
    
    private var isLocalFile: Bool {
        if let url = URL(string: resource.urlString) {
            return url.isFileURL
        }
        return resource.fileRelativePath != nil
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: resource.resourceType.iconName)
                .font(.system(size: 15))
                .foregroundColor(SymphoTheme.secondaryText)
                .frame(width: 32, height: 32)
                .background(SymphoTheme.elevatedCanvas.opacity(0.8), in: .rect(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(SymphoTheme.dividerColor, lineWidth: 1)
                }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(resource.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(SymphoTheme.primaryText)
                    .lineLimit(1)
                
                if isLocalFile {
                    Text("Local Database Document")
                        .font(.system(size: 10))
                        .foregroundColor(SymphoTheme.secondaryText)
                } else {
                    Text(resource.urlString)
                        .font(.system(size: 10))
                        .foregroundColor(SymphoTheme.secondaryText)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Action Buttons
            HStack(spacing: 8) {
                Button {
                    if let url = URL(string: resource.urlString) {
                        #if os(macOS)
                        NSWorkspace.shared.open(url)
                        #endif
                    }
                } label: {
                    Text(isLocalFile ? "Open File" : "Open Link")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(SymphoTheme.primaryText)
                        .foregroundColor(SymphoTheme.primaryCanvas)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                
                Button(action: onRemove) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(SymphoTheme.colorCritical)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(SymphoTheme.elevatedCanvas.opacity(0.4))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(SymphoTheme.dividerColor, lineWidth: 1)
        )
    }
}

//
//  BlueprintView.swift
//  Sympho
//
//  Created by Tanner Fause on 30.05.2026.
//

import SwiftUI
import SwiftData

struct BlueprintView: View {
    let domain: Domain
    @State private var viewMode = 0 // 0: Sequential Roadmap Path, 1: Structural Tree List
    @State private var selectedNode: Node? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // View Mode Segmented Picker
            HStack {
                Text("Roadmap View Mode")
                    .font(.caption)
                    .foregroundColor(SymphoTheme.secondaryText)
                
                Spacer()
                
                Picker("Blueprint View Mode", selection: $viewMode) {
                    Text("Sequential Path").tag(0)
                    Text("Structural Tree").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(width: 240)
            }
            .padding(.horizontal, SymphoTheme.outerPadding)
            .padding(.vertical, 12)
            
            MinimalDivider()
            
            // Content
            if viewMode == 0 {
                sequentialRoadmapView
            } else {
                structuralTreeView
            }
        }
        .sheet(item: $selectedNode) { node in
            NodeDetailSheet(node: node)
        }
    }
    
    // MARK: - 1. Sequential Path View (Vertical Timeline)
    
    private var sequentialRoadmapView: some View {
        let allNodes = domain.allNodes
        
        return ScrollView {
            if allNodes.isEmpty {
                VStack(spacing: 8) {
                    Text("No learning nodes defined yet.")
                        .font(.system(.body, design: .default))
                        .foregroundColor(SymphoTheme.secondaryText)
                    Text("Create courses and modules inside Curriculum to generate your timeline.")
                        .captionSans()
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 60)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(allNodes.enumerated()), id: \.element.id) { index, node in
                        HStack(alignment: .top, spacing: 16) {
                            // Timeline track graphic
                            VStack(spacing: 0) {
                                Circle()
                                    .fill(nodeStatusColor(node.status))
                                    .frame(width: 14, height: 14)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: 2)
                                    )
                                
                                if index < allNodes.count - 1 {
                                    Rectangle()
                                        .fill(nodeStatusColor(node.status).opacity(0.4))
                                        .frame(width: 2)
                                        .frame(minHeight: 50)
                                }
                            }
                            
                            // Node content card
                            VStack(alignment: .leading, spacing: 6) {
                                Button(action: { selectedNode = node }) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text(node.title)
                                                .font(.system(.headline, design: .default))
                                                .foregroundColor(SymphoTheme.primaryText)
                                                .multilineTextAlignment(.leading)
                                            
                                            Spacer()
                                            
                                            Text(node.status.displayName.uppercased())
                                                .font(.system(size: 8, weight: .bold))
                                                .foregroundColor(nodeStatusColor(node.status))
                                        }
                                        
                                        if !node.desc.isEmpty {
                                            Text(node.desc)
                                                .font(.caption)
                                                .foregroundColor(SymphoTheme.secondaryText)
                                                .lineLimit(2)
                                                .multilineTextAlignment(.leading)
                                        }
                                        
                                        // Parent module details
                                        if let module = node.module {
                                            Text("Part of: \(module.title)")
                                                .font(.system(size: 9))
                                                .foregroundColor(SymphoTheme.secondaryText)
                                        }
                                    }
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(SymphoTheme.cornerRadius)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: SymphoTheme.cornerRadius)
                                            .stroke(SymphoTheme.dividerColor, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                
                                Spacer().frame(height: 16)
                            }
                        }
                    }
                }
                .padding(SymphoTheme.outerPadding)
            }
        }
    }
    
    // MARK: - 2. Structural Tree View (Nesting Hierarchy)
    
    private var structuralTreeView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Domain Title
                HStack(spacing: 8) {
                    Image(systemName: "folder.fill")
                        .foregroundColor(SymphoTheme.secondaryText)
                    Text(domain.title)
                        .editorialSubtitle()
                }
                .padding(.leading, 8)
                
                let activeTracks = domain.tracks.filter { !$0.isDeletedLocally }
                let activeStandaloneModules = domain.modules.filter { !$0.isDeletedLocally && $0.track == nil }
                
                // Tracks -> Modules -> Nodes
                ForEach(activeTracks) { track in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.turn.down.right")
                                .foregroundColor(SymphoTheme.secondaryText)
                                .font(.caption)
                            Text(track.title)
                                .font(.system(size: 14, weight: .bold))
                        }
                        .padding(.leading, 24)
                        
                        ForEach(track.modules.filter { !$0.isDeletedLocally }) { module in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Image(systemName: "list.bullet")
                                        .foregroundColor(SymphoTheme.secondaryText)
                                        .font(.caption2)
                                    Text(module.title)
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .padding(.leading, 48)
                                
                                ForEach(module.nodes.filter { !$0.isDeletedLocally }) { node in
                                    Button(action: { selectedNode = node }) {
                                        HStack(spacing: 6) {
                                            Circle()
                                                .fill(nodeStatusColor(node.status))
                                                .frame(width: 6, height: 6)
                                            Text(node.title)
                                                .font(.system(size: 12))
                                                .foregroundColor(SymphoTheme.primaryText)
                                            Spacer()
                                        }
                                        .padding(.leading, 72)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                
                // Standalone Modules -> Nodes
                ForEach(activeStandaloneModules) { module in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.turn.down.right")
                                .foregroundColor(SymphoTheme.secondaryText)
                                .font(.caption)
                            Text(module.title)
                                .font(.system(size: 13, weight: .medium))
                        }
                        .padding(.leading, 24)
                        
                        ForEach(module.nodes.filter { !$0.isDeletedLocally }) { node in
                            Button(action: { selectedNode = node }) {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(nodeStatusColor(node.status))
                                        .frame(width: 6, height: 6)
                                    Text(node.title)
                                        .font(.system(size: 12))
                                        .foregroundColor(SymphoTheme.primaryText)
                                    Spacer()
                                }
                                .padding(.leading, 48)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(SymphoTheme.outerPadding)
        }
    }
    
    // MARK: - Helpers
    
    private func nodeStatusColor(_ status: NodeStatus) -> Color {
        switch status {
        case .backlog: return SymphoTheme.secondaryText
        case .active: return SymphoTheme.colorActive
        case .mastered: return SymphoTheme.colorMastered
        }
    }
}

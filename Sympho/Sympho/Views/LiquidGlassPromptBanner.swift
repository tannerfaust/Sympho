//
//  LiquidGlassPromptBanner.swift
//  Sympho
//
//  Created by Antigravity on 31.05.2026.
//

import SwiftUI
import SwiftData

struct LiquidGlassPromptBanner: View {
    @Environment(\.modelContext) private var modelContext
    
    let domain: Domain
    var track: Track? = nil
    var module: Module? = nil
    
    var onTrackCreated: ((Track) -> Void)? = nil
    var onModuleCreated: ((Module) -> Void)? = nil
    var onNodeCreated: ((Node) -> Void)? = nil
    
    @State private var promptText = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Minimalist Glass Input Bar
            HStack(spacing: 12) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(SymphoTheme.primaryText)
                
                TextField(inputPlaceholder, text: $promptText, onCommit: handlePromptSubmit)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(SymphoTheme.primaryText)
                
                if !promptText.isEmpty {
                    Button(action: { promptText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(SymphoTheme.secondaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 40)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.regularMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(SymphoTheme.dividerColor, lineWidth: 1)
            }
            
            // Minimalist Suggestion Chips
            if !promptText.trimmingCharacters(in: .whitespaces).isEmpty {
                HStack(spacing: 8) {
                    Text("Add as:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(SymphoTheme.secondaryText)
                    
                    if showTrackAction {
                        suggestionChip(title: "Track") {
                            createTrack(title: promptText)
                        }
                    }
                    
                    if showModuleAction {
                        suggestionChip(title: "Module") {
                            createModule(title: promptText)
                        }
                    }
                    
                    if showNodeAction {
                        suggestionChip(title: "Node") {
                            createNode(title: promptText)
                        }
                    }
                }
                .padding(.horizontal, 6)
                .transition(.opacity)
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Conditions
    
    private var showTrackAction: Bool {
        track == nil && module == nil
    }
    
    private var showModuleAction: Bool {
        module == nil
    }
    
    private var showNodeAction: Bool {
        let modulesAvailable = !domain.modules.isEmpty || domain.tracks.contains(where: { !$0.modules.isEmpty })
        return module != nil || modulesAvailable
    }
    
    private var inputPlaceholder: String {
        if let module = module {
            return "Quick add node to '\(module.title)'..."
        } else if let track = track {
            return "Quick add module or node to '\(track.title)'..."
        } else {
            return "Ask to make stuff... (Type title and select option below)"
        }
    }
    
    // MARK: - Actions
    
    private func suggestionChip(title: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            withAnimation(.snappy(duration: 0.15)) {
                action()
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 9))
                Text(title)
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(SymphoTheme.primaryText)
            .padding(.vertical, 4)
            .padding(.horizontal, 10)
            .background(SymphoTheme.elevatedCanvas)
            .cornerRadius(12)
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(SymphoTheme.dividerColor, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
    
    private func handlePromptSubmit() {
        let cleanText = promptText.trimmingCharacters(in: .whitespaces)
        guard !cleanText.isEmpty else { return }
        
        let lower = cleanText.lowercased()
        if lower.hasPrefix("t:") || lower.hasPrefix("track:") {
            let title = cleanText.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
            if !title.isEmpty && showTrackAction {
                createTrack(title: title)
                return
            }
        } else if lower.hasPrefix("m:") || lower.hasPrefix("module:") {
            let title = cleanText.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
            if !title.isEmpty && showModuleAction {
                createModule(title: title)
                return
            }
        } else if lower.hasPrefix("n:") || lower.hasPrefix("node:") {
            let title = cleanText.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
            if !title.isEmpty && showNodeAction {
                createNode(title: title)
                return
            }
        }
        
        // Default action: if in module view, create node. Otherwise let them use suggestions.
        if let _ = module {
            createNode(title: cleanText)
        }
    }
    
    private func createTrack(title: String) {
        let newTrack = Track(title: title, desc: "", domain: domain)
        modelContext.insert(newTrack)
        domain.isSynced = false
        try? modelContext.save()
        
        onTrackCreated?(newTrack)
        promptText = ""
    }
    
    private func createModule(title: String) {
        let resolvedTrack = track
        let newModule = Module(
            title: title,
            desc: "",
            track: resolvedTrack,
            domain: resolvedTrack == nil ? domain : nil
        )
        modelContext.insert(newModule)
        
        if let t = resolvedTrack {
            t.isSynced = false
        } else {
            domain.isSynced = false
        }
        try? modelContext.save()
        
        onModuleCreated?(newModule)
        promptText = ""
    }
    
    private func createNode(title: String) {
        let resolvedModule = module ?? defaultModule
        guard let finalModule = resolvedModule else { return }
        
        let newNode = Node(
            title: title,
            desc: "",
            status: .backlog,
            priority: .normal,
            module: finalModule
        )
        modelContext.insert(newNode)
        finalModule.isSynced = false
        try? modelContext.save()
        
        onNodeCreated?(newNode)
        promptText = ""
    }
    
    private var defaultModule: Module? {
        if let track = track {
            return track.modules.filter { !$0.isDeletedLocally }.first
        }
        if let firstStandalone = domain.modules.filter({ !$0.isDeletedLocally }).first {
            return firstStandalone
        }
        return domain.tracks.flatMap { $0.modules }.filter { !$0.isDeletedLocally }.first
    }
}

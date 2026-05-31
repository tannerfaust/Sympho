//
//  SymphoModels.swift
//  Sympho
//
//  Created by Tanner Fause on 30.05.2026.
//

import Foundation
import SwiftData

// MARK: - Enums for Statuses and Types

enum NodeStatus: String, Codable, CaseIterable, Identifiable {
    case backlog = "backlog"
    case active = "active"
    case mastered = "mastered"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .backlog: return "Backlog"
        case .active: return "Active"
        case .mastered: return "Mastered"
        }
    }
}

enum NodePriority: String, Codable, CaseIterable, Identifiable {
    case normal = "normal"
    case critical = "critical" // "Knowledge Debt" blocker
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .normal: return "Normal"
        case .critical: return "Critical Blocker"
        }
    }
}

enum ProjectStatus: String, Codable, CaseIterable, Identifiable {
    case backlog = "backlog"
    case active = "active"
    case completed = "completed"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .backlog: return "Backlog"
        case .active: return "Active"
        case .completed: return "Completed"
        }
    }
}

enum ResourceType: String, Codable, CaseIterable, Identifiable {
    case pdf = "pdf"
    case url = "url"
    case video = "video"
    case note = "note"
    
    var id: String { self.rawValue }
    
    var iconName: String {
        switch self {
        case .pdf: return "doc.richtext"
        case .url: return "link"
        case .video: return "play.rectangle"
        case .note: return "note.text"
        }
    }
    
    var displayName: String {
        switch self {
        case .pdf: return "PDF/Document"
        case .url: return "Web URL"
        case .video: return "Video Tutorial"
        case .note: return "Plain Note"
        }
    }
}

enum DomainIcon: String, Codable, CaseIterable, Identifiable {
    case book = "book.closed"
    case brain = "brain"
    case processor = "cpu"
    case terminal = "terminal"
    case science = "atom"
    case mathematics = "function"
    case world = "globe"
    case humanities = "building.columns"
    case design = "paintpalette"
    case music = "music.note"
    case media = "camera"
    case nature = "leaf"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .book: return "General"
        case .brain: return "Mind"
        case .processor: return "Technology"
        case .terminal: return "Programming"
        case .science: return "Science"
        case .mathematics: return "Mathematics"
        case .world: return "World"
        case .humanities: return "Humanities"
        case .design: return "Design"
        case .music: return "Music"
        case .media: return "Media"
        case .nature: return "Nature"
        }
    }

    static func validated(_ iconName: String) -> String {
        Self(rawValue: iconName)?.rawValue ?? Self.book.rawValue
    }
}

// MARK: - SwiftData Models

@Model
final class Domain: Identifiable {
    @Attribute(.unique) var id: UUID
    var title: String
    var desc: String
    var colorHex: String
    var iconName: String = DomainIcon.book.rawValue
    var sortIndex: Int = 0
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date
    
    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \Track.domain) var tracks: [Track] = []
    @Relationship(deleteRule: .cascade, inverse: \Module.domain) var modules: [Module] = []
    @Relationship(deleteRule: .cascade, inverse: \Project.domain) var projects: [Project] = []
    @Relationship(deleteRule: .nullify, inverse: \Resource.domain) var resources: [Resource] = []
    
    // Sync Metadata
    var isSynced: Bool
    var isDeletedLocally: Bool
    var lastSyncedAt: Date?
    
    init(
        id: UUID = UUID(),
        title: String,
        desc: String = "",
        colorHex: String = "#000000",
        iconName: String = DomainIcon.book.rawValue,
        sortIndex: Int = 0,
        isArchived: Bool = false
    ) {
        self.id = id
        self.title = title
        self.desc = desc
        self.colorHex = colorHex
        self.iconName = DomainIcon.validated(iconName)
        self.sortIndex = sortIndex
        self.isArchived = isArchived
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isSynced = false
        self.isDeletedLocally = false
        self.lastSyncedAt = nil
    }
    
    // Trickle-up helper to get all nodes nested inside this Domain
    var allNodes: [Node] {
        var result: [Node] = []
        // Nodes from tracks -> modules -> nodes
        for track in tracks {
            for module in track.modules {
                result.append(contentsOf: module.nodes)
            }
        }
        // Nodes from standalone modules
        for module in modules {
            result.append(contentsOf: module.nodes)
        }
        // Nodes from nested projects
        for project in projects {
            result.append(contentsOf: project.nodes)
        }
        return result.filter { !$0.isDeletedLocally }
    }
    
    // Trickle-up helper to get all resources nested anywhere inside this Domain
    var allResources: [Resource] {
        var result = Set<Resource>()
        // From nested nodes
        for node in allNodes {
            for res in node.resources {
                if !res.isDeletedLocally {
                    result.insert(res)
                }
            }
        }
        // Directly belonging to Domain library
        for res in resources {
            if !res.isDeletedLocally {
                result.insert(res)
            }
        }
        // From nested projects
        for project in projects {
            for res in project.resources {
                if !res.isDeletedLocally {
                    result.insert(res)
                }
            }
        }
        return Array(result).sorted { $0.createdAt > $1.createdAt }
    }
    
}

@Model
final class Track: Identifiable {
    @Attribute(.unique) var id: UUID
    var title: String
    var desc: String
    var createdAt: Date
    var updatedAt: Date
    
    // Relationships
    var domain: Domain?
    @Relationship(deleteRule: .cascade, inverse: \Module.track) var modules: [Module] = []
    @Relationship(deleteRule: .nullify, inverse: \Project.track) var projects: [Project] = []
    
    // Sync Metadata
    var isSynced: Bool
    var isDeletedLocally: Bool
    var lastSyncedAt: Date?
    
    init(id: UUID = UUID(), title: String, desc: String = "", domain: Domain? = nil) {
        self.id = id
        self.title = title
        self.desc = desc
        self.domain = domain
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isSynced = false
        self.isDeletedLocally = false
        self.lastSyncedAt = nil
    }
    
    var allNodes: [Node] {
        modules.flatMap { $0.nodes }.filter { !$0.isDeletedLocally }
    }
    
    var progress: Double {
        let nodes = allNodes
        guard !nodes.isEmpty else { return 0.0 }
        let masteredCount = nodes.filter { $0.status == .mastered }.count
        return Double(masteredCount) / Double(nodes.count)
    }
}

@Model
final class Module: Identifiable {
    @Attribute(.unique) var id: UUID
    var title: String
    var desc: String
    var createdAt: Date
    var updatedAt: Date
    
    // Relationships
    var track: Track?
    var domain: Domain? // Standalone module directly in a Domain
    @Relationship(deleteRule: .cascade, inverse: \Node.module) var nodes: [Node] = []
    
    // Sync Metadata
    var isSynced: Bool
    var isDeletedLocally: Bool
    var lastSyncedAt: Date?
    
    init(id: UUID = UUID(), title: String, desc: String = "", track: Track? = nil, domain: Domain? = nil) {
        self.id = id
        self.title = title
        self.desc = desc
        self.track = track
        self.domain = domain
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isSynced = false
        self.isDeletedLocally = false
        self.lastSyncedAt = nil
    }
}

@Model
final class Project: Identifiable {
    @Attribute(.unique) var id: UUID
    var title: String
    var desc: String
    var statusValue: String
    var isPinned: Bool
    var createdAt: Date
    var updatedAt: Date
    
    // Relationships
    var domain: Domain?
    var track: Track?
    @Relationship(deleteRule: .nullify, inverse: \Node.project) var nodes: [Node] = []
    @Relationship var resources: [Resource] = []
    
    // Sync Metadata
    var isSynced: Bool
    var isDeletedLocally: Bool
    var lastSyncedAt: Date?
    
    var status: ProjectStatus {
        get { ProjectStatus(rawValue: statusValue) ?? .backlog }
        set { statusValue = newValue.rawValue }
    }
    
    init(id: UUID = UUID(), title: String, desc: String = "", status: ProjectStatus = .backlog, isPinned: Bool = false, domain: Domain? = nil, track: Track? = nil) {
        self.id = id
        self.title = title
        self.desc = desc
        self.statusValue = status.rawValue
        self.isPinned = isPinned
        self.domain = domain
        self.track = track
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isSynced = false
        self.isDeletedLocally = false
        self.lastSyncedAt = nil
    }
}

@Model
final class Node: Identifiable {
    @Attribute(.unique) var id: UUID
    var title: String
    var desc: String
    var statusValue: String
    var priorityValue: String
    var isOrphan: Bool
    var masteredAt: Date?
    var createdAt: Date
    var updatedAt: Date
    
    // Relationships
    var module: Module?
    var project: Project?
    @Relationship var resources: [Resource] = []
    
    // Sync Metadata
    var isSynced: Bool
    var isDeletedLocally: Bool
    var lastSyncedAt: Date?
    
    var status: NodeStatus {
        get { NodeStatus(rawValue: statusValue) ?? .backlog }
        set {
            statusValue = newValue.rawValue
            if newValue == .mastered {
                masteredAt = Date()
            } else {
                masteredAt = nil
            }
        }
    }
    
    var priority: NodePriority {
        get { NodePriority(rawValue: priorityValue) ?? .normal }
        set { priorityValue = newValue.rawValue }
    }
    
    init(id: UUID = UUID(), title: String, desc: String = "", status: NodeStatus = .backlog, priority: NodePriority = .normal, isOrphan: Bool = false, module: Module? = nil, project: Project? = nil) {
        self.id = id
        self.title = title
        self.desc = desc
        self.statusValue = status.rawValue
        self.priorityValue = priority.rawValue
        self.isOrphan = isOrphan
        self.module = module
        self.project = project
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isSynced = false
        self.isDeletedLocally = false
        self.lastSyncedAt = nil
    }
}

@Model
final class Resource: Identifiable, Hashable {
    @Attribute(.unique) var id: UUID
    var title: String
    var bodyText: String = ""
    var urlString: String
    var fileRelativePath: String?
    var resourceTypeValue: String
    var createdAt: Date
    var updatedAt: Date
    
    // Relationships
    var domain: Domain?
    @Relationship var nodes: [Node] = []
    @Relationship var projects: [Project] = []
    @Relationship(deleteRule: .cascade, inverse: \LibraryAttachment.resource) var attachments: [LibraryAttachment] = []
    
    // Sync Metadata
    var isSynced: Bool
    var isDeletedLocally: Bool
    var lastSyncedAt: Date?
    
    var resourceType: ResourceType {
        get { ResourceType(rawValue: resourceTypeValue) ?? .note }
        set { resourceTypeValue = newValue.rawValue }
    }
    
    init(id: UUID = UUID(), title: String, bodyText: String = "", urlString: String = "", fileRelativePath: String? = nil, resourceType: ResourceType = .note, domain: Domain? = nil) {
        self.id = id
        self.title = title
        self.bodyText = bodyText
        self.urlString = urlString
        self.fileRelativePath = fileRelativePath
        
        let lowerURL = urlString.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        var resolvedType = resourceType
        if lowerURL.contains("youtube.com") || lowerURL.contains("youtu.be") {
            resolvedType = .video
        } else if lowerURL.hasSuffix(".pdf") {
            resolvedType = .pdf
        } else if (lowerURL.hasPrefix("http://") || lowerURL.hasPrefix("https://")) && resolvedType == .note {
            resolvedType = .url
        }
        
        self.resourceTypeValue = resolvedType.rawValue
        self.domain = domain
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isSynced = false
        self.isDeletedLocally = false
        self.lastSyncedAt = nil
    }
    
    // Conform to Hashable for Set operations
    static func == (lhs: Resource, rhs: Resource) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

@Model
final class LibraryAttachment: Identifiable {
    @Attribute(.unique) var id: UUID
    var displayName: String
    var storedPath: String
    var storageKind: String
    var contentType: String
    var createdAt: Date
    var resource: Resource?

    init(
        id: UUID = UUID(),
        displayName: String,
        storedPath: String,
        storageKind: String,
        contentType: String,
        resource: Resource? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.storedPath = storedPath
        self.storageKind = storageKind
        self.contentType = contentType
        self.createdAt = Date()
        self.resource = resource
    }
}

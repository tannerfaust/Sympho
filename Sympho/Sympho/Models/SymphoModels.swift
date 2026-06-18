//
//  SymphoModels.swift
//  Sympho
//
//  Created by Tanner Fause on 30.05.2026.
//

import Foundation
import SwiftData
import SwiftUI

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

enum ReadingPriority: String, Codable, CaseIterable, Identifiable {
    case low = "low"
    case normal = "normal"
    case high = "high"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .low: return "Low"
        case .normal: return "Normal"
        case .high: return "High"
        }
    }

    var iconName: String {
        switch self {
        case .low: return "arrow.down"
        case .normal: return "minus"
        case .high: return "arrow.up"
        }
    }
}

enum ReadingStatus: String, Codable, CaseIterable, Identifiable {
    case queue = "queue"
    case reading = "reading"
    case paused = "paused"
    case finished = "finished"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .queue: return "Want to Read"
        case .reading: return "Reading"
        case .paused: return "Paused"
        case .finished: return "Finished"
        }
    }

    var iconName: String {
        switch self {
        case .queue: return "books.vertical"
        case .reading: return "book.fill"
        case .paused: return "pause.circle"
        case .finished: return "checkmark.circle.fill"
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

enum CaptureIntent: String, Codable, CaseIterable, Identifiable {
    case planInbox = "plan_inbox"
    case learningMaterial = "learning_material"
    case learningNode = "learning_node"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .planInbox: return "Plan Inbox"
        case .learningMaterial: return "Learning Material"
        case .learningNode: return "Learning Node"
        }
    }

    var shortName: String {
        switch self {
        case .planInbox: return "Inbox"
        case .learningMaterial: return "Material"
        case .learningNode: return "Node"
        }
    }

    var iconName: String {
        switch self {
        case .planInbox: return "tray"
        case .learningMaterial: return "doc.on.doc"
        case .learningNode: return "circle.hexagonpath"
        }
    }

    var placeholder: String {
        switch self {
        case .planInbox:
            return "Dump a note, link, or file — no sorting needed now..."
        case .learningMaterial:
            return "Paste a link, attach a file, or jot notes for what you're learning..."
        case .learningNode:
            return "Name the topic you want to learn, then add materials if you have them..."
        }
    }

    var headerTitle: String {
        switch self {
        case .planInbox: return "Inbox Capture"
        case .learningMaterial: return "Learning Material"
        case .learningNode: return "Learning Node"
        }
    }

    var headerSubtitle: String {
        switch self {
        case .planInbox:
            return "Unassigned input — deal with it later"
        case .learningMaterial:
            return "Resources for something you're learning"
        case .learningNode:
            return "A topic you want to study"
        }
    }

    var showsDestinationPicker: Bool {
        switch self {
        case .planInbox: return false
        case .learningMaterial, .learningNode: return true
        }
    }

    var pillForeground: Color {
        switch self {
        case .planInbox:
            return Color(red: 0.58, green: 0.44, blue: 0.08)
        case .learningMaterial:
            return Color(red: 0.10, green: 0.44, blue: 0.78)
        case .learningNode:
            return Color(red: 0.14, green: 0.52, blue: 0.36)
        }
    }

    var pillBackground: Color {
        switch self {
        case .planInbox:
            return Color(red: 0.98, green: 0.93, blue: 0.76)
        case .learningMaterial:
            return Color(red: 0.90, green: 0.95, blue: 1.0)
        case .learningNode:
            return Color(red: 0.90, green: 0.97, blue: 0.92)
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
    var sortIndex: Int = 0
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
    
    init(id: UUID = UUID(), title: String, desc: String = "", sortIndex: Int = 0, domain: Domain? = nil) {
        self.id = id
        self.title = title
        self.desc = desc
        self.sortIndex = sortIndex
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

    var activeModules: [Module] {
        modules
            .filter { !$0.isDeletedLocally }
            .sorted { lhs, rhs in
                if lhs.sortIndex != rhs.sortIndex { return lhs.sortIndex < rhs.sortIndex }
                return lhs.createdAt < rhs.createdAt
            }
    }

    var activeProjects: [Project] {
        projects.filter { !$0.isDeletedLocally }
    }

    var allResources: [Resource] {
        var result = Set<Resource>()
        for node in allNodes {
            for res in node.resources where !res.isDeletedLocally {
                result.insert(res)
            }
        }
        for project in activeProjects {
            for res in project.resources where !res.isDeletedLocally {
                result.insert(res)
            }
        }
        return Array(result).sorted { $0.createdAt > $1.createdAt }
    }
}

@Model
final class Module: Identifiable {
    @Attribute(.unique) var id: UUID
    var title: String
    var desc: String
    var sortIndex: Int = 0
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
    
    init(id: UUID = UUID(), title: String, desc: String = "", sortIndex: Int = 0, track: Track? = nil, domain: Domain? = nil) {
        self.id = id
        self.title = title
        self.desc = desc
        self.sortIndex = sortIndex
        self.track = track
        self.domain = domain
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isSynced = false
        self.isDeletedLocally = false
        self.lastSyncedAt = nil
    }

    var activeNodes: [Node] {
        nodes
            .filter { !$0.isDeletedLocally }
            .sorted { lhs, rhs in
                if lhs.sortIndex != rhs.sortIndex { return lhs.sortIndex < rhs.sortIndex }
                return lhs.createdAt < rhs.createdAt
            }
    }

    var allResources: [Resource] {
        var result = Set<Resource>()
        for node in activeNodes {
            for res in node.resources where !res.isDeletedLocally {
                result.insert(res)
            }
        }
        return Array(result).sorted { $0.createdAt > $1.createdAt }
    }

    var progress: Double {
        guard !activeNodes.isEmpty else { return 0 }
        let mastered = activeNodes.filter { $0.status == .mastered }.count
        return Double(mastered) / Double(activeNodes.count)
    }

    var resolvedDomain: Domain? {
        domain ?? track?.domain
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
    var sortIndex: Int = 0
    var statusValue: String
    var priorityValue: String
    var isOrphan: Bool
    var captureIntentValue: String = CaptureIntent.planInbox.rawValue
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

    var captureIntent: CaptureIntent {
        get { CaptureIntent(rawValue: captureIntentValue) ?? .planInbox }
        set { captureIntentValue = newValue.rawValue }
    }
    
    init(
        id: UUID = UUID(),
        title: String,
        desc: String = "",
        sortIndex: Int = 0,
        status: NodeStatus = .backlog,
        priority: NodePriority = .normal,
        isOrphan: Bool = false,
        captureIntent: CaptureIntent = .planInbox,
        module: Module? = nil,
        project: Project? = nil
    ) {
        self.id = id
        self.title = title
        self.desc = desc
        self.sortIndex = sortIndex
        self.statusValue = status.rawValue
        self.priorityValue = priority.rawValue
        self.isOrphan = isOrphan
        self.captureIntentValue = captureIntent.rawValue
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
    @Relationship var tags: [LibraryTag] = []
    var readingListItem: ReadingListItem?

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
final class LibraryTag: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date

    @Relationship(inverse: \Resource.tags) var resources: [Resource] = []
    @Relationship(inverse: \ReadingListItem.tags) var readingItems: [ReadingListItem] = []

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.createdAt = Date()
    }
}

@Model
final class ReadingListGroup: Identifiable {
    @Attribute(.unique) var id: UUID
    var title: String
    var sortIndex: Int = 0
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \ReadingListItem.group) var items: [ReadingListItem] = []

    init(id: UUID = UUID(), title: String, sortIndex: Int = 0) {
        self.id = id
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.sortIndex = sortIndex
        self.createdAt = Date()
    }
}

@Model
final class ReadingListItem: Identifiable {
    @Attribute(.unique) var id: UUID
    var title: String
    var author: String
    var notes: String
    var urlString: String
    var statusValue: String
    var priorityValue: String
    var stoppedAtVolume: String
    var stoppedAtPage: String
    var sortIndex: Int = 0
    var createdAt: Date
    var updatedAt: Date

    var domain: Domain?
    var module: Module?
    var group: ReadingListGroup?
    @Relationship var tags: [LibraryTag] = []
    @Relationship(inverse: \Resource.readingListItem) var linkedResources: [Resource] = []

    var isSynced: Bool
    var isDeletedLocally: Bool
    var lastSyncedAt: Date?

    var status: ReadingStatus {
        get { ReadingStatus(rawValue: statusValue) ?? .queue }
        set { statusValue = newValue.rawValue }
    }

    var priority: ReadingPriority {
        get { ReadingPriority(rawValue: priorityValue) ?? .normal }
        set { priorityValue = newValue.rawValue }
    }

    var progressMarker: String {
        let volume = stoppedAtVolume.trimmingCharacters(in: .whitespacesAndNewlines)
        let page = stoppedAtPage.trimmingCharacters(in: .whitespacesAndNewlines)
        switch (volume.isEmpty, page.isEmpty) {
        case (true, true): return ""
        case (false, true): return volume
        case (true, false): return page
        case (false, false): return "\(volume) · \(page)"
        }
    }

    init(
        id: UUID = UUID(),
        title: String,
        author: String = "",
        notes: String = "",
        urlString: String = "",
        status: ReadingStatus = .queue,
        priority: ReadingPriority = .normal,
        stoppedAtVolume: String = "",
        stoppedAtPage: String = "",
        sortIndex: Int = 0,
        domain: Domain? = nil,
        module: Module? = nil,
        group: ReadingListGroup? = nil
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.notes = notes
        self.urlString = urlString
        self.statusValue = status.rawValue
        self.priorityValue = priority.rawValue
        self.stoppedAtVolume = stoppedAtVolume
        self.stoppedAtPage = stoppedAtPage
        self.sortIndex = sortIndex
        self.domain = domain
        self.module = module
        self.group = group
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isSynced = false
        self.isDeletedLocally = false
        self.lastSyncedAt = nil
    }
}

// MARK: - Planner

enum PlannerBlockKind: String, Codable, CaseIterable, Identifiable {
    case study = "study"
    case training = "training"
    case other = "other"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .study: return "Study"
        case .training: return "Training"
        case .other: return "Other"
        }
    }

    var iconName: String {
        switch self {
        case .study: return "brain.head.profile"
        case .training: return "figure.run"
        case .other: return "sparkles"
        }
    }
}

@Model
final class PlannerWeeklyBlock: Identifiable {
    @Attribute(.unique) var id: UUID
    var title: String
    var notes: String
    var kindValue: String
    /// 1 = Monday … 7 = Sunday (ISO weekday)
    var weekday: Int
    var startMinute: Int
    var endMinute: Int
    var sortIndex: Int = 0
    var createdAt: Date
    var updatedAt: Date

    var kind: PlannerBlockKind {
        get { PlannerBlockKind(rawValue: kindValue) ?? .study }
        set { kindValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        kind: PlannerBlockKind = .study,
        weekday: Int,
        startMinute: Int,
        endMinute: Int,
        sortIndex: Int = 0
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.kindValue = kind.rawValue
        self.weekday = weekday
        self.startMinute = startMinute
        self.endMinute = endMinute
        self.sortIndex = sortIndex
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

@Model
final class PlannerEvent: Identifiable {
    @Attribute(.unique) var id: UUID
    var title: String
    var notes: String
    var kindValue: String
    var startDate: Date
    var endDate: Date
    var createdAt: Date
    var updatedAt: Date
    var isDeletedLocally: Bool

    var kind: PlannerBlockKind {
        get { PlannerBlockKind(rawValue: kindValue) ?? .other }
        set { kindValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        kind: PlannerBlockKind = .other,
        startDate: Date,
        endDate: Date
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.kindValue = kind.rawValue
        self.startDate = startDate
        self.endDate = endDate
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isDeletedLocally = false
    }
}

@Model
final class PlannerDayNote: Identifiable {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var dayKey: String
    var text: String
    var updatedAt: Date

    init(id: UUID = UUID(), dayKey: String, text: String = "") {
        self.id = id
        self.dayKey = dayKey
        self.text = text
        self.updatedAt = Date()
    }
}

enum LibraryAttachmentSyncState: String, Codable, CaseIterable {
    case local
    case queued
    case synced
    case failed
}

@Model
final class LibraryAttachment: Identifiable {
    @Attribute(.unique) var id: UUID
    var displayName: String
    var storedPath: String
    var storageKind: String
    var contentType: String
    var byteSize: Int64?
    var sha256: String?
    var remoteStorageKey: String?
    var syncStateValue: String?
    var createdAt: Date
    var resource: Resource?

    var syncState: LibraryAttachmentSyncState {
        get { LibraryAttachmentSyncState(rawValue: syncStateValue ?? LibraryAttachmentSyncState.local.rawValue) ?? .local }
        set { syncStateValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        displayName: String,
        storedPath: String,
        storageKind: String,
        contentType: String,
        byteSize: Int64? = nil,
        sha256: String? = nil,
        remoteStorageKey: String? = nil,
        syncState: LibraryAttachmentSyncState = .local,
        resource: Resource? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.storedPath = storedPath
        self.storageKind = storageKind
        self.contentType = contentType
        self.byteSize = byteSize
        self.sha256 = sha256
        self.remoteStorageKey = remoteStorageKey
        self.syncStateValue = syncState.rawValue
        self.createdAt = Date()
        self.resource = resource
    }

    convenience init(imported file: ImportedLibraryFile, resource: Resource? = nil) {
        self.init(
            id: file.id,
            displayName: file.displayName,
            storedPath: file.storedPath,
            storageKind: file.storageKind,
            contentType: file.contentType,
            byteSize: file.byteSize,
            sha256: file.sha256,
            remoteStorageKey: file.remoteStorageKey,
            syncState: .local,
            resource: resource
        )
    }
}

enum DevCaptureKind: String, Codable, CaseIterable, Identifiable {
    case bug
    case bigIdea
    case moduleIdea
    case designIdea
    case improvement

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bug: return "Bug"
        case .bigIdea: return "Big Idea"
        case .moduleIdea: return "Module Idea"
        case .designIdea: return "Design Idea"
        case .improvement: return "Improvement"
        }
    }

    var iconName: String {
        switch self {
        case .bug: return "ladybug"
        case .bigIdea: return "lightbulb.max"
        case .moduleIdea: return "square.stack.3d.up"
        case .designIdea: return "paintbrush"
        case .improvement: return "wrench.and.screwdriver"
        }
    }
}

enum DevCaptureAssignee: String, Codable, CaseIterable, Identifiable {
    case claude
    case gemini
    case cursor
    case copilot

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claude: return "Claude"
        case .gemini: return "Gemini"
        case .cursor: return "Cursor"
        case .copilot: return "Copilot"
        }
    }
}

@Model
final class DevCapture: Identifiable {
    @Attribute(.unique) var id: UUID
    var title: String
    var bodyText: String
    var kindValue: String
    var assigneeValue: String
    var contextSummary: String
    var contextSection: String
    var contextDomainTitle: String?
    var contextTrackTitle: String?
    var contextModuleTitle: String?
    var contextNodeTitle: String?
    var contextProjectTitle: String?
    var createdAt: Date
    var updatedAt: Date
    var isSynced: Bool
    var isDeletedLocally: Bool
    var lastSyncedAt: Date?

    var kind: DevCaptureKind {
        get { DevCaptureKind(rawValue: kindValue) ?? .improvement }
        set { kindValue = newValue.rawValue }
    }

    var assignee: DevCaptureAssignee {
        get { DevCaptureAssignee(rawValue: assigneeValue) ?? .cursor }
        set { assigneeValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        title: String,
        bodyText: String = "",
        kind: DevCaptureKind,
        assignee: DevCaptureAssignee,
        contextSummary: String,
        contextSection: String,
        contextDomainTitle: String? = nil,
        contextTrackTitle: String? = nil,
        contextModuleTitle: String? = nil,
        contextNodeTitle: String? = nil,
        contextProjectTitle: String? = nil
    ) {
        self.id = id
        self.title = title
        self.bodyText = bodyText
        self.kindValue = kind.rawValue
        self.assigneeValue = assignee.rawValue
        self.contextSummary = contextSummary
        self.contextSection = contextSection
        self.contextDomainTitle = contextDomainTitle
        self.contextTrackTitle = contextTrackTitle
        self.contextModuleTitle = contextModuleTitle
        self.contextNodeTitle = contextNodeTitle
        self.contextProjectTitle = contextProjectTitle
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isSynced = false
        self.isDeletedLocally = false
        self.lastSyncedAt = nil
    }
}

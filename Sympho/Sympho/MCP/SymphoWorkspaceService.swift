import Foundation
import SwiftData

@MainActor
final class SymphoWorkspaceService {
    let context: ModelContext
    private let encoder: JSONEncoder = { let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e }()

    init(context: ModelContext) { self.context = context }

    func search(query: String, kinds: Set<WorkspaceEntityKind> = [], offset: Int = 0, limit: Int = 50) throws -> WorkspacePage {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let all = try allEntities(includeDeleted: false).filter { dto in
            (kinds.isEmpty || kinds.contains(dto.kind)) && (needle.isEmpty || searchableText(dto).contains(needle))
        }
        let safeOffset = max(0, offset), safeLimit = min(max(1, limit), 100)
        return WorkspacePage(items: Array(all.dropFirst(safeOffset).prefix(safeLimit)), total: all.count, offset: safeOffset, limit: safeLimit)
    }

    func list(kind: WorkspaceEntityKind, includeDeleted: Bool = false, offset: Int = 0, limit: Int = 100) throws -> WorkspacePage {
        let all = try allEntities(includeDeleted: includeDeleted).filter { $0.kind == kind }
        let safeOffset = max(0, offset), safeLimit = min(max(1, limit), 100)
        return WorkspacePage(items: Array(all.dropFirst(safeOffset).prefix(safeLimit)), total: all.count, offset: safeOffset, limit: safeLimit)
    }

    func get(kind: WorkspaceEntityKind, id: UUID) throws -> WorkspaceEntityDTO {
        guard let dto = try allEntities(includeDeleted: true).first(where: { $0.kind == kind && $0.id == id }) else {
            throw WorkspaceServiceError.notFound("No \(kind.rawValue) exists with id \(id.uuidString)")
        }
        return dto
    }

    func learningOutline() throws -> [WorkspaceValue] {
        let domains = try context.fetch(FetchDescriptor<Domain>()).filter { !$0.isDeletedLocally && !$0.isArchived }
        return domains.sorted { $0.sortIndex < $1.sortIndex }.map { domain in
            .object([
                "id": .string(domain.id.uuidString), "title": .string(domain.title),
                "tracks": .array(domain.tracks.filter { !$0.isDeletedLocally }.sorted { $0.sortIndex < $1.sortIndex }.map { track in
                    .object(["id": .string(track.id.uuidString), "title": .string(track.title),
                             "modules": .array(track.activeModules.map { module in
                                .object(["id": .string(module.id.uuidString), "title": .string(module.title),
                                         "nodes": .array(module.activeNodes.map { .object(["id": .string($0.id.uuidString), "title": .string($0.title), "status": .string($0.statusValue)]) })])
                             })])
                }),
                "standalone_modules": .array(domain.modules.filter { !$0.isDeletedLocally && $0.track == nil }.map { .object(["id": .string($0.id.uuidString), "title": .string($0.title)]) }),
                "projects": .array(domain.projects.filter { !$0.isDeletedLocally }.map { .object(["id": .string($0.id.uuidString), "title": .string($0.title), "status": .string($0.statusValue)]) })
            ])
        }
    }

    func create(kind: WorkspaceEntityKind, fields: [String: WorkspaceValue], requestID: String, idempotencyKey: String, client: String) throws -> WorkspaceEntityDTO {
        if let prior = try idempotentResult(key: idempotencyKey) { return prior }
        let change = MCPChangeSet(toolName: "create_entity", requestID: requestID, idempotencyKey: idempotencyKey, clientName: client)
        context.insert(change)
        do {
            let dto = try insert(kind: kind, fields: fields)
            change.mutations.append(MCPMutation(sequence: 0, entityType: kind.rawValue, entityID: dto.id, action: "create", afterJSON: json(dto), changeSet: change))
            change.resultJSON = json(dto)
            change.completedAt = Date()
            try context.save()
            return dto
        } catch {
            context.rollback()
            throw error
        }
    }

    func update(kind: WorkspaceEntityKind, id: UUID, fields: [String: WorkspaceValue], requestID: String, client: String) throws -> WorkspaceEntityDTO {
        let before = try get(kind: kind, id: id)
        let change = MCPChangeSet(toolName: "update_entity", requestID: requestID, clientName: client)
        context.insert(change)
        do {
            try apply(kind: kind, id: id, fields: fields)
            let after = try get(kind: kind, id: id)
            change.mutations.append(MCPMutation(sequence: 0, entityType: kind.rawValue, entityID: id, action: "update", beforeJSON: json(before), afterJSON: json(after), changeSet: change))
            change.resultJSON = json(after); change.completedAt = Date()
            try context.save()
            return after
        } catch { context.rollback(); throw error }
    }

    func link(sourceKind: WorkspaceEntityKind, sourceID: UUID, targetKind: WorkspaceEntityKind, targetID: UUID, linked: Bool, requestID: String, idempotencyKey: String, client: String) throws -> WorkspaceValue {
        if let prior = try idempotentValue(key: idempotencyKey) { return prior }
        let beforeSource = try get(kind: sourceKind, id: sourceID)
        let change = MCPChangeSet(toolName: linked ? "link_entities" : "unlink_entities", requestID: requestID, idempotencyKey: idempotencyKey, clientName: client)
        context.insert(change)
        do {
            try applyLink(sourceKind:sourceKind,sourceID:sourceID,targetKind:targetKind,targetID:targetID,linked:linked)
            let afterSource = try get(kind: sourceKind, id: sourceID)
            let afterTarget = try get(kind: targetKind, id: targetID)
            change.mutations = [MCPMutation(sequence:0,entityType:sourceKind.rawValue,entityID:sourceID,action:"\(linked ? "link" : "unlink"):\(targetKind.rawValue):\(targetID.uuidString)",beforeJSON:json(beforeSource),afterJSON:json(afterSource),changeSet:change)]
            let result: WorkspaceValue = .object(["source":try encodedValue(afterSource),"target":try encodedValue(afterTarget),"linked":.bool(linked)])
            change.resultJSON=json(result);change.completedAt=Date();try context.save();return result
        } catch { context.rollback(); throw error }
    }

    func createLearningPlan(_ plan: [String: WorkspaceValue], requestID: String, idempotencyKey: String, client: String) throws -> WorkspaceValue {
        if let prior = try idempotentValue(key:idempotencyKey) { return prior }
        guard let domainFields = plan["domain"]?.object else { throw WorkspaceServiceError.validation("plan.domain is required") }
        let change=MCPChangeSet(toolName:"create_learning_plan",requestID:requestID,idempotencyKey:idempotencyKey,clientName:client);context.insert(change)
        do {
            var created:[WorkspaceEntityDTO]=[]
            let domain=try insert(kind:.domain,fields:domainFields);created.append(domain)
            for trackValue in plan["tracks"]?.array ?? [] {
                guard var trackFields=trackValue.object else { throw WorkspaceServiceError.validation("Each track must be an object") }
                let modules=trackFields.removeValue(forKey:"modules")?.array ?? [];trackFields["domain_id"] = .string(domain.id.uuidString)
                let track=try insert(kind:.track,fields:trackFields);created.append(track)
                for moduleValue in modules {
                    guard var moduleFields=moduleValue.object else { throw WorkspaceServiceError.validation("Each module must be an object") }
                    let nodes=moduleFields.removeValue(forKey:"nodes")?.array ?? [];moduleFields["track_id"] = .string(track.id.uuidString)
                    let module=try insert(kind:.module,fields:moduleFields);created.append(module)
                    for nodeValue in nodes { guard var nodeFields=nodeValue.object else { throw WorkspaceServiceError.validation("Each node must be an object") };nodeFields["module_id"] = .string(module.id.uuidString);created.append(try insert(kind:.node,fields:nodeFields)) }
                }
            }
            for projectValue in plan["projects"]?.array ?? [] { guard var fields=projectValue.object else { throw WorkspaceServiceError.validation("Each project must be an object") };fields["domain_id"] = .string(domain.id.uuidString);created.append(try insert(kind:.project,fields:fields)) }
            guard created.count <= 250 else { throw WorkspaceServiceError.validation("Learning plans are limited to 250 entities") }
            change.mutations=created.enumerated().map{MCPMutation(sequence:$0.offset,entityType:$0.element.kind.rawValue,entityID:$0.element.id,action:"create",afterJSON:json($0.element),changeSet:change)}
            let result:WorkspaceValue = .object(["domain_id":.string(domain.id.uuidString),"created":.array(try created.map(encodedValue))]);change.resultJSON=json(result);change.completedAt=Date();try context.save();return result
        } catch { context.rollback();throw error }
    }

    func setDeleted(kind: WorkspaceEntityKind, id: UUID, deleted: Bool, requestID: String, client: String) throws -> WorkspaceEntityDTO {
        let before = try get(kind: kind, id: id)
        let change = MCPChangeSet(toolName: deleted ? "archive_entity" : "restore_entity", requestID: requestID, clientName: client)
        context.insert(change)
        do {
            try setDeletion(kind: kind, id: id, deleted: deleted)
            let after = try get(kind: kind, id: id)
            change.mutations.append(MCPMutation(sequence: 0, entityType: kind.rawValue, entityID: id, action: deleted ? "archive" : "restore", beforeJSON: json(before), afterJSON: json(after), changeSet: change))
            change.resultJSON = json(after); change.completedAt = Date(); try context.save()
            return after
        } catch { context.rollback(); throw error }
    }

    func activity(limit: Int = 50) throws -> [WorkspaceValue] {
        try context.fetch(FetchDescriptor<MCPChangeSet>(sortBy: [SortDescriptor(\MCPChangeSet.createdAt, order: .reverse)])).prefix(min(max(limit, 1), 100)).map {
            .object(["id": .string($0.id.uuidString), "tool": .string($0.toolName), "client": .string($0.clientName), "created_at": .string(ISO8601DateFormatter().string(from: $0.createdAt)), "undone": .bool($0.undoneAt != nil), "mutation_count": .int($0.mutations.count)])
        }
    }

    func undo(changeSetID: UUID, requestID: String, client: String) throws -> WorkspaceValue {
        guard let set = try context.fetch(FetchDescriptor<MCPChangeSet>()).first(where: { $0.id == changeSetID }) else { throw WorkspaceServiceError.notFound("Change set not found") }
        guard set.undoneAt == nil else { throw WorkspaceServiceError.conflict("Change set was already undone") }
        for mutation in set.mutations.sorted(by: { $0.sequence > $1.sequence }) {
            guard let kind = WorkspaceEntityKind(rawValue: mutation.entityType) else { continue }
            if let after=mutation.afterJSON,let expected=decodeDTO(after) {
                let current=try get(kind:kind,id:mutation.entityID)
                guard current == expected else { throw WorkspaceServiceError.conflict("Cannot undo because \(kind.rawValue) \(mutation.entityID) changed after this agent call") }
            }
            if mutation.action == "create" { try setDeletion(kind: kind, id: mutation.entityID, deleted: true) }
            else if mutation.action.hasPrefix("link:") || mutation.action.hasPrefix("unlink:") {
                let parts=mutation.action.split(separator:":",maxSplits:2).map(String.init)
                guard parts.count==3,let targetKind=WorkspaceEntityKind(rawValue:parts[1]),let targetID=UUID(uuidString:parts[2]) else{throw WorkspaceServiceError.internalFailure("Invalid relationship audit record")}
                try applyLink(sourceKind:kind,sourceID:mutation.entityID,targetKind:targetKind,targetID:targetID,linked:parts[0]=="unlink")
            }
            else if let before = mutation.beforeJSON, let dto=decodeDTO(before) {
                try apply(kind: kind, id: mutation.entityID, fields: dto.fields)
                try setDeletion(kind: kind, id: mutation.entityID, deleted: dto.deleted)
            }
        }
        set.undoneAt = Date(); try context.save()
        return .object(["change_set_id": .string(set.id.uuidString), "undone": .bool(true)])
    }

    // MARK: - Persistence mapping

    private func insert(kind: WorkspaceEntityKind, fields: [String: WorkspaceValue]) throws -> WorkspaceEntityDTO {
        let id = (try fields.uuid("id")) ?? UUID()
        switch kind {
        case .domain:
            context.insert(Domain(id: id, title: try fields.requiredString("title", max: 500), desc: fields["description"]?.string ?? "", colorHex: fields["color_hex"]?.string ?? "#000000", iconName: fields["icon_name"]?.string ?? DomainIcon.book.rawValue, sortIndex: fields["sort_index"]?.int ?? 0))
        case .track:
            let parent = try require(Domain.self, id: try fields.uuid("domain_id"), label: "domain_id")
            context.insert(Track(id: id, title: try fields.requiredString("title", max: 500), desc: fields["description"]?.string ?? "", sortIndex: fields["sort_index"]?.int ?? 0, domain: parent))
        case .module:
            let track = try optional(Track.self, id: try fields.uuid("track_id")); let domain = try optional(Domain.self, id: try fields.uuid("domain_id"))
            guard (track != nil) != (domain != nil) else { throw WorkspaceServiceError.validation("Provide exactly one of track_id or domain_id") }
            context.insert(Module(id: id, title: try fields.requiredString("title", max: 500), desc: fields["description"]?.string ?? "", sortIndex: fields["sort_index"]?.int ?? 0, track: track, domain: domain))
        case .project:
            context.insert(Project(id: id, title: try fields.requiredString("title", max: 500), desc: fields["description"]?.string ?? "", status: ProjectStatus(rawValue: fields["status"]?.string ?? "") ?? .backlog, isPinned: fields["pinned"]?.bool ?? false, domain: try optional(Domain.self, id: try fields.uuid("domain_id")), track: try optional(Track.self, id: try fields.uuid("track_id"))))
        case .node:
            context.insert(Node(id: id, title: try fields.requiredString("title", max: 500), desc: fields["description"]?.string ?? "", sortIndex: fields["sort_index"]?.int ?? 0, status: NodeStatus(rawValue: fields["status"]?.string ?? "") ?? .backlog, priority: NodePriority(rawValue: fields["priority"]?.string ?? "") ?? .normal, isOrphan: fields["orphan"]?.bool ?? false, captureIntent: CaptureIntent(rawValue: fields["capture_intent"]?.string ?? "") ?? .learningNode, module: try optional(Module.self, id: try fields.uuid("module_id")), project: try optional(Project.self, id: try fields.uuid("project_id"))))
        case .resource:
            context.insert(Resource(id: id, title: try fields.requiredString("title", max: 500), bodyText: fields["body"]?.string ?? "", urlString: fields["url"]?.string ?? "", resourceType: ResourceType(rawValue: fields["resource_type"]?.string ?? "") ?? .note, domain: try optional(Domain.self, id: try fields.uuid("domain_id"))))
        case .tag: context.insert(LibraryTag(id: id, name: try fields.requiredString("name", max: 100)))
        case .readingGroup: context.insert(ReadingListGroup(id: id, title: try fields.requiredString("title", max: 500), sortIndex: fields["sort_index"]?.int ?? 0))
        case .readingItem:
            context.insert(ReadingListItem(id: id, title: try fields.requiredString("title", max: 500), author: fields["author"]?.string ?? "", notes: fields["notes"]?.string ?? "", urlString: fields["url"]?.string ?? "", status: ReadingStatus(rawValue: fields["status"]?.string ?? "") ?? .queue, priority: ReadingPriority(rawValue: fields["priority"]?.string ?? "") ?? .normal, stoppedAtVolume: fields["volume"]?.string ?? "", stoppedAtPage: fields["page"]?.string ?? "", sortIndex: fields["sort_index"]?.int ?? 0, domain: try optional(Domain.self, id: try fields.uuid("domain_id")), module: try optional(Module.self, id: try fields.uuid("module_id")), group: try optional(ReadingListGroup.self, id: try fields.uuid("group_id"))))
        case .plannerBlock:
            let weekday = fields["weekday"]?.int ?? 0; guard (1...7).contains(weekday) else { throw WorkspaceServiceError.validation("weekday must be 1...7") }
            let start=fields["start_minute"]?.int ?? 0,end=fields["end_minute"]?.int ?? 60;guard (0..<1440).contains(start),(1...1440).contains(end),end>start else{throw WorkspaceServiceError.validation("Planner times must satisfy 0 <= start_minute < end_minute <= 1440")}
            let block=PlannerWeeklyBlock(id:id,title:try fields.requiredString("title",max:500),notes:fields["notes"]?.string ?? "",kind:PlannerBlockKind(rawValue:fields["kind"]?.string ?? "") ?? .study,weekday:weekday,startMinute:start,endMinute:end,sortIndex:fields["sort_index"]?.int ?? 0)
            if let raw=fields["target_kind"]?.string { guard let target=PlannerTargetKind(rawValue:raw) else{throw WorkspaceServiceError.validation("target_kind is invalid")};block.targetKind=target;switch target{case .domain:block.linkedDomainID=try require(Domain.self,id:try fields.uuid("target_id"),label:"target_id").id;case .project:block.linkedProjectID=try require(Project.self,id:try fields.uuid("target_id"),label:"target_id").id;case .reading:block.linkedReadingItemID=try require(ReadingListItem.self,id:try fields.uuid("target_id"),label:"target_id").id;case .library:block.linkedResourceID=try require(Resource.self,id:try fields.uuid("target_id"),label:"target_id").id}}
            context.insert(block)
        case .plannerEvent:
            let start = try date(fields, "start_date"), end = try date(fields, "end_date"); guard end > start else { throw WorkspaceServiceError.validation("end_date must be after start_date") }
            context.insert(PlannerEvent(id: id, title: try fields.requiredString("title", max: 500), notes: fields["notes"]?.string ?? "", kind: PlannerBlockKind(rawValue: fields["kind"]?.string ?? "") ?? .other, startDate: start, endDate: end))
        case .dayNote: context.insert(PlannerDayNote(id: id, dayKey: try fields.requiredString("day_key", max: 10), text: fields["text"]?.string ?? ""))
        case .attachment:
            let resource = try require(Resource.self, id: try fields.uuid("resource_id"), label: "resource_id")
            context.insert(LibraryAttachment(id: id, displayName: try fields.requiredString("display_name", max: 500), storedPath: try fields.requiredString("stored_path"), storageKind: fields["storage_kind"]?.string ?? "workspace", contentType: fields["content_type"]?.string ?? "application/octet-stream", byteSize: Int64(fields["byte_size"]?.int ?? 0), resource: resource))
        case .devCapture:
            context.insert(DevCapture(id: id, title: try fields.requiredString("title", max: 500), bodyText: fields["body"]?.string ?? "", kind: DevCaptureKind(rawValue: fields["kind"]?.string ?? "") ?? .improvement, assignee: DevCaptureAssignee(rawValue: fields["assignee"]?.string ?? "") ?? .codex, contextSummary: fields["context_summary"]?.string ?? "", contextSection: fields["context_section"]?.string ?? "MCP"))
        }
        return try get(kind: kind, id: id)
    }

    private func apply(kind: WorkspaceEntityKind, id: UUID, fields: [String: WorkspaceValue]) throws {
        switch kind {
        case .domain: let v = try require(Domain.self, id: id); if let x = fields["title"]?.string { v.title=x }; if let x=fields["description"]?.string {v.desc=x}; if let x=fields["sort_index"]?.int {v.sortIndex=x}; if let x=fields["archived"]?.bool {v.isArchived=x}; touch(v)
        case .track: let v=try require(Track.self,id:id); if let x=fields["title"]?.string{v.title=x}; if let x=fields["description"]?.string{v.desc=x}; if let x=fields["sort_index"]?.int{v.sortIndex=x}; if fields["domain_id"] != nil {v.domain=try optional(Domain.self,id:try fields.uuid("domain_id"))}; touch(v)
        case .module: let v=try require(Module.self,id:id); if let x=fields["title"]?.string{v.title=x}; if let x=fields["description"]?.string{v.desc=x}; if let x=fields["sort_index"]?.int{v.sortIndex=x}; if fields["track_id"] != nil {v.track=try optional(Track.self,id:try fields.uuid("track_id"));v.domain=nil}; if fields["domain_id"] != nil {v.domain=try optional(Domain.self,id:try fields.uuid("domain_id"));v.track=nil}; guard (v.track != nil) != (v.domain != nil) else {throw WorkspaceServiceError.validation("Module must have exactly one parent")}; touch(v)
        case .project: let v=try require(Project.self,id:id); if let x=fields["title"]?.string{v.title=x}; if let x=fields["description"]?.string{v.desc=x}; if let x=fields["status"]?.string, let e=ProjectStatus(rawValue:x){v.status=e}; if let x=fields["pinned"]?.bool{v.isPinned=x}; if fields["domain_id"] != nil {v.domain=try optional(Domain.self,id:try fields.uuid("domain_id"))}; if fields["track_id"] != nil {v.track=try optional(Track.self,id:try fields.uuid("track_id"))}; touch(v)
        case .node: let v=try require(Node.self,id:id); if let x=fields["title"]?.string{v.title=x}; if let x=fields["description"]?.string{v.desc=x}; if let x=fields["status"]?.string,let e=NodeStatus(rawValue:x){v.status=e}; if let x=fields["priority"]?.string,let e=NodePriority(rawValue:x){v.priority=e}; if let x=fields["pinned"]?.bool{v.isPinned=x}; if let x=fields["sort_index"]?.int{v.sortIndex=x}; if fields["module_id"] != nil {v.module=try optional(Module.self,id:try fields.uuid("module_id"))}; if fields["project_id"] != nil {v.project=try optional(Project.self,id:try fields.uuid("project_id"))}; touch(v)
        case .resource: let v=try require(Resource.self,id:id); if let x=fields["title"]?.string{v.title=x}; if let x=fields["body"]?.string{v.bodyText=x}; if let x=fields["url"]?.string{v.urlString=x}; if let x=fields["pinned"]?.bool{v.isPinned=x}; if let x=fields["status"]?.string,let e=LibraryStatus(rawValue:x){v.libraryStatus=e}; touch(v)
        case .tag: let v=try require(LibraryTag.self,id:id); if let x=fields["name"]?.string{v.name=x}
        case .readingGroup: let v=try require(ReadingListGroup.self,id:id); if let x=fields["title"]?.string{v.title=x}; if let x=fields["sort_index"]?.int{v.sortIndex=x}
        case .readingItem: let v=try require(ReadingListItem.self,id:id); if let x=fields["title"]?.string{v.title=x}; if let x=fields["author"]?.string{v.author=x}; if let x=fields["notes"]?.string{v.notes=x}; if let x=fields["status"]?.string,let e=ReadingStatus(rawValue:x){v.status=e}; if let x=fields["priority"]?.string,let e=ReadingPriority(rawValue:x){v.priority=e}; touch(v)
        case .plannerBlock: let v=try require(PlannerWeeklyBlock.self,id:id); if let x=fields["title"]?.string{v.title=x}; if let x=fields["notes"]?.string{v.notes=x}; if let x=fields["weekday"]?.int,(1...7).contains(x){v.weekday=x}; if let x=fields["duration_minutes"]?.int{v.durationMinutes=max(15,x)}; v.updatedAt=Date()
        case .plannerEvent: let v=try require(PlannerEvent.self,id:id); if let x=fields["title"]?.string{v.title=x}; if let x=fields["notes"]?.string{v.notes=x}; v.updatedAt=Date()
        case .dayNote: let v=try require(PlannerDayNote.self,id:id); if let x=fields["text"]?.string{v.text=x}; v.updatedAt=Date()
        case .attachment: let v=try require(LibraryAttachment.self,id:id); if let x=fields["display_name"]?.string{v.displayName=x}
        case .devCapture: let v=try require(DevCapture.self,id:id); if let x=fields["title"]?.string{v.title=x}; if let x=fields["body"]?.string{v.bodyText=x}; if let x=fields["assignee"]?.string,let e=DevCaptureAssignee(rawValue:x){v.assignee=e}; touch(v)
        }
    }

    private func allEntities(includeDeleted: Bool) throws -> [WorkspaceEntityDTO] {
        var out: [WorkspaceEntityDTO] = []
        out += try context.fetch(FetchDescriptor<Domain>()).map(dto)
        out += try context.fetch(FetchDescriptor<Track>()).map(dto)
        out += try context.fetch(FetchDescriptor<Module>()).map(dto)
        out += try context.fetch(FetchDescriptor<Project>()).map(dto)
        out += try context.fetch(FetchDescriptor<Node>()).map(dto)
        out += try context.fetch(FetchDescriptor<Resource>()).map(dto)
        out += try context.fetch(FetchDescriptor<LibraryTag>()).map(dto)
        out += try context.fetch(FetchDescriptor<ReadingListGroup>()).map(dto)
        out += try context.fetch(FetchDescriptor<ReadingListItem>()).map(dto)
        out += try context.fetch(FetchDescriptor<PlannerWeeklyBlock>()).map(dto)
        out += try context.fetch(FetchDescriptor<PlannerEvent>()).map(dto)
        out += try context.fetch(FetchDescriptor<PlannerDayNote>()).map(dto)
        out += try context.fetch(FetchDescriptor<LibraryAttachment>()).map(dto)
        out += try context.fetch(FetchDescriptor<DevCapture>()).map(dto)
        return includeDeleted ? out : out.filter { !$0.deleted }
    }

    private func dto(_ v: Domain)->WorkspaceEntityDTO { entity(v.id,.domain,v.title,["description":.string(v.desc),"color_hex":.string(v.colorHex),"icon_name":.string(v.iconName),"sort_index":.int(v.sortIndex),"archived":.bool(v.isArchived)],[:],v.isDeletedLocally,v.createdAt,v.updatedAt) }
    private func dto(_ v: Track)->WorkspaceEntityDTO { entity(v.id,.track,v.title,["description":.string(v.desc),"sort_index":.int(v.sortIndex)],["domain":ids(v.domain)],v.isDeletedLocally,v.createdAt,v.updatedAt) }
    private func dto(_ v: Module)->WorkspaceEntityDTO { entity(v.id,.module,v.title,["description":.string(v.desc),"sort_index":.int(v.sortIndex)],["track":ids(v.track),"domain":ids(v.domain)],v.isDeletedLocally,v.createdAt,v.updatedAt) }
    private func dto(_ v: Project)->WorkspaceEntityDTO { entity(v.id,.project,v.title,["description":.string(v.desc),"status":.string(v.statusValue),"pinned":.bool(v.isPinned)],["domain":ids(v.domain),"track":ids(v.track),"nodes":v.nodes.map(\.id),"resources":v.resources.map(\.id)],v.isDeletedLocally,v.createdAt,v.updatedAt) }
    private func dto(_ v: Node)->WorkspaceEntityDTO { entity(v.id,.node,v.title,["description":.string(v.desc),"status":.string(v.statusValue),"priority":.string(v.priorityValue),"sort_index":.int(v.sortIndex),"pinned":.bool(v.isPinned)],["module":ids(v.module),"project":ids(v.project),"resources":v.resources.map(\.id)],v.isDeletedLocally,v.createdAt,v.updatedAt) }
    private func dto(_ v: Resource)->WorkspaceEntityDTO { entity(v.id,.resource,v.title,["body":.string(v.bodyText),"url":.string(v.urlString),"resource_type":.string(v.resourceTypeValue),"status":.string(v.statusValue),"pinned":.bool(v.isPinned)],["domain":ids(v.domain),"nodes":v.nodes.map(\.id),"projects":v.projects.map(\.id),"tags":v.tags.map(\.id)],v.isDeletedLocally,v.createdAt,v.updatedAt) }
    private func dto(_ v: LibraryTag)->WorkspaceEntityDTO { entity(v.id,.tag,v.name,["name":.string(v.name)],[:],v.isDeletedLocally,v.createdAt,nil) }
    private func dto(_ v: ReadingListGroup)->WorkspaceEntityDTO { entity(v.id,.readingGroup,v.title,["sort_index":.int(v.sortIndex)],["items":v.items.map(\.id)],v.isDeletedLocally,v.createdAt,nil) }
    private func dto(_ v: ReadingListItem)->WorkspaceEntityDTO { entity(v.id,.readingItem,v.title,["author":.string(v.author),"notes":.string(v.notes),"url":.string(v.urlString),"status":.string(v.statusValue),"priority":.string(v.priorityValue),"volume":.string(v.stoppedAtVolume),"page":.string(v.stoppedAtPage)],["domain":ids(v.domain),"module":ids(v.module),"group":ids(v.group),"tags":v.tags.map(\.id)],v.isDeletedLocally,v.createdAt,v.updatedAt) }
    private func dto(_ v: PlannerWeeklyBlock)->WorkspaceEntityDTO { entity(v.id,.plannerBlock,v.title,["notes":.string(v.notes),"kind":.string(v.kindValue),"weekday":.int(v.weekday),"duration_minutes":.int(v.durationMinutes),"sort_index":.int(v.sortIndex)],[:],v.isDeletedLocally,v.createdAt,v.updatedAt) }
    private func dto(_ v: PlannerEvent)->WorkspaceEntityDTO { entity(v.id,.plannerEvent,v.title,["notes":.string(v.notes),"kind":.string(v.kindValue),"start_date":.string(iso(v.startDate)),"end_date":.string(iso(v.endDate))],[:],v.isDeletedLocally,v.createdAt,v.updatedAt) }
    private func dto(_ v: PlannerDayNote)->WorkspaceEntityDTO { entity(v.id,.dayNote,v.dayKey,["day_key":.string(v.dayKey),"text":.string(v.text)],[:],v.isDeletedLocally,nil,v.updatedAt) }
    private func dto(_ v: LibraryAttachment)->WorkspaceEntityDTO { entity(v.id,.attachment,v.displayName,["display_name":.string(v.displayName),"stored_path":.string(v.storedPath),"storage_kind":.string(v.storageKind),"content_type":.string(v.contentType),"byte_size":.int(Int(v.byteSize ?? 0))],["resource":ids(v.resource)],v.isDeletedLocally,v.createdAt,nil) }
    private func dto(_ v: DevCapture)->WorkspaceEntityDTO { entity(v.id,.devCapture,v.title,["body":.string(v.bodyText),"kind":.string(v.kindValue),"assignee":.string(v.assigneeValue),"context_summary":.string(v.contextSummary),"context_section":.string(v.contextSection)],[:],v.isDeletedLocally,v.createdAt,v.updatedAt) }

    private func entity(_ id:UUID,_ kind:WorkspaceEntityKind,_ title:String,_ fields:[String:WorkspaceValue],_ rel:[String:[UUID]],_ deleted:Bool,_ created:Date?,_ updated:Date?)->WorkspaceEntityDTO { WorkspaceEntityDTO(id:id,kind:kind,title:title,fields:fields,relationships:rel,deleted:deleted,createdAt:created,updatedAt:updated) }
    private func ids<T: Identifiable>(_ value:T?)->[UUID] where T.ID==UUID { value.map { [$0.id] } ?? [] }
    private func iso(_ d:Date)->String { ISO8601DateFormatter().string(from:d) }
    private func date(_ f:[String:WorkspaceValue],_ key:String)throws->Date { guard let s=f[key]?.string,let d=ISO8601DateFormatter().date(from:s) else{throw WorkspaceServiceError.validation("\(key) must be ISO-8601")};return d }
    private func searchableText(_ d:WorkspaceEntityDTO)->String { ([d.title] + d.fields.values.compactMap(\.string)).joined(separator:" ").lowercased() }
    private func json<T:Encodable>(_ v:T)->String { (try? encoder.encode(v)).flatMap { String(data:$0,encoding:.utf8) } ?? "{}" }
    private func decodeDTO(_ json:String)->WorkspaceEntityDTO? { guard let data=json.data(using:.utf8) else{return nil};let decoder=JSONDecoder();decoder.dateDecodingStrategy = .iso8601;return try? decoder.decode(WorkspaceEntityDTO.self,from:data) }
    private func encodedValue<T:Encodable>(_ value:T)throws->WorkspaceValue { try JSONDecoder().decode(WorkspaceValue.self,from:encoder.encode(value)) }
    private func idempotentValue(key:String)throws->WorkspaceValue? { guard let c=try context.fetch(FetchDescriptor<MCPChangeSet>()).first(where:{$0.idempotencyKey==key}),let d=c.resultJSON.data(using:.utf8) else{return nil};return try? JSONDecoder().decode(WorkspaceValue.self,from:d) }
    private func idempotentResult(key:String)throws->WorkspaceEntityDTO? { guard let c=try context.fetch(FetchDescriptor<MCPChangeSet>()).first(where:{$0.idempotencyKey==key}),let d=c.resultJSON.data(using:.utf8) else{return nil};let decoder=JSONDecoder();decoder.dateDecodingStrategy = .iso8601;return try? decoder.decode(WorkspaceEntityDTO.self,from:d) }

    private func require<T:PersistentModel>(_ type:T.Type,id:UUID?,label:String="id")throws->T { guard let id else{throw WorkspaceServiceError.validation("Missing \(label)")};return try require(type,id:id) }
    private func require<T:PersistentModel>(_ type:T.Type,id:UUID)throws->T { guard let item=try context.fetch(FetchDescriptor<T>()).first(where:{ ($0 as? any Identifiable)?.id as? UUID == id }) else{throw WorkspaceServiceError.notFound("\(String(describing:type)) \(id) not found")};return item }
    private func optional<T:PersistentModel>(_ type:T.Type,id:UUID?)throws->T? { guard let id else{return nil};return try require(type,id:id) }
    private func setMembership<T:Identifiable>(_ item:T,in values:inout [T],linked:Bool) where T.ID==UUID { if linked {if !values.contains(where:{$0.id==item.id}){values.append(item)}} else {values.removeAll{$0.id==item.id}} }
    private func applyLink(sourceKind:WorkspaceEntityKind,sourceID:UUID,targetKind:WorkspaceEntityKind,targetID:UUID,linked:Bool)throws { switch (sourceKind,targetKind) { case (.node,.project):try setMembership(try require(Node.self,id:sourceID),in:&require(Project.self,id:targetID).nodes,linked:linked);case (.resource,.node):try setMembership(try require(Resource.self,id:sourceID),in:&require(Node.self,id:targetID).resources,linked:linked);case (.resource,.project):try setMembership(try require(Resource.self,id:sourceID),in:&require(Project.self,id:targetID).resources,linked:linked);case (.tag,.resource):try setMembership(try require(LibraryTag.self,id:sourceID),in:&require(Resource.self,id:targetID).tags,linked:linked);case (.tag,.readingItem):try setMembership(try require(LibraryTag.self,id:sourceID),in:&require(ReadingListItem.self,id:targetID).tags,linked:linked);case (.resource,.readingItem):try setMembership(try require(Resource.self,id:sourceID),in:&require(ReadingListItem.self,id:targetID).linkedResources,linked:linked);default:throw WorkspaceServiceError.validation("Unsupported relationship \(sourceKind.rawValue) -> \(targetKind.rawValue)")} }

    private func setDeletion(kind:WorkspaceEntityKind,id:UUID,deleted:Bool)throws {
        switch kind {
        case .domain: try require(Domain.self,id:id).isDeletedLocally=deleted
        case .track: try require(Track.self,id:id).isDeletedLocally=deleted
        case .module: try require(Module.self,id:id).isDeletedLocally=deleted
        case .project: try require(Project.self,id:id).isDeletedLocally=deleted
        case .node: try require(Node.self,id:id).isDeletedLocally=deleted
        case .resource: try require(Resource.self,id:id).isDeletedLocally=deleted
        case .readingItem: try require(ReadingListItem.self,id:id).isDeletedLocally=deleted
        case .plannerEvent: try require(PlannerEvent.self,id:id).isDeletedLocally=deleted
        case .devCapture: try require(DevCapture.self,id:id).isDeletedLocally=deleted
        case .tag: try require(LibraryTag.self,id:id).isDeletedLocally=deleted
        case .readingGroup: try require(ReadingListGroup.self,id:id).isDeletedLocally=deleted
        case .plannerBlock: try require(PlannerWeeklyBlock.self,id:id).isDeletedLocally=deleted
        case .dayNote: try require(PlannerDayNote.self,id:id).isDeletedLocally=deleted
        case .attachment: try require(LibraryAttachment.self,id:id).isDeletedLocally=deleted
        }
    }

    private func touch(_ v:Domain){v.updatedAt=Date();v.isSynced=false}; private func touch(_ v:Track){v.updatedAt=Date();v.isSynced=false}; private func touch(_ v:Module){v.updatedAt=Date();v.isSynced=false}; private func touch(_ v:Project){v.updatedAt=Date();v.isSynced=false}; private func touch(_ v:Node){v.updatedAt=Date();v.isSynced=false}; private func touch(_ v:Resource){v.updatedAt=Date();v.isSynced=false}; private func touch(_ v:ReadingListItem){v.updatedAt=Date();v.isSynced=false}; private func touch(_ v:DevCapture){v.updatedAt=Date();v.isSynced=false}
}

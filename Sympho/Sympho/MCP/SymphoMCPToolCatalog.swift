#if os(macOS)
import Foundation
import MCP
import SwiftData

enum SymphoMCPToolCatalog {
    static let readNames: Set<String> = ["get_workspace_schema","search_workspace","list_entities","get_entity","get_learning_outline","get_planner","get_agent_activity","read_attachment"]

    static var tools: [Tool] {
        [
            tool("get_workspace_schema", "Describe supported entity kinds, editable fields, enums, and relationships. Call before unfamiliar writes.", properties:[:], read:true),
            tool("search_workspace", "Search all Sympho content. Use this first to resolve names to UUIDs.", properties: ["query":string(),"kinds":array(string()),"offset":integer(),"limit":integer()], read: true),
            tool("list_entities", "List one entity kind with pagination.", properties: ["kind":kind(),"include_deleted":boolean(),"offset":integer(),"limit":integer()], required:["kind"], read:true),
            tool("get_entity", "Get canonical detail for one entity UUID.", properties:["kind":kind(),"id":uuid()], required:["kind","id"], read:true),
            tool("get_learning_outline", "Get the Domain to Track to Module to Node hierarchy and projects.", properties:[:], read:true),
            tool("get_planner", "Get weekly blocks, events and day notes.", properties:[:], read:true),
            tool("get_agent_activity", "List recent MCP changes and undo availability.", properties:["limit":integer()], read:true),
            tool("create_entity", "Create any Sympho entity. Supply kind, kind-specific fields, and a unique idempotency_key.", properties:["kind":kind(),"fields":object(),"idempotency_key":string()], required:["kind","fields","idempotency_key"], idempotent:true),
            tool("create_learning_plan", "Atomically create a domain with nested tracks, modules, nodes, and projects.", properties:["plan":object(),"idempotency_key":string()], required:["plan","idempotency_key"], idempotent:true),
            tool("update_entity", "Update editable fields of an existing entity.", properties:["kind":kind(),"id":uuid(),"fields":object()], required:["kind","id","fields"]),
            tool("link_entities", "Create a supported relationship between two entities.", properties:["source_kind":kind(),"source_id":uuid(),"target_kind":kind(),"target_id":uuid(),"idempotency_key":string()], required:["source_kind","source_id","target_kind","target_id","idempotency_key"], idempotent:true),
            tool("unlink_entities", "Remove a supported relationship between two entities.", properties:["source_kind":kind(),"source_id":uuid(),"target_kind":kind(),"target_id":uuid(),"idempotency_key":string()], required:["source_kind","source_id","target_kind","target_id","idempotency_key"], idempotent:true),
            tool("archive_entity", "Reversibly soft-delete any supported entity.", properties:["kind":kind(),"id":uuid()], required:["kind","id"], destructive:true, idempotent:true),
            tool("restore_entity", "Restore a soft-deleted entity.", properties:["kind":kind(),"id":uuid()], required:["kind","id"], idempotent:true),
            tool("undo_agent_change", "Undo one MCP change set if no later edit conflicts.", properties:["change_set_id":uuid()], required:["change_set_id"], destructive:true, idempotent:true),
            tool("import_file", "Import a file from a user-approved folder into a resource.", properties:["path":string(),"resource_id":uuid()], required:["path","resource_id"]),
            tool("read_attachment", "Read UTF-8 text from an attachment in an approved folder, bounded to 100000 characters.", properties:["attachment_id":uuid()], required:["attachment_id"], read:true, openWorld:true),
        ]
    }

    static func install(on server: Server, service: SymphoWorkspaceService, settings: LocalMCPSettings, clientName: @escaping @Sendable () async -> String) async {
        await server.withMethodHandler(ListTools.self) { _ in .init(tools: tools) }
        await server.withMethodHandler(CallTool.self) { params in
            let requestID = UUID().uuidString
            do {
                if settings.readOnly && !readNames.contains(params.name) { throw WorkspaceServiceError.forbidden("Sympho MCP is in read-only mode") }
                let arguments = try workspaceArguments(params.arguments ?? [:])
                let client = await clientName()
                let result: WorkspaceValue = try await MainActor.run {
                    settings.lastCall = params.name
                    return try execute(name: params.name, args: arguments, requestID: requestID, client: client, service: service, settings: settings)
                }
                return try CallTool.Result(content:[.text(text:"Success",annotations:nil,_meta:nil)], structuredContent: result, isError:false)
            } catch {
                let code = (error as? WorkspaceServiceError)?.code ?? "internal"
                let payload: WorkspaceValue = .object(["error":.string(code),"message":.string(error.localizedDescription),"request_id":.string(requestID)])
                return try CallTool.Result(content:[.text(text:error.localizedDescription,annotations:nil,_meta:nil)], structuredContent: payload, isError:true)
            }
        }
    }

    @MainActor private static func execute(name:String,args:[String:WorkspaceValue],requestID:String,client:String,service:SymphoWorkspaceService,settings:LocalMCPSettings)throws->WorkspaceValue {
        switch name {
        case "get_workspace_schema": return schemaCatalog
        case "search_workspace":
            let kinds = Set((args["kinds"]?.array ?? []).compactMap { $0.string }.compactMap(WorkspaceEntityKind.init(rawValue:)))
            return try value(service.search(query:args["query"]?.string ?? "",kinds:kinds,offset:args["offset"]?.int ?? 0,limit:args["limit"]?.int ?? 50))
        case "list_entities": return try value(service.list(kind:try entityKind(args),includeDeleted:args["include_deleted"]?.bool ?? false,offset:args["offset"]?.int ?? 0,limit:args["limit"]?.int ?? 100))
        case "get_entity": return try value(service.get(kind:try entityKind(args),id:try id(args,"id")))
        case "get_learning_outline": return .array(try service.learningOutline())
        case "get_planner":
            return .object(["weekly_blocks":try value(service.list(kind:.plannerBlock).items),"events":try value(service.list(kind:.plannerEvent).items),"day_notes":try value(service.list(kind:.dayNote).items)])
        case "get_agent_activity": return .array(try service.activity(limit:args["limit"]?.int ?? 50))
        case "create_entity": return try value(service.create(kind:try entityKind(args),fields:args["fields"]?.object ?? [:],requestID:requestID,idempotencyKey:try args.requiredString("idempotency_key",max:500),client:client))
        case "create_learning_plan": return try service.createLearningPlan(args["plan"]?.object ?? [:],requestID:requestID,idempotencyKey:try args.requiredString("idempotency_key",max:500),client:client)
        case "update_entity": return try value(service.update(kind:try entityKind(args),id:try id(args,"id"),fields:args["fields"]?.object ?? [:],requestID:requestID,client:client))
        case "link_entities", "unlink_entities": return try service.link(sourceKind:try entityKind(args,key:"source_kind"),sourceID:try id(args,"source_id"),targetKind:try entityKind(args,key:"target_kind"),targetID:try id(args,"target_id"),linked:name=="link_entities",requestID:requestID,idempotencyKey:try args.requiredString("idempotency_key",max:500),client:client)
        case "archive_entity": return try value(service.setDeleted(kind:try entityKind(args),id:try id(args,"id"),deleted:true,requestID:requestID,client:client))
        case "restore_entity": return try value(service.setDeleted(kind:try entityKind(args),id:try id(args,"id"),deleted:false,requestID:requestID,client:client))
        case "undo_agent_change": return try service.undo(changeSetID:try id(args,"change_set_id"),requestID:requestID,client:client)
        case "import_file": return try importFile(args:args,requestID:requestID,client:client,service:service,settings:settings)
        case "read_attachment": return try readAttachment(args:args,service:service,settings:settings)
        default: throw WorkspaceServiceError.validation("Unknown tool: \(name)")
        }
    }

    @MainActor private static func importFile(args:[String:WorkspaceValue],requestID:String,client:String,service:SymphoWorkspaceService,settings:LocalMCPSettings)throws->WorkspaceValue {
        let requested = URL(fileURLWithPath:try args.requiredString("path"))
        let resourceID = try id(args,"resource_id")
        let resource = try service.context.fetch(FetchDescriptor<Resource>()).first(where:{$0.id==resourceID})
        guard let resource else { throw WorkspaceServiceError.notFound("Resource not found") }
        let imported = try settings.withApprovedFileAccess(requested) { try LibraryStorage.importFile(from:$0,entryID:resource.id,entryTitle:resource.title) }
        let fields:[String:WorkspaceValue] = ["display_name":.string(imported.displayName),"stored_path":.string(imported.storedPath),"storage_kind":.string(imported.storageKind),"content_type":.string(imported.contentType),"byte_size":.int(Int(imported.byteSize ?? 0)),"resource_id":.string(resource.id.uuidString)]
        return try value(service.create(kind:.attachment,fields:fields,requestID:requestID,idempotencyKey:"import:\(imported.sha256 ?? imported.id.uuidString)",client:client))
    }

    @MainActor private static func readAttachment(args:[String:WorkspaceValue],service:SymphoWorkspaceService,settings:LocalMCPSettings)throws->WorkspaceValue {
        let attachment = try service.context.fetch(FetchDescriptor<LibraryAttachment>()).first(where:{$0.id == (try? id(args,"attachment_id"))})
        guard let attachment, let url=LibraryStorage.resolvedURL(for:attachment) else { throw WorkspaceServiceError.notFound("Attachment not found") }
        let data = attachment.storageKind == "internal" ? try Data(contentsOf:url,options:.mappedIfSafe) : try settings.withApprovedFileAccess(url) { try Data(contentsOf:$0,options:.mappedIfSafe) }
        guard data.count <= 2_000_000, let text=String(data:data,encoding:.utf8) else { throw WorkspaceServiceError.validation("Attachment is not bounded UTF-8 text") }
        return .object(["attachment_id":.string(attachment.id.uuidString),"text":.string(String(text.prefix(100_000))),"truncated":.bool(text.count>100_000)])
    }

    private static func workspaceArguments(_ values:[String:Value])throws->[String:WorkspaceValue] { let data=try JSONEncoder().encode(values); return try JSONDecoder().decode([String:WorkspaceValue].self,from:data) }
    private static func value<T:Codable>(_ value:T)throws->WorkspaceValue { let data=try JSONEncoder().encode(value); return try JSONDecoder().decode(WorkspaceValue.self,from:data) }
    private static func entityKind(_ args:[String:WorkspaceValue],key:String="kind")throws->WorkspaceEntityKind { guard let raw=args[key]?.string,let kind=WorkspaceEntityKind(rawValue:raw) else{throw WorkspaceServiceError.validation("\(key) is invalid")};return kind }
    private static func id(_ args:[String:WorkspaceValue],_ key:String)throws->UUID { guard let raw=args[key]?.string,let value=UUID(uuidString:raw) else{throw WorkspaceServiceError.validation("\(key) must be a UUID")};return value }

    private static func tool(_ name:String,_ description:String,properties:[String:Value],required:[String]=[],read:Bool=false,destructive:Bool=false,idempotent:Bool=false,openWorld:Bool=false)->Tool {
        Tool(name:name,title:nil,description:description,inputSchema:.object(["type":"object","properties":.object(properties),"required":.array(required.map(Value.string)),"additionalProperties":false]),annotations:.init(readOnlyHint:read,destructiveHint:destructive,idempotentHint:idempotent,openWorldHint:openWorld))
    }
    private static func string()->Value { ["type":"string"] }; private static func integer()->Value {["type":"integer"]}; private static func boolean()->Value{["type":"boolean"]}; private static func uuid()->Value{["type":"string","format":"uuid"]}; private static func object()->Value{["type":"object","additionalProperties":true]}; private static func array(_ item:Value)->Value{["type":"array","items":item]}
    private static func kind()->Value { ["type":"string","enum":.array(WorkspaceEntityKind.allCases.map{.string($0.rawValue)})] }
    private static var schemaCatalog:WorkspaceValue { .object([
        "limits":.object(["page_size":.int(100),"text_characters":.int(20_000),"learning_plan_entities":.int(250),"attachment_read_bytes":.int(2_000_000)]),
        "domain":.string("required title; description, color_hex, icon_name, sort_index, archived"),
        "track":.string("required title, domain_id; description, sort_index"),
        "module":.string("required title and exactly one of track_id/domain_id; description, sort_index"),
        "node":.string("required title; description, module_id, project_id, sort_index, status, priority, pinned, capture_intent"),
        "project":.string("required title; description, domain_id, track_id, status, pinned"),
        "resource":.string("required title; body, url, resource_type, domain_id, status, pinned"),
        "attachment":.string("created with import_file; display_name can be updated"),
        "tag":.string("required name; link to resource or reading_item"),
        "reading_group":.string("required title; sort_index"),
        "reading_item":.string("required title; author, notes, url, status, priority, volume, page, sort_index, domain_id, module_id, group_id"),
        "planner_block":.string("required title; weekday 1...7, start_minute, end_minute, duration_minutes, kind, notes, sort_index"),
        "planner_event":.string("required title, start_date, end_date as ISO-8601; kind, notes"),
        "day_note":.string("required day_key YYYY-MM-DD; text"),
        "dev_capture":.string("required title; body, kind, assignee (tanner|claude|codex), context_summary, context_section"),
        "relationships":.string("link_entities supports node->project, resource->node, resource->project, tag->resource, tag->reading_item, resource->reading_item"),
        "write_rules":.string("creates and relationship changes require unique idempotency_key; use UUIDs from search/list; archive is reversible; writes are audited and undo refuses conflicts")
    ]) }
}
#endif

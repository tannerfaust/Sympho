import Foundation

enum WorkspaceValue: Codable, Sendable, Equatable {
    case string(String), int(Int), double(Double), bool(Bool), array([WorkspaceValue]), object([String: WorkspaceValue]), null

    init(from decoder: Decoder) throws {
        let box = try decoder.singleValueContainer()
        if box.decodeNil() { self = .null }
        else if let v = try? box.decode(Bool.self) { self = .bool(v) }
        else if let v = try? box.decode(Int.self) { self = .int(v) }
        else if let v = try? box.decode(Double.self) { self = .double(v) }
        else if let v = try? box.decode(String.self) { self = .string(v) }
        else if let v = try? box.decode([WorkspaceValue].self) { self = .array(v) }
        else { self = .object(try box.decode([String: WorkspaceValue].self)) }
    }

    func encode(to encoder: Encoder) throws {
        var box = encoder.singleValueContainer()
        switch self {
        case .string(let v): try box.encode(v)
        case .int(let v): try box.encode(v)
        case .double(let v): try box.encode(v)
        case .bool(let v): try box.encode(v)
        case .array(let v): try box.encode(v)
        case .object(let v): try box.encode(v)
        case .null: try box.encodeNil()
        }
    }

    var string: String? { if case .string(let value) = self { value } else { nil } }
    var int: Int? { if case .int(let value) = self { value } else { nil } }
    var bool: Bool? { if case .bool(let value) = self { value } else { nil } }
    var array: [WorkspaceValue]? { if case .array(let value) = self { value } else { nil } }
    var object: [String: WorkspaceValue]? { if case .object(let value) = self { value } else { nil } }
}

enum WorkspaceEntityKind: String, Codable, CaseIterable, Sendable {
    case domain, track, module, project, node, resource, tag
    case readingGroup = "reading_group"
    case readingItem = "reading_item"
    case plannerBlock = "planner_block"
    case plannerEvent = "planner_event"
    case dayNote = "day_note"
    case attachment
    case devCapture = "dev_capture"
}

struct WorkspaceEntityDTO: Codable, Identifiable, Sendable, Equatable {
    let id: UUID
    let kind: WorkspaceEntityKind
    var title: String
    var fields: [String: WorkspaceValue]
    var relationships: [String: [UUID]]
    var deleted: Bool
    var createdAt: Date?
    var updatedAt: Date?
}

struct WorkspacePage: Codable, Sendable {
    let items: [WorkspaceEntityDTO]
    let total: Int
    let offset: Int
    let limit: Int
}

enum WorkspaceServiceError: LocalizedError {
    case validation(String), notFound(String), conflict(String), forbidden(String), fileAccessDenied(String), internalFailure(String)

    var code: String {
        switch self {
        case .validation: "validation_failed"
        case .notFound: "not_found"
        case .conflict: "conflict"
        case .forbidden: "forbidden"
        case .fileAccessDenied: "file_access_denied"
        case .internalFailure: "internal"
        }
    }

    var errorDescription: String? {
        switch self {
        case .validation(let m), .notFound(let m), .conflict(let m), .forbidden(let m), .fileAccessDenied(let m), .internalFailure(let m): m
        }
    }
}

extension Dictionary where Key == String, Value == WorkspaceValue {
    func requiredString(_ key: String, max: Int = 20_000) throws -> String {
        guard let raw = self[key]?.string?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            throw WorkspaceServiceError.validation("Missing required field: \(key)")
        }
        guard raw.count <= max else { throw WorkspaceServiceError.validation("\(key) exceeds \(max) characters") }
        return raw
    }

    func uuid(_ key: String) throws -> UUID? {
        guard let raw = self[key]?.string else { return nil }
        guard let value = UUID(uuidString: raw) else { throw WorkspaceServiceError.validation("\(key) must be a UUID") }
        return value
    }
}

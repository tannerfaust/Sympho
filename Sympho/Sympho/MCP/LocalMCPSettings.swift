#if os(macOS)
import Foundation
import Observation
import Security

@Observable
@MainActor
final class LocalMCPSettings {
    static let shared = LocalMCPSettings()
    static let enabledKey = "localMCPEnabled"
    static let portKey = "localMCPPort"
    static let readOnlyKey = "localMCPReadOnly"
    private static let tokenService = "TannerFaust.Sympho.local-mcp"
    private static let tokenAccount = "bearer-token"
    private static let rootsKey = "localMCPApprovedRootBookmarks"

    var isRunning = false
    var errorMessage: String?
    var connectedClients = 0
    var lastClient: String?
    var lastCall: String?

    var enabled: Bool {
        get { ProcessInfo.processInfo.environment["SYMPHO_MCP_ENABLED"] == "1" || UserDefaults.standard.bool(forKey: Self.enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.enabledKey) }
    }
    var port: Int {
        get { let value = UserDefaults.standard.integer(forKey: Self.portKey); return value == 0 ? 8765 : value }
        set { UserDefaults.standard.set(min(max(newValue, 1024), 65535), forKey: Self.portKey) }
    }
    var readOnly: Bool {
        get { UserDefaults.standard.bool(forKey: Self.readOnlyKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.readOnlyKey) }
    }
    var endpoint: String { "http://127.0.0.1:\(port)/mcp" }

    func token() throws -> String {
        if let injected = ProcessInfo.processInfo.environment["SYMPHO_MCP_TOKEN"], !injected.isEmpty { return injected }
        if let existing = try readToken() { return existing }
        return try rotateToken()
    }

    @discardableResult func rotateToken() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw WorkspaceServiceError.internalFailure("Could not generate MCP token")
        }
        let value = Data(bytes).base64EncodedString()
        let query: [String: Any] = [kSecClass as String:kSecClassGenericPassword, kSecAttrService as String:Self.tokenService, kSecAttrAccount as String:Self.tokenAccount]
        SecItemDelete(query as CFDictionary)
        var add = query; add[kSecValueData as String] = Data(value.utf8)
        guard SecItemAdd(add as CFDictionary, nil) == errSecSuccess else { throw WorkspaceServiceError.internalFailure("Could not save MCP token") }
        return value
    }

    func approvedRootURLs() -> [URL] {
        let values = UserDefaults.standard.array(forKey: Self.rootsKey) as? [Data] ?? []
        return values.compactMap { data in
            var stale = false
            return try? URL(resolvingBookmarkData: data, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &stale)
        }
    }

    func addApprovedRoot(_ url: URL) throws {
        let accessing = url.startAccessingSecurityScopedResource(); defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let data = try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
        var values = UserDefaults.standard.array(forKey: Self.rootsKey) as? [Data] ?? []
        if !approvedRootURLs().contains(where: { $0.standardizedFileURL == url.standardizedFileURL }) { values.append(data) }
        UserDefaults.standard.set(values, forKey: Self.rootsKey)
    }

    func removeApprovedRoot(at index: Int) {
        var values = UserDefaults.standard.array(forKey: Self.rootsKey) as? [Data] ?? []
        guard values.indices.contains(index) else { return }; values.remove(at: index); UserDefaults.standard.set(values, forKey: Self.rootsKey)
    }

    func validateApprovedFile(_ url: URL) throws -> URL {
        let resolved = url.standardizedFileURL.resolvingSymlinksInPath()
        guard approvedRootURLs().contains(where: { root in
            let base = root.standardizedFileURL.resolvingSymlinksInPath().path
            return resolved.path == base || resolved.path.hasPrefix(base + "/")
        }) else { throw WorkspaceServiceError.fileAccessDenied("Path is outside the approved MCP folders") }
        return resolved
    }

    func withApprovedFileAccess<T>(_ url: URL, operation: (URL) throws -> T) throws -> T {
        let resolved = try validateApprovedFile(url)
        let root = approvedRootURLs().first { candidate in
            let base=candidate.standardizedFileURL.resolvingSymlinksInPath().path
            return resolved.path==base || resolved.path.hasPrefix(base+"/")
        }
        guard let root else { throw WorkspaceServiceError.fileAccessDenied("Approved folder bookmark is unavailable") }
        let accessing=root.startAccessingSecurityScopedResource();defer{if accessing{root.stopAccessingSecurityScopedResource()}}
        return try operation(resolved)
    }

    func configuration(for client: String) throws -> String {
        let auth = "Bearer \(try token())"
        switch client {
        case "codex": return "[mcp_servers.sympho]\nurl = \"\(endpoint)\"\nhttp_headers = { Authorization = \"\(auth)\" }\ndefault_tools_approval_mode = \"prompt\""
        default: return "{\n  \"mcpServers\": {\n    \"sympho\": {\n      \"type\": \"http\",\n      \"url\": \"\(endpoint)\",\n      \"headers\": { \"Authorization\": \"\(auth)\" }\n    }\n  }\n}"
        }
    }

    private func readToken() throws -> String? {
        let query: [String: Any] = [kSecClass as String:kSecClassGenericPassword, kSecAttrService as String:Self.tokenService, kSecAttrAccount as String:Self.tokenAccount, kSecReturnData as String:true, kSecMatchLimit as String:kSecMatchLimitOne]
        var result: CFTypeRef?; let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw WorkspaceServiceError.internalFailure("Could not read MCP token") }
        return String(data: data, encoding: .utf8)
    }
}
#endif

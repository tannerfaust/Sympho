#if os(macOS)
import Foundation
import AppKit
import MCP
import Network
import Observation
import SwiftData

@Observable
@MainActor
final class LocalMCPServer {
    static let shared = LocalMCPServer()
    private var listener: NWListener?
    private var runtime: MCPRuntime?
    private var container: ModelContainer?
    private var terminationObserver: NSObjectProtocol?
    private let connectionRegistry = ConnectionRegistry()

    func configure(container: ModelContainer) {
        self.container = container
        if terminationObserver == nil {
            terminationObserver = NotificationCenter.default.addObserver(forName:NSApplication.willTerminateNotification,object:nil,queue:.main) { _ in Task { @MainActor in await LocalMCPServer.shared.stop() } }
        }
        if LocalMCPSettings.shared.enabled { Task { await start() } }
    }

    func start() async {
        guard listener == nil, let container else { return }
        let settings=LocalMCPSettings.shared
        do {
            _ = try settings.token()
            let runtime=MCPRuntime(service:SymphoWorkspaceService(context:container.mainContext),settings:settings,token:try settings.token())
            let port=NWEndpoint.Port(rawValue:UInt16(settings.port))!
            let parameters = NWParameters.tcp
            parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: port)
            let listener=try NWListener(using:parameters)
            let registry = connectionRegistry
            listener.newConnectionHandler = { connection in
                let handler = HTTPConnection(connection: connection, runtime: runtime, settings: settings) { finished in
                    registry.remove(finished)
                }
                registry.insert(handler)
                handler.start()
            }
            listener.stateUpdateHandler={ state in Task { @MainActor in
                switch state { case .ready: settings.isRunning=true; settings.errorMessage=nil
                case .failed(let error): settings.isRunning=false; settings.errorMessage="Port \(settings.port) unavailable: \(error.localizedDescription)"
                case .cancelled: settings.isRunning=false
                default: break }
            }}
            listener.start(queue:DispatchQueue(label:"sympho.mcp.listener"))
            self.runtime=runtime; self.listener=listener
        } catch { settings.errorMessage=error.localizedDescription; settings.isRunning=false }
    }

    func stop() async {
        listener?.cancel()
        listener = nil
        connectionRegistry.removeAll()
        await runtime?.stop()
        runtime = nil
        LocalMCPSettings.shared.isRunning = false
    }
    func restart() async { await stop(); if LocalMCPSettings.shared.enabled { await start() } }
}

private final class ConnectionRegistry: @unchecked Sendable {
    private var connections: [HTTPConnection] = []
    private let lock = NSLock()

    func insert(_ connection: HTTPConnection) {
        lock.lock()
        connections.append(connection)
        lock.unlock()
    }

    func remove(_ connection: HTTPConnection) {
        lock.lock()
        connections.removeAll { $0 === connection }
        lock.unlock()
    }

    func removeAll() {
        lock.lock()
        connections.removeAll()
        lock.unlock()
    }
}

private actor MCPRuntime {
    struct Session { let server:Server; let transport:StatefulHTTPServerTransport; var lastAccess:Date; let client:String }
    private var sessions:[String:Session]=[:]
    let service:SymphoWorkspaceService
    let settings:LocalMCPSettings
    let token:String
    init(service:SymphoWorkspaceService,settings:LocalMCPSettings,token:String){self.service=service;self.settings=settings;self.token=token}

    func handle(_ request:HTTPRequest) async -> HTTPResponse {
        guard request.path == "/mcp" else { return .error(statusCode:404,.invalidRequest("MCP endpoint not found")) }
        if !validOrigin(request) { return .error(statusCode:403,.invalidRequest("Origin is not permitted")) }
        if !authorized(request) { return .error(statusCode:401,.invalidRequest("Unauthorized"),extraHeaders:["WWW-Authenticate":"Bearer"])}
        let sid=request.header(HTTPHeaderName.sessionID)
        if let sid,var session=sessions[sid] { session.lastAccess=Date();sessions[sid]=session;return await session.transport.handleRequest(request) }
        guard request.method.uppercased()=="POST",isInitialize(request.body) else { return .error(statusCode:400,.invalidRequest("Missing or invalid MCP session")) }
        let sessionID=UUID().uuidString
        let transport=StatefulHTTPServerTransport(sessionIDGenerator:FixedID(value:sessionID))
        let client=parseClient(request.body)
        let server=Server(name:"sympho",version:"0.1.0",instructions:"Search before writing. Resolve names to UUIDs. Use idempotency keys for creates. Sympho may be in read-only mode. Archive rather than delete. Results are canonical local SwiftData state.",capabilities:.init(tools:.init(listChanged:false)))
        await SymphoMCPToolCatalog.install(on:server,service:service,settings:settings,clientName:{client})
        do {
            try await server.start(transport: transport)
            sessions[sessionID] = Session(server: server, transport: transport, lastAccess: Date(), client: client)
            let count = sessions.count
            Task { @MainActor in
                settings.connectedClients = count
                settings.lastClient = client
            }
            return await transport.handleRequest(request)
        }
        catch { return .error(statusCode:500,.internalError(error.localizedDescription)) }
    }
    func stop() async { for (_,s) in sessions { await s.transport.disconnect() };sessions.removeAll() }
    private func authorized(_ r:HTTPRequest)->Bool { guard let value=r.header("Authorization") else{return false};return value=="Bearer \(token)" }
    private func validOrigin(_ r:HTTPRequest)->Bool { guard let raw=r.header("Origin") else{return true};guard let url=URL(string:raw),let host=url.host?.lowercased() else{return false};return host=="localhost" || host=="127.0.0.1" || host=="::1" }
    private func isInitialize(_ data:Data?)->Bool { guard let data,let o=try? JSONSerialization.jsonObject(with:data) as? [String:Any] else{return false};return o["method"] as? String=="initialize" }
    private func parseClient(_ data:Data?)->String { guard let data,let o=try? JSONSerialization.jsonObject(with:data) as? [String:Any],let p=o["params"] as? [String:Any],let c=p["clientInfo"] as? [String:Any] else{return "unknown"};return "\(c["name"] as? String ?? "unknown") \(c["version"] as? String ?? "")" }
    private struct FixedID:SessionIDGenerator { let value:String;func generateSessionID()->String{value} }
}

private final class HTTPConnection: @unchecked Sendable {
    private let connection: NWConnection
    private let runtime: MCPRuntime
    private let queue: DispatchQueue
    private let onFinish: (HTTPConnection) -> Void
    private var buffer = Data()

    init(connection: NWConnection, runtime: MCPRuntime, settings: LocalMCPSettings, onFinish: @escaping (HTTPConnection) -> Void) {
        self.connection = connection
        self.runtime = runtime
        self.onFinish = onFinish
        self.queue = DispatchQueue(label: "sympho.mcp.connection")
        _ = settings
    }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            guard let self, case .ready = state else { return }
            self.queue.async { self.receive() }
        }
        connection.start(queue: queue)
    }

    private func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1_048_576) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            self.queue.async {
                if let data { self.buffer.append(data) }
                if let request = self.parseRequest() {
                    self.handleRequest(request)
                } else if !isComplete && error == nil {
                    self.receive()
                } else {
                    self.finish()
                }
            }
        }
    }

    private func handleRequest(_ request: HTTPRequest) {
        let runtime = runtime
        Task {
            let response = await runtime.handle(request)
            self.queue.async { self.sendResponse(response) }
        }
    }

    private func parseRequest() -> HTTPRequest? {
        guard let marker = buffer.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        let head = String(decoding: buffer[..<marker.lowerBound], as: UTF8.self)
        let lines = head.components(separatedBy: "\r\n")
        guard let first = lines.first else { return nil }
        let parts = first.split(separator: " ")
        guard parts.count >= 2 else { return nil }
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            let pair = line.split(separator: ":", maxSplits: 1)
            if pair.count == 2 {
                headers[String(pair[0])] = pair[1].trimmingCharacters(in: .whitespaces)
            }
        }
        let length = Int(headers.first(where: { $0.key.lowercased() == "content-length" })?.value ?? "0") ?? 0
        let start = marker.upperBound
        guard buffer.count >= start + length else { return nil }
        let body = length > 0 ? buffer.subdata(in: start..<start + length) : nil
        buffer.removeSubrange(0..<(start + length))
        return HTTPRequest(method: String(parts[0]), headers: headers, body: body, path: String(parts[1]))
    }

    private func finish() {
        connection.cancel()
        onFinish(self)
    }

    private func sendResponse(_ response: HTTPResponse) {
        var headers = response.headers
        headers["Connection"] = "close"
        switch response {
        case .stream(let stream, _):
            headers["Transfer-Encoding"] = "chunked"
            sendHead(statusCode: response.statusCode, headers: headers) { [weak self] in
                self?.pumpStream(stream)
            }
        default:
            let body = response.bodyData ?? Data()
            headers["Content-Length"] = "\(body.count)"
            sendHead(statusCode: response.statusCode, headers: headers) { [weak self] in
                self?.sendData(body) { self?.finish() }
            }
        }
    }

    private func pumpStream(_ stream: AsyncThrowingStream<Data, Error>) {
        Task { [weak self] in
            guard let self else { return }
            do {
                for try await chunk in stream {
                    await self.sendDataOnQueue(Self.chunkedFrame(chunk))
                }
                await self.sendDataOnQueue(Data("0\r\n\r\n".utf8))
                self.queue.async { self.finish() }
            } catch {
                self.queue.async { self.finish() }
            }
        }
    }

    private func sendDataOnQueue(_ data: Data) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            queue.async { [weak self] in
                self?.sendData(data) { continuation.resume() }
            }
        }
    }

    private func sendHead(statusCode: Int, headers: [String: String], completion: @escaping () -> Void) {
        let reason = statusCode == 200 ? "OK" : statusCode == 202 ? "Accepted" : "Error"
        let text = "HTTP/1.1 \(statusCode) \(reason)\r\n"
            + headers.map { "\($0.key): \($0.value)" }.joined(separator: "\r\n")
            + "\r\n\r\n"
        sendData(Data(text.utf8), completion: completion)
    }

    private func sendData(_ data: Data, completion: @escaping () -> Void) {
        guard !data.isEmpty else {
            completion()
            return
        }
        connection.send(content: data, completion: .contentProcessed { _ in completion() })
    }

    private static func chunkedFrame(_ chunk: Data) -> Data {
        Data(String(chunk.count, radix: 16).utf8) + Data("\r\n".utf8) + chunk + Data("\r\n".utf8)
    }
}
#endif

#if os(macOS)
import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct LocalMCPSettingsPanel: View {
    @Environment(\.modelContext) private var modelContext
    @State private var settings = LocalMCPSettings.shared
    @State private var showsFolderPicker = false
    @State private var copiedMessage: String?
    @State private var activity: [MCPChangeSet] = []
    @State private var pendingClient: String?
    @State private var showsCredentialWarning = false

    var body: some View {
        SettingsSection(title:"Local MCP",iconName:"point.3.connected.trianglepath.dotted") {
            VStack(alignment:.leading,spacing:14) {
                Toggle("Allow local AI tools to use Sympho",isOn:Binding(get:{settings.enabled},set:{ value in settings.enabled=value;Task{value ? await LocalMCPServer.shared.start():await LocalMCPServer.shared.stop()}}))
                    .toggleStyle(.switch)
                HStack { Circle().fill(settings.isRunning ? .green:.secondary).frame(width:8,height:8);Text(settings.isRunning ? "Running at \(settings.endpoint)":settings.errorMessage ?? "Stopped").font(.system(size:11)).foregroundStyle(.secondary);Spacer();Text("\(settings.connectedClients) client(s)").font(.system(size:10)).foregroundStyle(.tertiary) }
                HStack { Text("Port").font(.system(size:11,weight:.medium));TextField("8765",value:Binding(get:{settings.port},set:{settings.port=$0}),format:.number).textFieldStyle(.roundedBorder).frame(width:90);Button("Restart"){Task{await LocalMCPServer.shared.restart()}}.buttonStyle(SymphoSecondaryButtonStyle());Toggle("Read only",isOn:Binding(get:{settings.readOnly},set:{settings.readOnly=$0})).toggleStyle(.switch) }
                Divider()
                Text("CLIENT SETUP").font(.system(size:10,weight:.semibold)).foregroundStyle(.tertiary)
                Text("Sympho must be running. The copied configuration contains a local secret; keep it private.").font(.system(size:11)).foregroundStyle(.secondary)
                HStack(spacing:8) { setupButton("Copy Codex config","codex");setupButton("Copy Claude config","claude");setupButton("Copy Cursor config","cursor");Button("Test connection"){Task{await testConnection()}}.buttonStyle(SymphoSecondaryButtonStyle());Button("Rotate token",role:.destructive){rotate()}.buttonStyle(SymphoSecondaryButtonStyle()) }
                if let copiedMessage { Text(copiedMessage).font(.system(size:10)).foregroundStyle(.secondary) }
                Divider()
                HStack { Text("APPROVED FOLDERS").font(.system(size:10,weight:.semibold)).foregroundStyle(.tertiary);Spacer();Button("Add Folder"){showsFolderPicker=true}.buttonStyle(SymphoSecondaryButtonStyle()) }
                ForEach(Array(settings.approvedRootURLs().enumerated()),id:\.offset) { index,url in HStack { Image(systemName:"folder");Text(url.path).font(.system(size:10)).lineLimit(1);Spacer();Button(role:.destructive){settings.removeApprovedRoot(at:index)}label:{Image(systemName:"xmark.circle")}.buttonStyle(.plain) } }
                if settings.approvedRootURLs().isEmpty { Text("No file paths are accessible to MCP until you approve a folder.").font(.system(size:10)).foregroundStyle(.secondary) }
                Divider()
                HStack { Text("AGENT ACTIVITY").font(.system(size:10,weight:.semibold)).foregroundStyle(.tertiary);Spacer();Button("Refresh"){loadActivity()}.buttonStyle(.plain) }
                ForEach(activity.prefix(8)) { item in HStack { VStack(alignment:.leading){Text(item.toolName).font(.system(size:11,weight:.medium));Text("\(item.clientName) · \(item.createdAt.formatted(date:.abbreviated,time:.shortened))").font(.system(size:9)).foregroundStyle(.secondary)};Spacer();if item.undoneAt == nil { Button("Undo"){undo(item)}.buttonStyle(.borderless) } else { Text("Undone").font(.system(size:9)).foregroundStyle(.secondary) } } }
            }
        }
        .fileImporter(isPresented:$showsFolderPicker,allowedContentTypes:[.folder],allowsMultipleSelection:false) { result in if case .success(let urls)=result,let url=urls.first { do { try settings.addApprovedRoot(url) } catch { settings.errorMessage=error.localizedDescription } } }
        .confirmationDialog("Copy complete MCP credentials?",isPresented:$showsCredentialWarning,titleVisibility:.visible) { Button("Copy credentials"){if let client=pendingClient{copyConfiguration(client)}};Button("Cancel",role:.cancel){} } message:{Text("Anyone with this bearer token can access your local Sympho workspace while MCP is enabled.")}
        .onAppear(perform:loadActivity)
    }

    private func setupButton(_ title:String,_ client:String)->some View { Button(title){pendingClient=client;showsCredentialWarning=true}.buttonStyle(SymphoSecondaryButtonStyle()) }
    private func copyConfiguration(_ client:String){do{NSPasteboard.general.clearContents();NSPasteboard.general.setString(try settings.configuration(for:client),forType:.string);copiedMessage="\(client.capitalized) configuration copied"}catch{settings.errorMessage=error.localizedDescription}}
    private func testConnection() async { do { var request=URLRequest(url:URL(string:settings.endpoint)!);request.httpMethod="POST";request.setValue("application/json",forHTTPHeaderField:"Content-Type");request.setValue("application/json, text/event-stream",forHTTPHeaderField:"Accept");request.setValue("Bearer \(try settings.token())",forHTTPHeaderField:"Authorization");request.httpBody=try JSONSerialization.data(withJSONObject:["jsonrpc":"2.0","id":1,"method":"initialize","params":["protocolVersion":"2025-11-25","capabilities":[:],"clientInfo":["name":"Sympho Settings","version":"1"]]]);let (_,response)=try await URLSession.shared.data(for:request);guard let http=response as? HTTPURLResponse,http.statusCode==200 else{throw WorkspaceServiceError.internalFailure("MCP did not accept initialization")};copiedMessage="Connection test passed"}catch{settings.errorMessage=error.localizedDescription} }
    private func rotate(){do{_ = try settings.rotateToken();copiedMessage="Token rotated. Copy fresh client configurations.";Task{await LocalMCPServer.shared.restart()}}catch{settings.errorMessage=error.localizedDescription}}
    private func loadActivity(){activity=(try? modelContext.fetch(FetchDescriptor<MCPChangeSet>(sortBy:[SortDescriptor(\MCPChangeSet.createdAt,order:.reverse)]))) ?? []}
    private func undo(_ item:MCPChangeSet){do{_ = try SymphoWorkspaceService(context:modelContext).undo(changeSetID:item.id,requestID:UUID().uuidString,client:"Sympho Settings");loadActivity()}catch{settings.errorMessage=error.localizedDescription}}
}
#endif

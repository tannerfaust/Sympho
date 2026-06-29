//
//  ProjectsView.swift
//  Sympho
//
//  Created by Tanner Fause on 30.05.2026.
//

import SwiftUI
import SwiftData

struct ProjectsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppNavigationContext.self) private var navigationContext
    @Binding var openProjectID: UUID?
    var onReturnToOrigin: (SymphoNavigationReturn) -> Void = { _ in }

    init(
        openProjectID: Binding<UUID?> = .constant(nil),
        onReturnToOrigin: @escaping (SymphoNavigationReturn) -> Void = { _ in }
    ) {
        self._openProjectID = openProjectID
        self.onReturnToOrigin = onReturnToOrigin
    }

    @Query(filter: #Predicate<Project> { !$0.isDeletedLocally }, sort: \Project.updatedAt, order: .reverse)
    private var projects: [Project]

    @Query(
        filter: #Predicate<Domain> { !$0.isArchived && !$0.isDeletedLocally },
        sort: [SortDescriptor(\Domain.sortIndex), SortDescriptor(\Domain.title)]
    )
    private var domains: [Domain]

    @State private var selectedProject: Project?
    @State private var showsCreateProject = false
    @State private var showsCompactTitle = false

    var body: some View {
        Group {
            if let selectedProject {
                ProjectDetailView(
                    project: selectedProject,
                    backTitle: backTitle(for: selectedProject),
                    onBack: { handleProjectBack(selectedProject) }
                )
            } else {
                projectsOverview
            }
        }
        .onAppear {
            syncNavigationContext()
            consumeProjectDeepLink(openProjectID)
        }
        .onChange(of: selectedProject?.id) { _, _ in syncNavigationContext() }
        .onChange(of: openProjectID) { _, id in
            consumeProjectDeepLink(id)
        }
        .onChange(of: projects.map(\.id)) { _, _ in
            if openProjectID != nil {
                consumeProjectDeepLink(openProjectID)
            }
        }
    }

    private func consumeProjectDeepLink(_ id: UUID?) {
        guard let id, let project = projects.first(where: { $0.id == id }) else { return }
        selectedProject = project
        openProjectID = nil
    }

    private func syncNavigationContext() {
        navigationContext.updateProjectsWorkspace(project: selectedProject)
    }

    private func backTitle(for project: Project) -> String {
        if navigationContext.returnDestination?.entryKind == .projectsList(project.id) {
            return navigationContext.returnDestination?.label ?? "Projects"
        }
        return "Projects"
    }

    private func handleProjectBack(_ project: Project) {
        if let destination = navigationContext.returnDestination,
           destination.entryKind == .projectsList(project.id) {
            navigationContext.returnDestination = nil
            selectedProject = nil
            onReturnToOrigin(destination)
            return
        }
        selectedProject = nil
    }

    private var projectsOverview: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                overviewHeader

                if projects.isEmpty {
                    emptyProjectsView
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 14)], spacing: 14) {
                        ForEach(projects) { project in
                            ProjectCard(project: project) {
                                selectedProject = project
                            }
                        }
                    }
                    .padding(.horizontal, SymphoTheme.outerPadding)
                    .padding(.bottom, SymphoTheme.outerPadding)
                }
            }
        }
        .projectsScrollChrome(title: "Projects", showsCompactTitle: $showsCompactTitle)
        .sheet(isPresented: $showsCreateProject) {
            CreateProjectSheet(domains: domains) {
                showsCreateProject = false
            }
        }
    }

    private var overviewHeader: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Projects")
                    .editorialHeader()

                Text(projects.isEmpty ? "No active workspaces" : "\(projects.count) active workspace\(projects.count == 1 ? "" : "s")")
                    .metadataSans()
            }

            Spacer()

            Button {
                showsCreateProject = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .help("New Project")
        }
        .padding(.horizontal, SymphoTheme.outerPadding)
        .padding(.top, 18)
        .padding(.bottom, 18)
    }

    private var emptyProjectsView: some View {
        VStack(spacing: 13) {
            Spacer()

            Image(systemName: "folder")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(SymphoTheme.secondaryText)
                .frame(width: 64, height: 64)
                .glassEffect(.regular, in: .rect(cornerRadius: 18))

            Text("No projects yet")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(SymphoTheme.primaryText)

            Text("Create a focused workspace for an outcome you want to complete.")
                .metadataSans()

            Button("New Project") {
                showsCreateProject = true
            }
            .buttonStyle(SymphoSecondaryButtonStyle())
            .padding(.top, 3)

            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 380)
    }
}

private struct ProjectCard: View {
    @Environment(\.modelContext) private var modelContext

    let project: Project
    let onOpen: () -> Void

    @State private var isHovering = false
    @State private var showsEditSheet = false

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    SymphoGlyphView(emoji: project.emoji, iconName: project.iconName,
                                    fallbackSystemName: "folder", size: 20)
                        .foregroundStyle(SymphoTheme.primaryText)
                        .frame(width: 46, height: 46)
                        .glassEffect(.regular, in: .rect(cornerRadius: 14))

                    Spacer()

                    Text(project.status.displayName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(SymphoTheme.secondaryText)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(project.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(SymphoTheme.primaryText)
                        .lineLimit(1)

                    Text(project.desc.isEmpty ? "Focused project workspace" : project.desc)
                        .font(.system(size: 12))
                        .foregroundStyle(SymphoTheme.secondaryText)
                        .lineLimit(2)
                        .frame(minHeight: 30, alignment: .topLeading)
                }

                HStack(spacing: 14) {
                    if let domain = project.domain {
                        Label(domain.title, systemImage: DomainIcon.validated(domain.iconName))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    Label("\(activeNodes.count)", systemImage: "checklist")
                    Label("\(activeResources.count)", systemImage: "doc")
                }
                .font(.system(size: 11))
                .foregroundStyle(SymphoTheme.tertiaryText)
            }
            .padding(16)
            .frame(minHeight: 188, alignment: .topLeading)
            .background {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(SymphoTheme.elevatedCanvas.opacity(isHovering ? 0.86 : 0.62))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(isHovering ? SymphoTheme.primaryText.opacity(0.16) : SymphoTheme.dividerColor, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Edit", systemImage: "pencil") { showsEditSheet = true }
            Button("Delete", role: .destructive) { softDeleteProject() }
            Divider()
            Button(project.isPinned ? "Unpin Project" : "Pin Project") {
                project.isPinned.toggle()
                markProjectChanged()
            }
        }
        .sheet(isPresented: $showsEditSheet) {
            SymphoItemEditSheet(subject: .project(project)) {
                showsEditSheet = false
            }
        }
    }

    private func softDeleteProject() {
        project.isDeletedLocally = true
        project.isSynced = false
        project.updatedAt = Date()
        try? modelContext.save()
    }

    private var activeNodes: [Node] {
        project.nodes.filter { !$0.isDeletedLocally }
    }

    private var activeResources: [Resource] {
        project.resources.filter { !$0.isDeletedLocally }
    }

    private func markProjectChanged() {
        project.updatedAt = Date()
        project.isSynced = false
        try? modelContext.save()
    }
}

private struct CreateProjectSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let domains: [Domain]
    let onDismiss: () -> Void

    @State private var title = ""
    @State private var description = ""
    @State private var selectedDomain: Domain?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(SymphoTheme.primaryText)
                    .frame(width: 50, height: 50)
                    .glassEffect(.regular, in: .rect(cornerRadius: 15))

                VStack(alignment: .leading, spacing: 5) {
                    Text("New Project")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(SymphoTheme.primaryText)

                    Text("Create a temporary workspace around a concrete outcome, build, or research goal.")
                        .font(.system(size: 12))
                        .foregroundStyle(SymphoTheme.secondaryText)
                }
            }

            VStack(spacing: 10) {
                ProjectInputRow(title: "Name", iconName: "folder") {
                    TextField("Project name", text: $title)
                        .textFieldStyle(.plain)
                }

                ProjectInputRow(title: "Focus", iconName: "text.alignleft") {
                    TextField("Short description", text: $description)
                        .textFieldStyle(.plain)
                }

                ProjectInputRow(title: "Domain", iconName: "books.vertical") {
                    Picker("Domain", selection: $selectedDomain) {
                        Text("Standalone").tag(nil as Domain?)
                        ForEach(domains) { domain in
                            Text(domain.title).tag(domain as Domain?)
                        }
                    }
                    .labelsHidden()
                }
            }

            HStack {
                Button("Cancel") {
                    close()
                }
                .buttonStyle(SymphoSecondaryButtonStyle())
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create Project") {
                    createProject()
                }
                .buttonStyle(SymphoPrimaryButtonStyle())
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        #if os(macOS)
        .frame(width: 500)
        #endif
        .background(SymphoTheme.primaryCanvas)
    }

    private func createProject() {
        let project = Project(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            desc: description.trimmingCharacters(in: .whitespacesAndNewlines),
            domain: selectedDomain
        )

        modelContext.insert(project)
        if let selectedDomain {
            selectedDomain.projects.append(project)
            selectedDomain.updatedAt = Date()
            selectedDomain.isSynced = false
        }

        try? modelContext.save()
        close()
    }

    private func close() {
        dismiss()
        onDismiss()
    }
}

struct ProjectDetailView: View {
    @Environment(\.modelContext) private var modelContext

    let project: Project
    var backTitle: String = "Projects"
    let onBack: () -> Void

    @State private var selectedNode: Node?
    @State private var showsCreateNode = false
    @State private var showsCreateResource = false
    @State private var showsCompactTitle = false
    @State private var showsEditProjectSheet = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                projectHeader
                nodesSection
                resourcesSection
            }
            .padding(.horizontal, SymphoTheme.outerPadding)
            .padding(.top, 16)
            .padding(.bottom, SymphoTheme.outerPadding)
        }
        .projectsScrollChrome(title: project.title, showsCompactTitle: $showsCompactTitle)
        .sheet(isPresented: $showsCreateNode) {
            CreateProjectNodeSheet(project: project)
        }
        .sheet(isPresented: $showsCreateResource) {
            CreateProjectResourceSheet(project: project)
        }
        .sheet(item: $selectedNode) { node in
            NodeDetailSheet(node: node)
        }
        .sheet(isPresented: $showsEditProjectSheet) {
            SymphoItemEditSheet(subject: .project(project)) {
                showsEditProjectSheet = false
            }
        }
    }

    private var projectHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            SymphoGlassBackButton(title: backTitle, action: onBack)

            HStack(alignment: .top, spacing: 16) {
                SymphoGlyphView(emoji: project.emoji, iconName: project.iconName,
                                fallbackSystemName: "folder", size: 22)
                    .foregroundStyle(SymphoTheme.primaryText)
                    .frame(width: 54, height: 54)
                    .glassEffect(.regular, in: .rect(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 5) {
                    Text(project.title)
                        .editorialHeader()

                    if !project.desc.isEmpty {
                        Text(project.desc)
                            .metadataSans()
                    }
                }

                Spacer()

                Picker("Status", selection: Binding(
                    get: { project.status },
                    set: {
                        project.status = $0
                        markProjectChanged()
                    }
                )) {
                    ForEach(ProjectStatus.allCases) { status in
                        Text(status.displayName).tag(status)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()

                SymphoOverflowMenu(
                    onEdit: { showsEditProjectSheet = true },
                    onDelete: { deleteProject() }
                )
            }

            HStack(spacing: 18) {
                ProjectFact(value: activeNodes.count, label: "Nodes")
                ProjectFact(value: activeResources.count, label: "Materials")

                if let domain = project.domain {
                    Label(domain.title, systemImage: DomainIcon.validated(domain.iconName))
                        .font(.system(size: 11))
                        .foregroundStyle(SymphoTheme.secondaryText)
                }
            }
        }
    }

    private var nodesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Checklist", iconName: "checklist", actionTitle: "Add Node") {
                showsCreateNode = true
            }

            if activeNodes.isEmpty {
                ProjectSectionEmptyState(text: "No milestones added yet.")
            } else {
                VStack(spacing: 0) {
                    ForEach(activeNodes) { node in
                        ProjectNodeRow(node: node) {
                            selectedNode = node
                        }

                        if node.id != activeNodes.last?.id {
                            MinimalDivider()
                                .padding(.leading, 50)
                        }
                    }
                }
                .projectSectionSurface()
            }
        }
    }

    private var resourcesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Materials", iconName: "doc", actionTitle: "Add Material") {
                showsCreateResource = true
            }

            if activeResources.isEmpty {
                ProjectSectionEmptyState(text: "No materials linked yet.")
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 12)], spacing: 12) {
                    ForEach(activeResources) { resource in
                        NodeMaterialRow(resource: resource) {
                            resource.isDeletedLocally = true
                            resource.isSynced = false
                            markProjectChanged()
                        }
                    }
                }
            }
        }
    }

    private func sectionHeader(title: String, iconName: String, actionTitle: String, action: @escaping () -> Void) -> some View {
        HStack {
            Label(title, systemImage: iconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(SymphoTheme.primaryText)

            Spacer()

            Button(action: action) {
                Label(actionTitle, systemImage: "plus")
            }
            .buttonStyle(SymphoSecondaryButtonStyle())
        }
    }

    private var activeNodes: [Node] {
        project.nodes.filter { !$0.isDeletedLocally }
    }

    private var activeResources: [Resource] {
        project.resources.filter { !$0.isDeletedLocally }
    }

    private func markProjectChanged() {
        project.updatedAt = Date()
        project.isSynced = false
        try? modelContext.save()
    }

    private func deleteProject() {
        project.isDeletedLocally = true
        project.isSynced = false
        project.updatedAt = Date()
        try? modelContext.save()
        onBack()
    }
}

private struct ProjectNodeRow: View {
    @Environment(\.modelContext) private var modelContext

    let node: Node
    let onOpen: () -> Void

    @State private var showsEditSheet = false

    var body: some View {
        HStack(spacing: 12) {
            Button(action: toggleCompletion) {
                Image(systemName: node.status == .mastered ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15))
                    .foregroundStyle(node.status == .mastered ? SymphoTheme.colorMastered : SymphoTheme.secondaryText)
            }
            .buttonStyle(.plain)

            Button(action: onOpen) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(node.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(node.status == .mastered ? SymphoTheme.secondaryText : SymphoTheme.primaryText)
                            .strikethrough(node.status == .mastered)

                        if !node.desc.isEmpty {
                            Text(node.desc)
                                .font(SymphoNoteTypography.previewFont)
                                .foregroundStyle(SymphoTheme.secondaryText)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    Text(node.status.displayName)
                        .font(.system(size: 10))
                        .foregroundStyle(SymphoTheme.tertiaryText)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .symphoCardContextMenu(
            edit: { showsEditSheet = true },
            delete: { softDeleteNode() }
        )
        .sheet(isPresented: $showsEditSheet) {
            SymphoItemEditSheet(subject: .node(node)) {
                showsEditSheet = false
            }
        }
    }

    private func toggleCompletion() {
        node.status = node.status == .mastered ? .backlog : .mastered
        node.updatedAt = Date()
        node.isSynced = false
        try? modelContext.save()
    }

    private func softDeleteNode() {
        node.isDeletedLocally = true
        node.isSynced = false
        node.updatedAt = Date()
        try? modelContext.save()
    }
}

private struct CreateProjectNodeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let project: Project

    @State private var title = ""
    @State private var description = ""

    var body: some View {
        ProjectEditorSheet(
            title: "New Node",
            description: "Add a concrete milestone to this project workspace.",
            iconName: "checklist",
            confirmTitle: "Add Node",
            isConfirmDisabled: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        ) {
            ProjectInputRow(title: "Name", iconName: "checkmark.circle") {
                TextField("Milestone name", text: $title)
                    .textFieldStyle(.plain)
            }

            ProjectInputRow(title: "Notes", iconName: "text.alignleft") {
                TextField("Short description", text: $description)
                    .textFieldStyle(.plain)
            }
        } onConfirm: {
            let node = Node(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                desc: description.trimmingCharacters(in: .whitespacesAndNewlines),
                project: project
            )
            modelContext.insert(node)
            project.updatedAt = Date()
            project.isSynced = false
            try? modelContext.save()
            dismiss()
        }
    }
}

private struct CreateProjectResourceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let project: Project

    @State private var title = ""
    @State private var address = ""
    @State private var type: ResourceType = .url

    var body: some View {
        ProjectEditorSheet(
            title: "New Material",
            description: "Link a reference, note, or source to this project.",
            iconName: "doc.badge.plus",
            confirmTitle: "Add Material",
            isConfirmDisabled: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        ) {
            ProjectInputRow(title: "Name", iconName: "doc") {
                TextField("Material name", text: $title)
                    .textFieldStyle(.plain)
            }

            ProjectInputRow(title: "Address", iconName: "link") {
                TextField("URL or reference", text: $address)
                    .textFieldStyle(.plain)
            }

            ProjectInputRow(title: "Type", iconName: "square.stack") {
                Picker("Type", selection: $type) {
                    ForEach(ResourceType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .labelsHidden()
            }
        } onConfirm: {
            let resource = Resource(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                urlString: address.trimmingCharacters(in: .whitespacesAndNewlines),
                resourceType: type,
                domain: project.domain
            )
            modelContext.insert(resource)
            project.resources.append(resource)
            project.updatedAt = Date()
            project.isSynced = false
            try? modelContext.save()
            dismiss()
        }
    }
}

private struct ProjectEditorSheet<Content: View>: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let description: String
    let iconName: String
    let confirmTitle: String
    let isConfirmDisabled: Bool
    @ViewBuilder let content: Content
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: iconName)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(SymphoTheme.primaryText)
                    .frame(width: 50, height: 50)
                    .glassEffect(.regular, in: .rect(cornerRadius: 15))

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(SymphoTheme.primaryText)

                    Text(description)
                        .font(.system(size: 12))
                        .foregroundStyle(SymphoTheme.secondaryText)
                }
            }

            VStack(spacing: 10) {
                content
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(SymphoSecondaryButtonStyle())
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(confirmTitle, action: onConfirm)
                    .buttonStyle(SymphoPrimaryButtonStyle())
                    .disabled(isConfirmDisabled)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        #if os(macOS)
        .frame(width: 500)
        #endif
        .background(SymphoTheme.primaryCanvas)
    }
}

private struct ProjectInputRow<Content: View>: View {
    let title: String
    let iconName: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(SymphoTheme.secondaryText)
                .frame(width: 20)

            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(SymphoTheme.primaryText)
                .frame(width: 62, alignment: .leading)

            content
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 11)
        .frame(height: 42)
        .background {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(SymphoTheme.elevatedCanvas.opacity(0.62))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(SymphoTheme.dividerColor, lineWidth: 1)
        }
    }
}

private struct ProjectFact: View {
    let value: Int
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Text("\(value)")
                .foregroundStyle(SymphoTheme.primaryText)

            Text(label)
                .foregroundStyle(SymphoTheme.secondaryText)
        }
        .font(.system(size: 11, weight: .medium))
    }
}

private struct ProjectSectionEmptyState: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(SymphoTheme.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .projectSectionSurface()
    }
}

private struct ProjectsScrollChrome: ViewModifier {
    let title: String
    @Binding var showsCompactTitle: Bool

    func body(content: Content) -> some View {
        content
            .scrollEdgeEffectStyle(.soft, for: .top)
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top > 38
            } action: { _, newValue in
                withAnimation(.easeInOut(duration: 0.16)) {
                    showsCompactTitle = newValue
                }
            }
            .safeAreaBar(edge: .top, spacing: 0) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SymphoTheme.primaryText)
                    .lineLimit(1)
                    .opacity(showsCompactTitle ? 1 : 0)
                    .frame(maxWidth: .infinity)
                    .frame(height: 26)
                    .offset(y: -2)
                    .accessibilityHidden(!showsCompactTitle)
            }
    }
}

private extension View {
    func projectsScrollChrome(title: String, showsCompactTitle: Binding<Bool>) -> some View {
        modifier(ProjectsScrollChrome(title: title, showsCompactTitle: showsCompactTitle))
    }

    func projectSectionSurface() -> some View {
        background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(SymphoTheme.elevatedCanvas.opacity(0.56))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(SymphoTheme.dividerColor, lineWidth: 1)
        }
    }
}

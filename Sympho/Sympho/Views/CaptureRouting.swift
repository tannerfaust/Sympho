//
//  CaptureRouting.swift
//  Sympho
//

import SwiftUI
import SwiftData

enum CaptureRouteKind: String, Equatable {
    case inbox
    case domain
    case project
}

struct CaptureRoute: Equatable {
    var kind: CaptureRouteKind = .inbox
    var domain: Domain?
    var track: Track?
    var module: Module?
    var project: Project?

    static let inbox = CaptureRoute()

    var isInbox: Bool { kind == .inbox }

    var label: String {
        switch kind {
        case .inbox:
            return "Inbox"
        case .domain:
            if let module {
                return module.title
            }
            if let track {
                return track.title
            }
            return domain?.title ?? "Choose…"
        case .project:
            return project?.title ?? "Choose…"
        }
    }

    var isValid: Bool {
        switch kind {
        case .inbox:
            return true
        case .domain:
            return domain != nil
        case .project:
            return project != nil
        }
    }

    mutating func selectInbox() {
        kind = .inbox
        domain = nil
        track = nil
        module = nil
        project = nil
    }

    mutating func selectDomain(_ domain: Domain, track: Track? = nil, module: Module? = nil) {
        kind = .domain
        self.domain = domain
        self.track = track
        self.module = module
        project = nil
    }

    mutating func selectProject(_ project: Project) {
        kind = .project
        self.project = project
        domain = nil
        track = nil
        module = nil
    }
}

enum CaptureRouting {
    static func inboxCapturesModule(in domain: Domain, track: Track?, context: ModelContext) -> Module {
        if let module = track?.activeModules.first(where: { $0.title == inboxModuleTitle }) {
            return module
        }

        if let track {
            let module = Module(title: inboxModuleTitle, desc: "Default module for quick capture entries", track: track, domain: domain)
            context.insert(module)
            track.modules.append(module)
            return module
        }

        let title = inboxModuleTitle
        if let existing = domain.modules.first(where: { $0.title == title && !$0.isDeletedLocally && $0.track == nil }) {
            return existing
        }

        let module = Module(title: title, desc: "Default module for quick capture entries", domain: domain)
        context.insert(module)
        domain.modules.append(module)
        return module
    }

    static func resolveModule(for route: CaptureRoute, context: ModelContext) -> Module? {
        guard route.kind == .domain, let domain = route.domain else { return nil }

        if let module = route.module, !module.isDeletedLocally {
            return module
        }

        return inboxCapturesModule(in: domain, track: route.track, context: context)
    }

    static func apply(route: CaptureRoute, to node: Node, context: ModelContext) {
        switch route.kind {
        case .inbox:
            node.module = nil
            node.project = nil
            node.isOrphan = true

        case .domain:
            guard let domain = route.domain else { return }
            let module = resolveModule(for: route, context: context)
            node.module = module
            node.project = nil
            node.isOrphan = false
            module?.isSynced = false
            module?.updatedAt = Date()
            domain.isSynced = false
            domain.updatedAt = Date()

        case .project:
            guard let project = route.project else { return }
            node.project = project
            node.module = nil
            node.isOrphan = false
            project.isSynced = false
            project.updatedAt = Date()
        }
    }

    private static let inboxModuleTitle = "Inbox Captures"
}

struct CaptureIntentPicker: View {
    @Binding var intent: CaptureIntent

    var body: some View {
        Picker("Type", selection: $intent) {
            ForEach(CaptureIntent.allCases) { option in
                Text(option.displayName).tag(option)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .frame(minWidth: 148)
        .help("Type of input")
    }
}

struct CaptureDestinationPicker: View {
    @Binding var route: CaptureRoute
    let domains: [Domain]
    let projects: [Project]

    var body: some View {
        Menu {
            Button("Inbox", systemImage: "tray") {
                route.selectInbox()
            }

            if !domains.isEmpty {
                Section("Domains") {
                    ForEach(domains) { domain in
                        domainMenu(for: domain)
                    }
                }
            }

            if !projects.isEmpty {
                Section("Projects") {
                    ForEach(projects) { project in
                        Button {
                            route.selectProject(project)
                        } label: {
                            Text(project.title)
                        }
                    }
                }
            }
        } label: {
            Text(route.label)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Destination")
    }

    @ViewBuilder
    private func domainMenu(for domain: Domain) -> some View {
        let activeTracks = domain.tracks.filter { !$0.isDeletedLocally }
        let standaloneModules = domain.modules.filter { !$0.isDeletedLocally && $0.track == nil }

        if activeTracks.isEmpty && standaloneModules.isEmpty {
            Button(domain.title) {
                route.selectDomain(domain)
            }
        } else {
            Menu {
                Button("\(domain.title)") {
                    route.selectDomain(domain)
                }

                if !activeTracks.isEmpty {
                    Section("Tracks") {
                        ForEach(activeTracks) { track in
                            trackMenu(for: track, in: domain)
                        }
                    }
                }

                if !standaloneModules.isEmpty {
                    Section("Modules") {
                        ForEach(standaloneModules) { module in
                            Button(module.title) {
                                route.selectDomain(domain, module: module)
                            }
                        }
                    }
                }
            } label: {
                Text(domain.title)
            }
        }
    }

    @ViewBuilder
    private func trackMenu(for track: Track, in domain: Domain) -> some View {
        let activeModules = track.activeModules

        if activeModules.isEmpty {
            Button(track.title) {
                route.selectDomain(domain, track: track)
            }
        } else {
            Menu {
                Button(track.title) {
                    route.selectDomain(domain, track: track)
                }

                Section("Modules") {
                    ForEach(activeModules) { module in
                        Button(module.title) {
                            route.selectDomain(domain, track: track, module: module)
                        }
                    }
                }
            } label: {
                Text(track.title)
            }
        }
    }
}

struct CaptureIntentBadge: View {
    let intent: CaptureIntent
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: intent.iconName)
                .font(.system(size: compact ? 9 : 10, weight: .semibold))

            Text(compact ? intent.shortName : intent.displayName)
                .font(.system(size: compact ? 10 : 11, weight: .semibold))
        }
        .foregroundStyle(intent.pillForeground)
        .padding(.horizontal, compact ? 8 : 10)
        .padding(.vertical, compact ? 4 : 5)
        .background(intent.pillBackground, in: .capsule)
    }
}

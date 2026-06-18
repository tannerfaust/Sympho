//
//  MenuBarCaptureMenu.swift
//  Sympho
//

import SwiftUI
import SwiftData

struct MenuBarCaptureMenu: View {
    @Environment(\.openWindow) private var openWindow

    @Query(
        filter: #Predicate<Domain> { !$0.isArchived && !$0.isDeletedLocally },
        sort: [SortDescriptor(\Domain.sortIndex), SortDescriptor(\Domain.title)]
    )
    private var domains: [Domain]

    @Query(filter: #Predicate<Project> { !$0.isDeletedLocally }, sort: \Project.title)
    private var projects: [Project]

    private var defaultRoute: CaptureRoute {
        MenuBarCaptureSettings.suggestedDefaultRoute(domains: domains, projects: projects)
    }

    var body: some View {
        Button("Quick Capture", systemImage: "plus.circle") {
            launch(intent: MenuBarCaptureSettings.defaultIntent, route: defaultRoute)
        }

        Divider()

        Button("Open Sympho", systemImage: "macwindow") {
            openWindow(id: "main")
        }

        Divider()

        Button("Thing to Learn", systemImage: CaptureIntent.learningNode.iconName) {
            launch(intent: .learningNode, route: defaultRoute)
        }

        Button("Learning Material", systemImage: CaptureIntent.learningMaterial.iconName) {
            launch(intent: .learningMaterial, route: defaultRoute)
        }

        Button("Inbox Note", systemImage: CaptureIntent.planInbox.iconName) {
            launch(intent: .planInbox, route: .inbox)
        }

        if !domains.isEmpty || !projects.isEmpty {
            Divider()
        }

        if !domains.isEmpty {
            Menu("Add to Domain") {
                ForEach(domains) { domain in
                    domainCaptureMenu(for: domain)
                }
            }
        }

        if !projects.isEmpty {
            Menu("Add to Project") {
                ForEach(projects) { project in
                    projectCaptureMenu(for: project)
                }
            }
        }
    }

    @ViewBuilder
    private func domainCaptureMenu(for domain: Domain) -> some View {
        let activeTracks = domain.tracks.filter { !$0.isDeletedLocally }.roadmapSorted()
        let standaloneModules = domain.modules.filter { !$0.isDeletedLocally && $0.track == nil }.roadmapSorted()

        Menu(domain.title) {
            captureButtons(route: route(for: domain))

            if !activeTracks.isEmpty {
                Divider()
                Section("Tracks") {
                    ForEach(activeTracks) { track in
                        trackCaptureMenu(for: track, in: domain)
                    }
                }
            }

            if !standaloneModules.isEmpty {
                Divider()
                Section("Modules") {
                    ForEach(standaloneModules) { module in
                        Menu(module.title) {
                            captureButtons(route: route(for: domain, module: module))
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func trackCaptureMenu(for track: Track, in domain: Domain) -> some View {
        let modules = track.activeModules

        Menu(track.title) {
            captureButtons(route: route(for: domain, track: track))

            if !modules.isEmpty {
                Divider()
                Section("Modules") {
                    ForEach(modules) { module in
                        Menu(module.title) {
                            captureButtons(route: route(for: domain, track: track, module: module))
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func projectCaptureMenu(for project: Project) -> some View {
        Menu(project.title) {
            captureButtons(route: route(for: project))
        }
    }

    @ViewBuilder
    private func captureButtons(route: CaptureRoute) -> some View {
        Button("Thing to Learn", systemImage: CaptureIntent.learningNode.iconName) {
            launch(intent: .learningNode, route: route)
        }

        Button("Learning Material", systemImage: CaptureIntent.learningMaterial.iconName) {
            launch(intent: .learningMaterial, route: route)
        }
    }

    private func route(for domain: Domain, track: Track? = nil, module: Module? = nil) -> CaptureRoute {
        var route = CaptureRoute()
        route.selectDomain(domain, track: track, module: module)
        return route
    }

    private func route(for project: Project) -> CaptureRoute {
        var route = CaptureRoute()
        route.selectProject(project)
        return route
    }

    private func launch(intent: CaptureIntent, route: CaptureRoute) {
        openWindow(
            id: "quickCapture",
            value: QuickCaptureLaunchConfiguration(intent: intent, route: intent == .planInbox ? .inbox : route)
        )
    }
}

struct QuickCaptureWindow: View {
    @Environment(\.dismiss) private var dismiss
    let configuration: QuickCaptureLaunchConfiguration?

    @State private var isPresented = true

    @Query(
        filter: #Predicate<Domain> { !$0.isArchived && !$0.isDeletedLocally },
        sort: [SortDescriptor(\Domain.sortIndex), SortDescriptor(\Domain.title)]
    )
    private var domains: [Domain]

    @Query(filter: #Predicate<Project> { !$0.isDeletedLocally }, sort: \Project.title)
    private var projects: [Project]

    private var initialIntent: CaptureIntent {
        configuration?.intent ?? MenuBarCaptureSettings.defaultIntent
    }

    private var initialRoute: CaptureRoute {
        if let configuration {
            return configuration.route(domains: domains, projects: projects)
        }
        return MenuBarCaptureSettings.suggestedDefaultRoute(domains: domains, projects: projects)
    }

    var body: some View {
        QuickCaptureOverlay(
            isPresented: $isPresented,
            initialIntent: initialIntent,
            initialRoute: initialRoute
        )
        .onChange(of: isPresented) { _, newValue in
            if !newValue {
                dismiss()
            }
        }
    }
}

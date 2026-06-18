//
//  MenuBarCaptureSettings.swift
//  Sympho
//

import Foundation

enum MenuBarCaptureSettings {
    static let isEnabledKey = "menuBarCaptureEnabled"
    static let defaultIntentKey = "menuBarCaptureDefaultIntent"
    static let defaultRouteKindKey = "menuBarCaptureDefaultRouteKind"
    static let defaultDomainIDKey = "menuBarCaptureDefaultDomainID"
    static let defaultTrackIDKey = "menuBarCaptureDefaultTrackID"
    static let defaultModuleIDKey = "menuBarCaptureDefaultModuleID"
    static let defaultProjectIDKey = "menuBarCaptureDefaultProjectID"

    static var defaultIntent: CaptureIntent {
        get {
            let rawValue = UserDefaults.standard.string(forKey: defaultIntentKey)
            return rawValue.flatMap(CaptureIntent.init(rawValue:)) ?? .learningNode
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: defaultIntentKey)
        }
    }

    static var hasStoredDefaultRoute: Bool {
        UserDefaults.standard.object(forKey: defaultRouteKindKey) != nil
    }

    static func defaultRoute(domains: [Domain], projects: [Project]) -> CaptureRoute {
        route(
            kindRawValue: UserDefaults.standard.string(forKey: defaultRouteKindKey),
            domainID: uuid(forKey: defaultDomainIDKey),
            trackID: uuid(forKey: defaultTrackIDKey),
            moduleID: uuid(forKey: defaultModuleIDKey),
            projectID: uuid(forKey: defaultProjectIDKey),
            domains: domains,
            projects: projects
        )
    }

    static func suggestedDefaultRoute(domains: [Domain], projects: [Project]) -> CaptureRoute {
        let configuredRoute = defaultRoute(domains: domains, projects: projects)
        guard !hasStoredDefaultRoute, configuredRoute.isInbox, let firstDomain = domains.first else {
            return configuredRoute
        }

        var route = CaptureRoute()
        route.selectDomain(firstDomain)
        return route
    }

    static func saveDefaultRoute(_ route: CaptureRoute) {
        let defaults = UserDefaults.standard
        defaults.set(route.kind.rawValue, forKey: defaultRouteKindKey)
        defaults.set(route.domain?.id.uuidString, forKey: defaultDomainIDKey)
        defaults.set(route.track?.id.uuidString, forKey: defaultTrackIDKey)
        defaults.set(route.module?.id.uuidString, forKey: defaultModuleIDKey)
        defaults.set(route.project?.id.uuidString, forKey: defaultProjectIDKey)
    }

    static func route(
        kindRawValue: String?,
        domainID: UUID?,
        trackID: UUID?,
        moduleID: UUID?,
        projectID: UUID?,
        domains: [Domain],
        projects: [Project]
    ) -> CaptureRoute {
        guard let kindRawValue, let kind = CaptureRouteKind(rawValue: kindRawValue) else {
            return .inbox
        }

        switch kind {
        case .inbox:
            return .inbox
        case .domain:
            guard let domainID, let domain = domains.first(where: { $0.id == domainID }) else {
                return .inbox
            }
            let track = trackID.flatMap { id in
                domain.tracks.first { $0.id == id && !$0.isDeletedLocally }
            }
            let module = moduleID.flatMap { id in
                let standalone = domain.modules.first { $0.id == id && !$0.isDeletedLocally && $0.track == nil }
                let trackModule = domain.tracks
                    .flatMap(\.modules)
                    .first { $0.id == id && !$0.isDeletedLocally }
                return standalone ?? trackModule
            }

            var route = CaptureRoute()
            route.selectDomain(domain, track: track, module: module)
            return route
        case .project:
            guard let projectID, let project = projects.first(where: { $0.id == projectID }) else {
                return .inbox
            }
            var route = CaptureRoute()
            route.selectProject(project)
            return route
        }
    }

    private static func uuid(forKey key: String) -> UUID? {
        UserDefaults.standard.string(forKey: key).flatMap(UUID.init(uuidString:))
    }
}

struct QuickCaptureLaunchConfiguration: Codable, Hashable {
    var token = UUID()
    var intentRawValue: String
    var routeKindRawValue: String?
    var domainID: UUID?
    var trackID: UUID?
    var moduleID: UUID?
    var projectID: UUID?

    init(intent: CaptureIntent, route: CaptureRoute) {
        intentRawValue = intent.rawValue
        routeKindRawValue = route.kind.rawValue
        domainID = route.domain?.id
        trackID = route.track?.id
        moduleID = route.module?.id
        projectID = route.project?.id
    }

    var intent: CaptureIntent {
        CaptureIntent(rawValue: intentRawValue) ?? .learningNode
    }

    func route(domains: [Domain], projects: [Project]) -> CaptureRoute {
        MenuBarCaptureSettings.route(
            kindRawValue: routeKindRawValue,
            domainID: domainID,
            trackID: trackID,
            moduleID: moduleID,
            projectID: projectID,
            domains: domains,
            projects: projects
        )
    }
}

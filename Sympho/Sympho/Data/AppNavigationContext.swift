//
//  AppNavigationContext.swift
//  Sympho
//

import Foundation
import Observation

enum DevCaptureSettings {
    private static let enabledKey = "devCaptureEnabled"

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }
}

@Observable
final class AppNavigationContext {
    var sectionTitle: String = NavSection.dashboard.title
    var domainTitle: String?
    var trackTitle: String?
    var moduleTitle: String?
    var nodeTitle: String?
    var projectTitle: String?

    var summary: String {
        var parts = [sectionTitle]
        if let domainTitle { parts.append(domainTitle) }
        if let trackTitle { parts.append(trackTitle) }
        if let moduleTitle { parts.append(moduleTitle) }
        if let nodeTitle { parts.append(nodeTitle) }
        if let projectTitle, !parts.contains(projectTitle) { parts.append(projectTitle) }
        return parts.joined(separator: " › ")
    }

    func updateShell(section: NavSection, domain: Domain?, isSettings: Bool) {
        if isSettings {
            sectionTitle = "Settings"
            clearDrillDown()
            return
        }

        sectionTitle = section.title

        if section != .domains {
            domainTitle = nil
            clearDrillDown()
        } else if domain == nil {
            domainTitle = nil
            clearDrillDown()
        } else {
            domainTitle = domain?.title
        }
    }

    func updateDomainWorkspace(
        domain: Domain?,
        track: Track?,
        module: Module?,
        node: Node?,
        project: Project?
    ) {
        sectionTitle = NavSection.domains.title
        domainTitle = domain?.title
        trackTitle = track?.title
        moduleTitle = module?.title
        nodeTitle = node?.title
        projectTitle = project?.title
    }

    func updateProjectsWorkspace(project: Project?) {
        sectionTitle = NavSection.projects.title
        clearDrillDown()
        projectTitle = project?.title
    }

    private func clearDrillDown() {
        trackTitle = nil
        moduleTitle = nil
        nodeTitle = nil
        projectTitle = nil
    }
}

//
//  SymphoApp.swift
//  Sympho
//
//  Created by Tanner Fause on 30.05.2026.
//

import SwiftUI
import SwiftData

@main
struct SymphoApp: App {
    @Environment(\.scenePhase) private var scenePhase

    let container: ModelContainer

    init() {
        do {
            let schema = Schema([
                Domain.self,
                Track.self,
                Module.self,
                Project.self,
                Node.self,
                Resource.self,
                LibraryAttachment.self,
                LibraryTag.self,
                ReadingListGroup.self,
                ReadingListItem.self,
                PlannerWeeklyBlock.self,
                PlannerEvent.self,
                PlannerDayNote.self,
                DevCapture.self
            ])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            container = try ModelContainer(for: schema, configurations: [config])
            SymphoProductionDataSanitizer.runIfNeeded(in: container.mainContext)
            EnglishC2GrammarSeed.runIfNeeded(in: container.mainContext)
        } catch {
            fatalError("Could not initialize SwiftData ModelContainer: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        #if os(macOS)
        WindowGroup("Sympho", id: "main") {
            rootContent
        }
        .windowStyle(.hiddenTitleBar)
        .defaultLaunchBehavior(.presented)
        .commands {
            CommandGroup(after: .textEditing) {
                Button("Search Sympho") {
                    NotificationCenter.default.post(name: .showGlobalSearch, object: nil)
                }
                .keyboardShortcut("f", modifiers: [.command])
            }
        }

        MenuBarExtra {
            MenuBarCaptureMenu()
                .modelContainer(container)
        } label: {
            Label("Sympho", image: "SymphoMenuBarIcon")
        }
        .menuBarExtraStyle(.menu)

        WindowGroup("Quick Capture", id: "quickCapture", for: QuickCaptureLaunchConfiguration.self) { configuration in
            QuickCaptureWindow(configuration: configuration.wrappedValue)
                .modelContainer(container)
                .preferredColorScheme(.light)
        }
        .windowResizability(.contentSize)
        .restorationBehavior(.disabled)
        #else
        WindowGroup {
            rootContent
        }
        #endif
    }

    private var rootContent: some View {
        ContentView()
            .modelContainer(container)
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .inactive || newPhase == .background else { return }
                do {
                    try container.mainContext.save()
                } catch {
                    print("Could not save local SwiftData changes: \(error.localizedDescription)")
                }
            }
    }
}

private enum SymphoProductionDataSanitizer {
    private static let cleanupVersion = 1
    private static let cleanupKey = "productionDataSanitizerVersion"

    static func runIfNeeded(in context: ModelContext) {
        guard UserDefaults.standard.integer(forKey: cleanupKey) < cleanupVersion else { return }

        do {
            try removeLegacyDemoData(in: context)
            try context.save()
            UserDefaults.standard.set(cleanupVersion, forKey: cleanupKey)
        } catch {
            print("Could not sanitize legacy demo data: \(error.localizedDescription)")
        }
    }

    private static func removeLegacyDemoData(in context: ModelContext) throws {
        let domains = try context.fetch(FetchDescriptor<Domain>())
        let tracks = try context.fetch(FetchDescriptor<Track>())
        let modules = try context.fetch(FetchDescriptor<Module>())
        let projects = try context.fetch(FetchDescriptor<Project>())
        let nodes = try context.fetch(FetchDescriptor<Node>())
        let resources = try context.fetch(FetchDescriptor<Resource>())
        let readingGroups = try context.fetch(FetchDescriptor<ReadingListGroup>())
        let readingItems = try context.fetch(FetchDescriptor<ReadingListItem>())

        for node in nodes where isLegacyDemoNode(node) {
            context.delete(node)
        }

        for resource in resources where isLegacyDemoResource(resource) {
            context.delete(resource)
        }

        for project in projects where isLegacyDemoProject(project) {
            context.delete(project)
        }

        for module in modules where isLegacyDemoModule(module) {
            context.delete(module)
        }

        for track in tracks where isLegacyDemoTrack(track) {
            context.delete(track)
        }

        for item in readingItems where isLegacyReadingSample(item) {
            context.delete(item)
        }

        for group in readingGroups where isLegacyReadingGroup(group) {
            context.delete(group)
        }

        for domain in domains where isLegacyDemoDomain(domain) {
            context.delete(domain)
        }
    }

    private static func isLegacyDemoDomain(_ domain: Domain) -> Bool {
        (domain.title == "Robotics & Artificial Intelligence"
            && domain.desc == "Mapping algorithms, SLAM systems, kinematics, and deep neural vision control.")
        || (domain.title == "Computer Science Foundations"
            && domain.desc == "Compilers, systems logic, memory layouts, and algorithm design.")
    }

    private static func isLegacyDemoTrack(_ track: Track) -> Bool {
        switch (track.title, track.desc) {
        case ("Autonomous Navigation & SLAM", "Core math and sensor fusion needed for localized positioning."),
             ("Algorithms & Data Structures", "Complexity, classic structures, and problem-solving patterns."),
             ("Systems Programming", "Processes, memory, I/O, and how machines run your code."):
            return true
        default:
            return false
        }
    }

    private static func isLegacyDemoModule(_ module: Module) -> Bool {
        if module.title == "Inbox Captures", module.activeNodes.isEmpty {
            return true
        }

        switch (module.title, module.desc) {
        case ("LIDAR Integration & Filtering", "Raw laser scan points to distance matrices."),
             ("Visual-Inertial Odometry (VIO)", "Stereo camera features fused with IMU readings."),
             ("Inverse Kinematics Math", "Jacobian matrices and end-effector coordinates."),
             ("Sorting & Search", "Divide-and-conquer sorts, binary search, and amortized analysis."),
             ("Graphs & Paths", "BFS, DFS, shortest paths, and spanning trees."),
             ("Operating Systems", "Scheduling, virtual memory, and filesystem abstractions."),
             ("Networking Basics", "Sockets, HTTP, and how requests move across the stack."),
             ("Memory Management", "Stack vs heap, pointers, and ownership in low-level languages."):
            return true
        default:
            return false
        }
    }

    private static func isLegacyDemoProject(_ project: Project) -> Bool {
        project.title == "CueIn macOS App"
            && project.desc == "Goal: Launch an editorial media capture toolbar for content creators."
    }

    private static func isLegacyDemoNode(_ node: Node) -> Bool {
        switch (node.title, node.desc) {
        case ("LIDAR Sensor Integration", "Parse raw packet arrays from Ouster OS1 sensor using C++ bindings."),
             ("Extended Kalman Filtering", "Fusing odometer wheel ticks and gyroscope axes in state transitions."),
             ("Forward Kinematics Matrices", "Master Denavit-Hartenberg (DH) parameters for 6-DoF robotic arm."),
             ("Design Custom SwiftData Sync", "Implement isSynced flags, isDeletedLocally flags, and transaction journals."),
             ("Read about SwiftData relationships", "Understand how @Relationship rules behave during cascade delete."),
             ("Source: supabase.com/docs", "Review edge function syntax for postgres triggers."),
             ("Big-O notation cheat sheet", "Compare growth rates for common loop and recursion patterns."),
             ("Implement merge sort on linked lists", "Practice stable O(n log n) sorting without random access."),
             ("Binary search on answer space", "Use monotonic predicates to search numeric ranges efficiently."),
             ("Dijkstra with a priority queue", "Non-negative edge weights and lazy decrease-key strategies."),
             ("Topological ordering for prerequisites", "Detect cycles while ordering course or task dependencies."),
             ("Process vs thread models", "Context switches, shared address spaces, and synchronization primitives."),
             ("Virtual memory and page tables", "TLB hits, demand paging, and copy-on-write semantics."),
             ("TCP handshake and flow control", "SYN/ACK sequence, window sizes, and retransmission behavior."),
             ("Pointers and dynamic allocation in C", "Malloc, free, and struct layout with alignment padding."):
            return true
        default:
            return false
        }
    }

    private static func isLegacyDemoResource(_ resource: Resource) -> Bool {
        switch (resource.title, resource.urlString) {
        case ("SLAM Course: Lecture 4 - LIDAR Scan Matching", "https://www.youtube.com/watch?v=SLAM_LIDAR"),
             ("Supabase Swift Client Docs", "https://github.com/supabase-community/supabase-swift"),
             ("Supabase Database Schema Docs", "https://supabase.com/docs/guides/database/tables"),
             ("The C Programming Language (K&R)", "https://www.read.c/kr_book.pdf"):
            return true
        default:
            return false
        }
    }

    private static func isLegacyReadingGroup(_ group: ReadingListGroup) -> Bool {
        guard group.title == "Deep dives" || group.title == "Leisure" else { return false }
        return !group.items.isEmpty && group.items.allSatisfy { isLegacyReadingSample($0) }
    }

    private static func isLegacyReadingSample(_ item: ReadingListItem) -> Bool {
        legacyReadingSamples[item.title] == item.author
    }

    private static let legacyReadingSamples: [String: String] = [
        "Thinking, Fast and Slow": "Daniel Kahneman",
        "Deep Work": "Cal Newport",
        "The Design of Everyday Things": "Don Norman",
        "Project Hail Mary": "Andy Weir",
        "Born to Run": "Christopher McDougall",
        "Meditations": "Marcus Aurelius",
        "Structure and Interpretation of Computer Programs": "Abelson & Sussman",
        "So Good They Can't Ignore You": "Cal Newport"
    ]
}

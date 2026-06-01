//
//  ContentView.swift
//  Sympho
//
//  Created by Tanner Fause on 30.05.2026.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var domains: [Domain]
    
    var body: some View {
        NavigationShell()
            .onAppear {
                initializeMockDataIfNeeded()
                seedComputerScienceCurriculumIfNeeded()
                seedReadingListSamplesIfNeeded()
            }
            .preferredColorScheme(.light)
    }

    private func seedReadingListSamplesIfNeeded() {
        let descriptor = FetchDescriptor<ReadingListItem>(
            predicate: #Predicate<ReadingListItem> { !$0.isDeletedLocally }
        )
        guard (try? modelContext.fetchCount(descriptor)) == 0 else { return }

        let fiction = ReadingListGroup(title: "Deep dives", sortIndex: 0)
        let leisure = ReadingListGroup(title: "Leisure", sortIndex: 1)
        modelContext.insert(fiction)
        modelContext.insert(leisure)

        let samples: [(String, String, ReadingStatus, ReadingPriority, String, String, ReadingListGroup?)] = [
            ("Thinking, Fast and Slow", "Daniel Kahneman", .reading, .high, "Part II", "p. 142", fiction),
            ("Deep Work", "Cal Newport", .queue, .high, "", "", fiction),
            ("The Design of Everyday Things", "Don Norman", .queue, .normal, "", "", fiction),
            ("Project Hail Mary", "Andy Weir", .queue, .normal, "", "", leisure),
            ("Born to Run", "Christopher McDougall", .reading, .normal, "", "Ch. 8", leisure),
            ("Meditations", "Marcus Aurelius", .finished, .low, "", "", nil),
            ("Structure and Interpretation of Computer Programs", "Abelson & Sussman", .paused, .high, "Ch. 2", "ex. 2.4", fiction),
            ("So Good They Can't Ignore You", "Cal Newport", .queue, .normal, "", "", nil),
        ]

        for (index, sample) in samples.enumerated() {
            let item = ReadingListItem(
                title: sample.0,
                author: sample.1,
                status: sample.2,
                priority: sample.3,
                stoppedAtVolume: sample.4,
                stoppedAtPage: sample.5,
                sortIndex: index,
                group: sample.6
            )
            modelContext.insert(item)
        }

        try? modelContext.save()
    }

    private func seedComputerScienceCurriculumIfNeeded() {
        guard let cs = domains.first(where: {
            !$0.isDeletedLocally
                && $0.title.localizedCaseInsensitiveContains("computer science")
        }) else { return }

        let activeTracks = cs.tracks.filter { !$0.isDeletedLocally }
        guard activeTracks.isEmpty else { return }

        ContentView.seedComputerScienceCurriculum(in: cs, modelContext: modelContext)
        try? modelContext.save()
    }
    
    private func initializeMockDataIfNeeded() {
        guard domains.isEmpty else { return }
        
        // 1. Create Robotics & AI Domain
        let robotics = Domain(
            title: "Robotics & Artificial Intelligence",
            desc: "Mapping algorithms, SLAM systems, kinematics, and deep neural vision control.",
            colorHex: "#1A1A1A",
            iconName: DomainIcon.processor.rawValue,
            sortIndex: 0
        )
        modelContext.insert(robotics)
        
        // Track inside Robotics
        let navigationTrack = Track(
            title: "Autonomous Navigation & SLAM",
            desc: "Core math and sensor fusion needed for localized positioning.",
            domain: robotics
        )
        modelContext.insert(navigationTrack)
        robotics.tracks.append(navigationTrack)
        
        // Modules inside SLAM Track
        let laserModule = Module(
            title: "LIDAR Integration & Filtering",
            desc: "Raw laser scan points to distance matrices.",
            track: navigationTrack
        )
        modelContext.insert(laserModule)
        navigationTrack.modules.append(laserModule)
        
        let visualSlamModule = Module(
            title: "Visual-Inertial Odometry (VIO)",
            desc: "Stereo camera features fused with IMU readings.",
            track: navigationTrack
        )
        modelContext.insert(visualSlamModule)
        navigationTrack.modules.append(visualSlamModule)
        
        // Nodes inside Laser Module
        let lidarNode = Node(
            title: "LIDAR Sensor Integration",
            desc: "Parse raw packet arrays from Ouster OS1 sensor using C++ bindings.",
            status: .active,
            priority: .normal,
            module: laserModule
        )
        modelContext.insert(lidarNode)
        laserModule.nodes.append(lidarNode)
        
        let kalmanNode = Node(
            title: "Extended Kalman Filtering",
            desc: "Fusing odometer wheel ticks and gyroscope axes in state transitions.",
            status: .backlog,
            priority: .critical, // Knowledge Debt
            module: laserModule
        )
        modelContext.insert(kalmanNode)
        laserModule.nodes.append(kalmanNode)
        
        // Add resources to SLAM
        let lidarVideo = Resource(
            title: "SLAM Course: Lecture 4 - LIDAR Scan Matching",
            urlString: "https://www.youtube.com/watch?v=SLAM_LIDAR",
            resourceType: .video,
            domain: robotics
        )
        modelContext.insert(lidarVideo)
        lidarNode.resources.append(lidarVideo)
        
        // Standalone Module inside Robotics Domain
        let kinematicsModule = Module(
            title: "Inverse Kinematics Math",
            desc: "Jacobian matrices and end-effector coordinates.",
            domain: robotics
        )
        modelContext.insert(kinematicsModule)
        robotics.modules.append(kinematicsModule)
        
        let forwardKinNode = Node(
            title: "Forward Kinematics Matrices",
            desc: "Master Denavit-Hartenberg (DH) parameters for 6-DoF robotic arm.",
            status: .mastered,
            priority: .normal,
            module: kinematicsModule
        )
        modelContext.insert(forwardKinNode)
        kinematicsModule.nodes.append(forwardKinNode)
        
        
        // 2. Create Computer Science Domain
        let cs = Domain(
            title: "Computer Science Foundations",
            desc: "Compilers, systems logic, memory layouts, and algorithm design.",
            colorHex: "#1FA85C",
            iconName: DomainIcon.terminal.rawValue,
            sortIndex: 1
        )
        modelContext.insert(cs)
        ContentView.seedComputerScienceCurriculum(in: cs, modelContext: modelContext)
        
        // 3. Create a Pinned Project
        let cueinProj = Project(
            title: "CueIn macOS App",
            desc: "Goal: Launch an editorial media capture toolbar for content creators.",
            status: .active,
            isPinned: true,
            domain: cs
        )
        modelContext.insert(cueinProj)
        cs.projects.append(cueinProj)
        
        let setupNode = Node(
            title: "Design Custom SwiftData Sync",
            desc: "Implement isSynced flags, isDeletedLocally flags, and transaction journals.",
            status: .active,
            priority: .normal,
            project: cueinProj
        )
        modelContext.insert(setupNode)
        cueinProj.nodes.append(setupNode)
        
        let docResource = Resource(
            title: "Supabase Swift Client Docs",
            urlString: "https://github.com/supabase-community/supabase-swift",
            resourceType: .url,
            domain: cs
        )
        modelContext.insert(docResource)
        cueinProj.resources.append(docResource)
        setupNode.resources.append(docResource)
        
        
        // 4. Create Inbox Orphans
        let orphan1 = Node(
            title: "Read about SwiftData relationships",
            desc: "Understand how @Relationship rules behave during cascade delete.",
            status: .backlog,
            isOrphan: true
        )
        modelContext.insert(orphan1)
        
        let orphan2 = Node(
            title: "Source: supabase.com/docs",
            desc: "Review edge function syntax for postgres triggers.",
            status: .backlog,
            isOrphan: true
        )
        modelContext.insert(orphan2)
        
        let resOrphan = Resource(
            title: "Supabase Database Schema Docs",
            urlString: "https://supabase.com/docs/guides/database/tables",
            resourceType: .url
        )
        modelContext.insert(resOrphan)
        orphan2.resources.append(resOrphan)
        
        try? modelContext.save()
    }

    private static func seedComputerScienceCurriculum(in cs: Domain, modelContext: ModelContext) {
        // Track 1 — algorithms
        let algorithmsTrack = Track(
            title: "Algorithms & Data Structures",
            desc: "Complexity, classic structures, and problem-solving patterns.",
            domain: cs
        )
        modelContext.insert(algorithmsTrack)
        cs.tracks.append(algorithmsTrack)

        let sortingModule = Module(
            title: "Sorting & Search",
            desc: "Divide-and-conquer sorts, binary search, and amortized analysis.",
            track: algorithmsTrack
        )
        modelContext.insert(sortingModule)
        algorithmsTrack.modules.append(sortingModule)

        insertNode(
            title: "Big-O notation cheat sheet",
            desc: "Compare growth rates for common loop and recursion patterns.",
            status: .mastered,
            module: sortingModule,
            modelContext: modelContext
        )
        insertNode(
            title: "Implement merge sort on linked lists",
            desc: "Practice stable O(n log n) sorting without random access.",
            status: .active,
            module: sortingModule,
            modelContext: modelContext
        )
        insertNode(
            title: "Binary search on answer space",
            desc: "Use monotonic predicates to search numeric ranges efficiently.",
            status: .backlog,
            priority: .critical,
            module: sortingModule,
            modelContext: modelContext
        )

        let graphsModule = Module(
            title: "Graphs & Paths",
            desc: "BFS, DFS, shortest paths, and spanning trees.",
            track: algorithmsTrack
        )
        modelContext.insert(graphsModule)
        algorithmsTrack.modules.append(graphsModule)

        insertNode(
            title: "Dijkstra with a priority queue",
            desc: "Non-negative edge weights and lazy decrease-key strategies.",
            status: .active,
            module: graphsModule,
            modelContext: modelContext
        )
        insertNode(
            title: "Topological ordering for prerequisites",
            desc: "Detect cycles while ordering course or task dependencies.",
            status: .backlog,
            module: graphsModule,
            modelContext: modelContext
        )

        // Track 2 — systems
        let systemsTrack = Track(
            title: "Systems Programming",
            desc: "Processes, memory, I/O, and how machines run your code.",
            domain: cs
        )
        modelContext.insert(systemsTrack)
        cs.tracks.append(systemsTrack)

        let osModule = Module(
            title: "Operating Systems",
            desc: "Scheduling, virtual memory, and filesystem abstractions.",
            track: systemsTrack
        )
        modelContext.insert(osModule)
        systemsTrack.modules.append(osModule)

        insertNode(
            title: "Process vs thread models",
            desc: "Context switches, shared address spaces, and synchronization primitives.",
            status: .active,
            module: osModule,
            modelContext: modelContext
        )
        insertNode(
            title: "Virtual memory and page tables",
            desc: "TLB hits, demand paging, and copy-on-write semantics.",
            status: .backlog,
            module: osModule,
            modelContext: modelContext
        )

        let networkingModule = Module(
            title: "Networking Basics",
            desc: "Sockets, HTTP, and how requests move across the stack.",
            track: systemsTrack
        )
        modelContext.insert(networkingModule)
        systemsTrack.modules.append(networkingModule)

        insertNode(
            title: "TCP handshake and flow control",
            desc: "SYN/ACK sequence, window sizes, and retransmission behavior.",
            status: .backlog,
            module: networkingModule,
            modelContext: modelContext
        )

        // Standalone module (skip if one already exists from an older seed)
        let hasStandaloneModule = cs.modules.contains { $0.track == nil && !$0.isDeletedLocally }
        if !hasStandaloneModule {
            let memoryModule = Module(
                title: "Memory Management",
                desc: "Stack vs heap, pointers, and ownership in low-level languages.",
                domain: cs
            )
            modelContext.insert(memoryModule)
            cs.modules.append(memoryModule)

            let pointerNode = insertNode(
                title: "Pointers and dynamic allocation in C",
                desc: "Malloc, free, and struct layout with alignment padding.",
                status: .mastered,
                module: memoryModule,
                modelContext: modelContext
            )

            let krBook = Resource(
                title: "The C Programming Language (K&R)",
                urlString: "https://www.read.c/kr_book.pdf",
                resourceType: .pdf,
                domain: cs
            )
            modelContext.insert(krBook)
            pointerNode.resources.append(krBook)
        }
    }

    @discardableResult
    private static func insertNode(
        title: String,
        desc: String,
        status: NodeStatus = .backlog,
        priority: NodePriority = .normal,
        module: Module,
        modelContext: ModelContext
    ) -> Node {
        let node = Node(
            title: title,
            desc: desc,
            status: status,
            priority: priority,
            module: module
        )
        modelContext.insert(node)
        module.nodes.append(node)
        return node
    }
}

#Preview {
    ContentView()
}

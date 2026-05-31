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
            .onAppear(perform: initializeMockDataIfNeeded)
            .preferredColorScheme(.light)
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
        
        let logicModule = Module(
            title: "Memory Management",
            desc: "Understand stack allocation, heap layouts, and pointer offsets.",
            domain: cs
        )
        modelContext.insert(logicModule)
        cs.modules.append(logicModule)
        
        let cPointerNode = Node(
            title: "Memory allocation and pointers in C",
            desc: "Malloc, realloc, and free operations with dynamic pointer sizing.",
            status: .mastered,
            priority: .normal,
            module: logicModule
        )
        modelContext.insert(cPointerNode)
        logicModule.nodes.append(cPointerNode)
        
        let cPdf = Resource(
            title: "The C Programming Language (K&R Second Edition)",
            urlString: "https://www.read.c/kr_book.pdf",
            resourceType: .pdf,
            domain: cs
        )
        modelContext.insert(cPdf)
        cPointerNode.resources.append(cPdf)
        
        
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
}

#Preview {
    ContentView()
}

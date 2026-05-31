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
                LibraryAttachment.self
            ])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not initialize SwiftData ModelContainer: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        #endif
    }
}

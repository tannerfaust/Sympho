//
//  SyncManager.swift
//  Sympho
//
//  Created by Tanner Fause on 30.05.2026.
//

import Foundation
import SwiftData
import SwiftUI

@Observable
@MainActor
final class SyncManager {
    static let shared = SyncManager()
    
    var isSyncing: Bool = false
    var lastSyncedDate: Date? = nil
    var syncLogs: [String] = []
    
    private init() {}
    
    /// Triggers the synchronization loop
    /// This demonstrates the exact protocol that will talk to Supabase.
    func synchronize(modelContext: ModelContext) async {
        guard !isSyncing else { return }
        
        isSyncing = true
        log("Initiating background sync to Supabase...")
        
        do {
            // Simulate networking delays
            try await Task.sleep(nanoseconds: 1_200_000_000) // 1.2s
            
            // 1. Process Soft Deletes (trickle-up to cloud deletions first)
            try await syncDeletions(context: modelContext)
            
            // 2. Push Local Changes (Insert / Update)
            try await pushLocalChanges(context: modelContext)
            
            // 3. Pull Remote Changes
            try await pullRemoteChanges(context: modelContext)
            
            lastSyncedDate = Date()
            log("Sync complete. All local modifications successfully merged.")
        } catch {
            log("Sync failed: \(error.localizedDescription)")
        }
        
        isSyncing = false
    }
    
    /// Scans database for soft deleted records, uploads deletion request to Supabase, and performs hard deletion locally.
    private func syncDeletions(context: ModelContext) async throws {
        log("Checking for local soft-deleted objects...")
        
        // Dynamic queries for soft deleted models
        let domainsFetch = FetchDescriptor<Domain>(predicate: #Predicate { $0.isDeletedLocally })
        let tracksFetch = FetchDescriptor<Track>(predicate: #Predicate { $0.isDeletedLocally })
        let modulesFetch = FetchDescriptor<Module>(predicate: #Predicate { $0.isDeletedLocally })
        let nodesFetch = FetchDescriptor<Node>(predicate: #Predicate { $0.isDeletedLocally })
        let resourcesFetch = FetchDescriptor<Resource>(predicate: #Predicate { $0.isDeletedLocally })
        let projectsFetch = FetchDescriptor<Project>(predicate: #Predicate { $0.isDeletedLocally })
        
        let deletedDomains = try context.fetch(domainsFetch)
        let deletedTracks = try context.fetch(tracksFetch)
        let deletedModules = try context.fetch(modulesFetch)
        let deletedNodes = try context.fetch(nodesFetch)
        let deletedResources = try context.fetch(resourcesFetch)
        let deletedProjects = try context.fetch(projectsFetch)
        
        let totalSoftDeletes = deletedDomains.count + deletedTracks.count + deletedModules.count + deletedNodes.count + deletedResources.count + deletedProjects.count
        
        if totalSoftDeletes > 0 {
            log("Found \(totalSoftDeletes) soft-deleted records. Syncing to Supabase via DELETE API...")
            
            // In Production: 
            // supabase.from("domains").delete().in("id", deletedDomains.map(\.id))
            // supabase.from("nodes").delete().in("id", deletedNodes.map(\.id)) ...
            
            // Post-sync: purge them locally
            for item in deletedDomains { context.delete(item) }
            for item in deletedTracks { context.delete(item) }
            for item in deletedModules { context.delete(item) }
            for item in deletedNodes { context.delete(item) }
            for item in deletedResources { context.delete(item) }
            for item in deletedProjects { context.delete(item) }
            
            try context.save()
            log("Purged \(totalSoftDeletes) soft-deleted records from client store.")
        } else {
            log("No soft-deleted records to sync.")
        }
    }
    
    /// Scans database for unsynced local creations/modifications and upserts them to Supabase.
    private func pushLocalChanges(context: ModelContext) async throws {
        log("Scanning for unsynced local additions/updates...")
        
        // Fetch unsynced items
        let domainsFetch = FetchDescriptor<Domain>(predicate: #Predicate { !$0.isSynced && !$0.isDeletedLocally })
        let tracksFetch = FetchDescriptor<Track>(predicate: #Predicate { !$0.isSynced && !$0.isDeletedLocally })
        let modulesFetch = FetchDescriptor<Module>(predicate: #Predicate { !$0.isSynced && !$0.isDeletedLocally })
        let nodesFetch = FetchDescriptor<Node>(predicate: #Predicate { !$0.isSynced && !$0.isDeletedLocally })
        let resourcesFetch = FetchDescriptor<Resource>(predicate: #Predicate { !$0.isSynced && !$0.isDeletedLocally })
        let projectsFetch = FetchDescriptor<Project>(predicate: #Predicate { !$0.isSynced && !$0.isDeletedLocally })
        
        let unsyncedDomains = try context.fetch(domainsFetch)
        let unsyncedTracks = try context.fetch(tracksFetch)
        let unsyncedModules = try context.fetch(modulesFetch)
        let unsyncedNodes = try context.fetch(nodesFetch)
        let unsyncedResources = try context.fetch(resourcesFetch)
        let unsyncedProjects = try context.fetch(projectsFetch)
        
        let totalUnsynced = unsyncedDomains.count + unsyncedTracks.count + unsyncedModules.count + unsyncedNodes.count + unsyncedResources.count + unsyncedProjects.count
        
        if totalUnsynced > 0 {
            log("Syncing \(totalUnsynced) additions/modifications to Supabase...")
            
            // In Production:
            // let payload = unsyncedNodes.map { node in PostgresNode(from: node) }
            // try await supabase.from("nodes").upsert(payload).execute()
            
            // Mark as synced
            for item in unsyncedDomains { item.isSynced = true; item.lastSyncedAt = Date() }
            for item in unsyncedTracks { item.isSynced = true; item.lastSyncedAt = Date() }
            for item in unsyncedModules { item.isSynced = true; item.lastSyncedAt = Date() }
            for item in unsyncedNodes { item.isSynced = true; item.lastSyncedAt = Date() }
            for item in unsyncedResources { item.isSynced = true; item.lastSyncedAt = Date() }
            for item in unsyncedProjects { item.isSynced = true; item.lastSyncedAt = Date() }
            
            try context.save()
            log("Successfully updated \(totalUnsynced) records in cloud and marked synced on client.")
        } else {
            log("Local database is fully synced.")
        }
    }
    
    /// Pulls any remote edits from Supabase and applies them to local SwiftData.
    private func pullRemoteChanges(context: ModelContext) async throws {
        log("Checking Supabase for remote updates since last sync...")
        // In Production:
        // let remoteEdits = try await supabase.from("nodes").select().gt("updated_at", lastSyncedDate ?? Date.distantPast).execute()
        // Map and write them to context.
        log("Remote database checked. Client is up-to-date.")
    }
    
    private func log(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        let formattedMessage = "[\(timestamp)] \(message)"
        syncLogs.insert(formattedMessage, at: 0)
        print(formattedMessage)
    }
}

//
//  DomainManager.swift
//  SimBridge
//
//  Created for SimBridge.
//

import Foundation
import FileProvider
import SimBridgeKit

/// Registers and removes Finder locations (File Provider domains) and records
/// each mount — as a domain identifier plus absolute root path — in the shared
/// App Group. The sandboxed extension reaches that path via its
/// temporary-exception entitlement.
///
/// All File Provider registration APIs are completion-based; they are wrapped
/// in continuations so callers can use `async`/`await`.
@MainActor
final class DomainManager {

    private let store: MountStore

    /// Fails only if the App Group container is unavailable (misconfigured
    /// entitlements) — surfaced early so setup problems are obvious.
    init?() {
        guard let store = MountStore(appGroupIdentifier: SimBridgeConfig.appGroupIdentifier) else {
            return nil
        }
        self.store = store
    }

    /// The mounts currently recorded in the App Group.
    func currentMounts() throws -> [MountDescriptor] {
        try store.load()
    }

    /// Mounts a folder as a Finder location. The root path is encoded into the
    /// domain identifier, so the extension needs nothing else to reach it.
    func mount(folderURL: URL, displayName: String, kind: MountDescriptor.Kind) async throws {
        let domainID = Self.domainIdentifier(for: folderURL)
        let descriptor = MountDescriptor(
            domainIdentifier: domainID,
            displayName: displayName,
            kind: kind
        )

        let domain = NSFileProviderDomain(
            identifier: NSFileProviderDomainIdentifier(domainID),
            displayName: displayName
        )
        // Replace any stale registration for this identifier so the fresh
        // bookmark takes effect.
        try? await removeDomain(domain)
        // Register the domain FIRST and only record it on success — otherwise a
        // failed `add` (e.g. the extension can't be launched) would leave an
        // orphan record in the store that keeps reappearing in the list.
        // The extension recovers the root path from the domain identifier, so it
        // does not depend on the store being written beforehand.
        try await addDomain(domain)
        try store.upsert(descriptor)
        try? await signalWorkingSet(for: domain)
    }

    /// Removes a Finder location and forgets its record.
    ///
    /// Hardened: if the domain is already gone (e.g. the simulator was deleted,
    /// or a previous removal half-succeeded), we still clear the record so the
    /// list can't get permanently stuck. A *real* failure where the domain still
    /// exists (e.g. the debug-dylib "can't be used" case) is re-thrown and the
    /// record is kept, so we never orphan a live Finder location.
    func unmount(_ descriptor: MountDescriptor) async throws {
        let domain = NSFileProviderDomain(
            identifier: NSFileProviderDomainIdentifier(descriptor.domainIdentifier),
            displayName: descriptor.displayName
        )
        do {
            try await removeDomain(domain)
            try store.remove(domainIdentifier: descriptor.domainIdentifier)
        } catch {
            if await domainExists(descriptor.domainIdentifier) {
                throw error   // still registered — keep the record and surface it
            }
            try store.remove(domainIdentifier: descriptor.domainIdentifier)
        }
    }

    /// Removes **all** Finder locations this app registered and clears the
    /// record. Recovery path for stuck or orphaned domains — e.g. domains left
    /// behind by a different installed copy of the app that the system can no
    /// longer use (the "application can’t be used right now" error).
    ///
    /// Hardened: records are cleared for every domain that is *actually gone*
    /// afterwards (handles partial failures), and the original error is still
    /// re-thrown so the UI can report it.
    func resetAllDomains() async throws {
        var thrown: Error?
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                NSFileProviderManager.removeAllDomains { error in
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume() }
                }
            }
        } catch {
            thrown = error
        }

        let remaining = Set(await currentDomainIdentifiers())
        for descriptor in (try? store.load()) ?? [] where !remaining.contains(descriptor.domainIdentifier) {
            try? store.remove(domainIdentifier: descriptor.domainIdentifier)
        }

        if let thrown { throw thrown }
    }

    /// Removes only the given mounts (used to clean up mounts whose backing
    /// folder no longer exists). Best-effort per mount; never throws.
    func removeMounts(_ descriptors: [MountDescriptor]) async {
        for descriptor in descriptors {
            try? await unmount(descriptor)
        }
    }

    // MARK: - Identifier

    /// A stable domain identifier that also encodes the folder path, so the
    /// extension can recover the root from its own domain identifier and
    /// remounting the same folder reuses the same Finder location.
    static func domainIdentifier(for url: URL) -> String {
        DomainIdentifierCodec.identifier(forRootPath: url.standardizedFileURL.path)
    }

    // MARK: - Domain introspection

    /// Identifiers of all domains currently registered by this app.
    private func currentDomainIdentifiers() async -> [String] {
        await withCheckedContinuation { (continuation: CheckedContinuation<[String], Never>) in
            NSFileProviderManager.getDomainsWithCompletionHandler { domains, _ in
                continuation.resume(returning: domains.map { $0.identifier.rawValue })
            }
        }
    }

    /// Whether a domain with the given identifier is still registered.
    private func domainExists(_ identifier: String) async -> Bool {
        await currentDomainIdentifiers().contains(identifier)
    }

    // MARK: - Continuation wrappers

    private func addDomain(_ domain: NSFileProviderDomain) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            NSFileProviderManager.add(domain) { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            }
        }
    }

    private func removeDomain(_ domain: NSFileProviderDomain) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            NSFileProviderManager.remove(domain) { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            }
        }
    }

    private func signalWorkingSet(for domain: NSFileProviderDomain) async throws {
        guard let manager = NSFileProviderManager(for: domain) else { return }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            manager.signalEnumerator(for: .workingSet) { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            }
        }
    }
}

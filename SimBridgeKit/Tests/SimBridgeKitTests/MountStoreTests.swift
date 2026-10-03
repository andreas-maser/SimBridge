//
//  MountStoreTests.swift
//  SimBridgeKitTests
//

import Testing
import Foundation
@testable import SimBridgeKit

@Suite("MountStore")
struct MountStoreTests {

    /// A `MountStore` backed by a throwaway UserDefaults suite (unique per test).
    private func makeStore() -> (store: MountStore, suite: String) {
        let suite = "test.simbridge.\(UUID().uuidString)"
        return (MountStore(appGroupIdentifier: suite)!, suite)
    }

    private func cleanUp(_ suite: String) {
        UserDefaults().removePersistentDomain(forName: suite)
    }

    private func descriptor(_ id: String, _ name: String = "Name") -> MountDescriptor {
        MountDescriptor(domainIdentifier: id, displayName: name, kind: .simulator)
    }

    @Test("An empty store loads an empty list")
    func emptyLoad() throws {
        let (store, suite) = makeStore(); defer { cleanUp(suite) }
        #expect(try store.load().isEmpty)
    }

    @Test("Upsert then load returns the descriptor")
    func upsertLoad() throws {
        let (store, suite) = makeStore(); defer { cleanUp(suite) }
        try store.upsert(descriptor("mount-a"))
        let loaded = try store.load()
        #expect(loaded.count == 1)
        #expect(loaded.first?.domainIdentifier == "mount-a")
    }

    @Test("Upsert with the same identifier replaces instead of duplicating")
    func upsertReplaces() throws {
        let (store, suite) = makeStore(); defer { cleanUp(suite) }
        try store.upsert(descriptor("mount-a", "Old"))
        try store.upsert(descriptor("mount-a", "New"))
        let loaded = try store.load()
        #expect(loaded.count == 1)
        #expect(loaded.first?.displayName == "New")
    }

    @Test("Remove deletes only the matching mount")
    func remove() throws {
        let (store, suite) = makeStore(); defer { cleanUp(suite) }
        try store.upsert(descriptor("mount-a"))
        try store.upsert(descriptor("mount-b"))
        try store.remove(domainIdentifier: "mount-a")
        let loaded = try store.load()
        #expect(loaded.count == 1)
        #expect(loaded.first?.domainIdentifier == "mount-b")
    }

    @Test("Lookup by identifier finds the right mount, nil otherwise")
    func lookup() throws {
        let (store, suite) = makeStore(); defer { cleanUp(suite) }
        try store.upsert(descriptor("mount-x", "X"))
        #expect(try store.mount(forDomainIdentifier: "mount-x")?.displayName == "X")
        #expect(try store.mount(forDomainIdentifier: "nope") == nil)
    }
}

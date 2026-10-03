//
//  MountStore.swift
//  SimBridgeKit
//
//  Created for SimBridge.
//

import Foundation

/// Describes one mounted sandbox, kept for the **app's own** list of active
/// mounts. The extension does not read this: it recovers the root path from the
/// self-describing domain identifier (see `DomainIdentifierCodec`).
public struct MountDescriptor: Codable, Hashable, Sendable {

    public enum Kind: String, Codable, Sendable {
        case simulator
        case device
    }

    /// Stable domain identifier that also encodes the root path.
    public let domainIdentifier: String

    /// Human-readable name shown in the app's list / Finder sidebar.
    public let displayName: String

    /// Where the files come from.
    public let kind: Kind

    public init(domainIdentifier: String, displayName: String, kind: Kind) {
        self.domainIdentifier = domainIdentifier
        self.displayName = displayName
        self.kind = kind
    }
}

/// Reads and writes the list of mounts in the shared App Group **UserDefaults**.
///
/// UserDefaults (not a raw file) is used on purpose: a File Provider extension
/// runs under a separate persona and cannot read owner-only files the app
/// writes into the group container. Access through `cfprefsd` (which
/// `UserDefaults` uses) is mediated correctly across that persona boundary.
public struct MountStore {

    private let defaults: UserDefaults
    private let key = "mounts.v1"

    /// - Parameter appGroupIdentifier: e.g. `group.de.andreasmaser.SimBridge`.
    /// - Returns: `nil` if the App Group suite is unavailable (misconfigured
    ///   entitlements) — a fail-fast signal during setup.
    public init?(appGroupIdentifier: String) {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            return nil
        }
        self.defaults = defaults
    }

    /// Loads all mounts. Empty when nothing is stored or the data can't decode.
    public func load() throws -> [MountDescriptor] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([MountDescriptor].self, from: data)) ?? []
    }

    /// Finds a single mount by its domain identifier.
    public func mount(forDomainIdentifier identifier: String) throws -> MountDescriptor? {
        try load().first { $0.domainIdentifier == identifier }
    }

    /// Adds or replaces a mount (matched by domain identifier).
    public func upsert(_ descriptor: MountDescriptor) throws {
        var mounts = try load()
        mounts.removeAll { $0.domainIdentifier == descriptor.domainIdentifier }
        mounts.append(descriptor)
        try save(mounts)
    }

    /// Removes a mount by its domain identifier.
    public func remove(domainIdentifier: String) throws {
        var mounts = try load()
        mounts.removeAll { $0.domainIdentifier == domainIdentifier }
        try save(mounts)
    }

    private func save(_ mounts: [MountDescriptor]) throws {
        let data = try JSONEncoder().encode(mounts)
        defaults.set(data, forKey: key)
    }
}

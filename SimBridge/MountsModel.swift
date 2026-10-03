//
//  MountsModel.swift
//  SimBridge
//
//  Created for SimBridge.
//

import Foundation
import Observation
import AppKit
import os
import SimBridgeKit

private let log = Logger(subsystem: "de.andreasmaser.SimBridge", category: "app")

/// Drives the control center: discovers Simulator apps, mounts/unmounts them as
/// Finder locations, and bridges UI actions to `DomainManager`.
@MainActor
@Observable
final class MountsModel {

    /// Currently mounted Finder locations.
    private(set) var mounts: [MountDescriptor] = []

    /// Domain identifiers whose backing folder no longer exists on disk — e.g.
    /// the simulator was deleted or the app was uninstalled. Recomputed on every
    /// `reload()` so the UI can mark them and offer a one-click cleanup.
    private(set) var unavailableDomainIdentifiers: Set<String> = []

    /// Mountable locations discovered on disk (app data, app groups, local storage).
    /// Grouping/sorting is derived once here (via `didSet`) rather than in the
    /// view's `body`, which is evaluated frequently.
    private(set) var mountables: [SimulatorMountable] = [] {
        didSet { deviceGroups = Self.group(mountables) }
    }

    /// `mountables` grouped by device and sorted (booted first, then by name).
    /// Cached so the O(n log n) locale-aware sort doesn't run on every redraw.
    private(set) var deviceGroups: [DeviceGroup] = []

    /// One simulator device with its mountable sources.
    struct DeviceGroup: Identifiable, Hashable {
        let udid: String
        let name: String
        let runtime: String
        let isBooted: Bool
        let items: [SimulatorMountable]
        var id: String { udid }
    }

    private static func group(_ mountables: [SimulatorMountable]) -> [DeviceGroup] {
        Dictionary(grouping: mountables, by: \.deviceUDID)
            .map { udid, items in
                DeviceGroup(udid: udid, name: items[0].deviceName, runtime: items[0].runtime,
                            isBooted: items[0].deviceIsBooted, items: items)
            }
            .sorted { lhs, rhs in
                if lhs.isBooted != rhs.isBooted { return lhs.isBooted }   // booted first
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
    }

    /// Whether SimBridge has been granted access to the Simulator folder.
    private(set) var hasSimulatorAccess = false

    var errorMessage: String?

    @ObservationIgnored private let manager: DomainManager?
    @ObservationIgnored private let access = SimulatorAccess()
    @ObservationIgnored private let watcher = MountWatcher()

    init() {
        manager = DomainManager()
        if manager == nil {
            errorMessage = String(localized: "App Group unavailable — check the entitlements (group.de.andreasmaser.SimBridge).")
        }
        access.restore()
        hasSimulatorAccess = access.hasAccess
        reload()
        discover()
    }

    /// Set of domain identifiers already mounted, for quick lookup in the UI.
    var mountedDomainIdentifiers: Set<String> {
        Set(mounts.map(\.domainIdentifier))
    }

    func domainIdentifier(for mountable: SimulatorMountable) -> String {
        DomainIdentifierCodec.identifier(forRootPath: mountable.rootPath)
    }

    // MARK: - Loading

    func reload() {
        guard let manager else { return }
        do {
            mounts = try manager.currentMounts()
            recomputeAvailability()
            watcher.update(mounts: mounts)   // keep live-update watching in sync
        } catch {
            errorMessage = String(localized: "Couldn’t load mounts: \(error.localizedDescription)")
        }
    }

    /// Flags mounts whose root folder is gone (deleted simulator / uninstalled app).
    private func recomputeAvailability() {
        let fileManager = FileManager.default
        unavailableDomainIdentifiers = Set(
            mounts.filter { mount in
                guard let root = DomainIdentifierCodec.rootPath(forIdentifier: mount.domainIdentifier) else {
                    return true   // undecodable → treat as unavailable
                }
                return !fileManager.fileExists(atPath: root)
            }.map(\.domainIdentifier)
        )
    }

    /// Whether a mount's backing folder still exists.
    func isAvailable(_ mount: MountDescriptor) -> Bool {
        !unavailableDomainIdentifiers.contains(mount.domainIdentifier)
    }

    /// `true` when at least one mount points to a folder that no longer exists.
    var hasUnavailableMounts: Bool { !unavailableDomainIdentifiers.isEmpty }

    /// Re-reads the Simulator catalog off the main actor.
    func discover() {
        guard let devicesDir = access.devicesDirectory else {
            mountables = []
            log.info("discover: kein devicesDirectory (kein Zugriff)")
            return
        }
        log.info("discover in \(devicesDir.path, privacy: .public)")
        Task {
            let found = await Task.detached(priority: .userInitiated) {
                SimulatorCatalog.allMountables(inDevicesDirectory: devicesDir)
            }.value
            mountables = found
            log.info("discover: \(found.count) Quellen gefunden")
        }
    }

    // MARK: - Access

    func requestSimulatorAccess() {
        if access.requestAccess() {
            hasSimulatorAccess = true
            discover()
        }
    }

    // MARK: - Mounting

    /// Mounts a discovered location as a Finder location.
    func mount(_ mountable: SimulatorMountable) {
        guard let manager else { return }
        let url = URL(fileURLWithPath: mountable.rootPath, isDirectory: true)
        Task {
            do {
                try await manager.mount(folderURL: url, displayName: mountable.mountName, kind: .simulator)
                reload()
            } catch {
                errorMessage = String(localized: "Mounting failed: \(error.localizedDescription)")
            }
        }
    }

    func unmount(_ descriptor: MountDescriptor) {
        guard let manager else { return }
        Task {
            do {
                try await manager.unmount(descriptor)
                reload()
            } catch {
                errorMessage = String(localized: "Removing failed: \(error.localizedDescription)")
            }
        }
    }

    /// Removes every Finder location this app registered. Recovery action for
    /// stuck/orphaned domains (e.g. left over from another installed copy).
    func resetAllMounts() {
        guard let manager else { return }
        Task {
            do {
                try await manager.resetAllDomains()
                reload()
            } catch {
                errorMessage = String(localized: "Reset failed: \(error.localizedDescription)")
            }
        }
    }

    /// Removes only the mounts whose backing folder no longer exists.
    func removeUnavailableMounts() {
        guard let manager else { return }
        let stale = mounts.filter { unavailableDomainIdentifiers.contains($0.domainIdentifier) }
        guard !stale.isEmpty else { return }
        Task {
            await manager.removeMounts(stale)
            reload()
        }
    }
}

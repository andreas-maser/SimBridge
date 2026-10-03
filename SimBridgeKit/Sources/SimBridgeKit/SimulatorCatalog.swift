//
//  SimulatorCatalog.swift
//  SimBridgeKit
//
//  Created for SimBridge.
//

import Foundation

/// One iOS Simulator device found on disk.
public struct SimulatorDevice: Identifiable, Hashable, Sendable {
    public let udid: String
    public let name: String
    /// Pretty runtime, e.g. "iOS 18.2".
    public let runtime: String
    /// `true` if the Simulator is currently booted (CoreSimulator state 3).
    public let isBooted: Bool
    public var id: String { udid }
}

/// A mountable location inside a Simulator — an app's data container, one of its
/// App Group containers, or the local "On My iPhone" storage.
public struct SimulatorMountable: Identifiable, Hashable, Sendable {

    public enum Kind: String, Sendable {
        case appData        // Data/Application/<GUID> (Documents, Library, tmp)
        case appGroup       // Shared/AppGroup/<GUID> (e.g. a SwiftData store)
        case localStorage   // "On My iPhone" local Files storage
    }

    public let deviceUDID: String
    public let deviceName: String
    public let runtime: String
    public let deviceIsBooted: Bool

    public let kind: Kind
    /// Primary label, e.g. "Trackers" or "Auf meinem iPhone".
    public let title: String
    /// Secondary label, e.g. the bundle id or group id.
    public let subtitle: String
    /// Name used for the Finder location.
    public let mountName: String
    /// Absolute path of the folder to mount.
    public let rootPath: String

    public var id: String { "\(deviceUDID)/\(rootPath)" }
}

/// Reads the CoreSimulator `Devices` directory and lists devices and their
/// mountable locations. Pure filesystem work over a granted directory; no
/// `simctl` needed.
public enum SimulatorCatalog {

    private static let localStorageGroupID = "group.com.apple.FileProvider.LocalStorage"

    /// Lists all devices found under the given `Devices` directory.
    public static func devices(inDevicesDirectory devicesDir: URL) -> [SimulatorDevice] {
        childDirectories(of: devicesDir).compactMap { device(atDeviceDirectory: $0) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// All mountable locations across all devices.
    public static func allMountables(inDevicesDirectory devicesDir: URL) -> [SimulatorMountable] {
        devices(inDevicesDirectory: devicesDir).flatMap { device in
            mountables(for: device, inDevicesDirectory: devicesDir)
        }
    }

    /// Mountable locations for one device: user apps' data containers, their
    /// matching App Group containers, and the local "On My iPhone" storage.
    public static func mountables(for device: SimulatorDevice, inDevicesDirectory devicesDir: URL) -> [SimulatorMountable] {
        let containers = devicesDir
            .appendingPathComponent(device.udid)
            .appendingPathComponent("data/Containers")

        var result: [SimulatorMountable] = []

        // --- Installed user apps → data containers -----------------------
        let displayNames = installedBundleDisplayNames(in: containers)   // bundleID → name
        let dataContainers = dataContainerPaths(in: containers)          // bundleID → path
        var appOrgTokens: Set<String> = []

        for (bundleID, name) in displayNames.sorted(by: { $0.value.localizedStandardCompare($1.value) == .orderedAscending }) {
            guard let path = dataContainers[bundleID] else { continue }
            result.append(make(device, kind: .appData, title: name, subtitle: bundleID,
                               mountName: "\(name) — \(device.name)", rootPath: path))
            if let token = orgToken(for: bundleID) { appOrgTokens.insert(token) }
        }

        // --- App Group containers that belong to those apps --------------
        let groups = appGroupContainers(in: containers)                  // groupID → path
        for (groupID, path) in groups.sorted(by: { $0.key < $1.key }) {
            guard appOrgTokens.contains(where: { groupID.contains($0) }) else { continue }
            result.append(make(device, kind: .appGroup, title: "App Group", subtitle: groupID,
                               mountName: "\(groupID) — \(device.name)", rootPath: path))
        }

        // --- "On My iPhone" local storage --------------------------------
        if let localGroup = groups[localStorageGroupID] {
            let storage = "\(localGroup)/File Provider Storage"
            if FileManager.default.fileExists(atPath: storage) {
                result.append(make(device, kind: .localStorage, title: "On My iPhone",
                                   subtitle: "Local file storage",
                                   mountName: "On My iPhone — \(device.name)", rootPath: storage))
            }
        }

        return result
    }

    // MARK: - Building blocks

    private static func make(
        _ device: SimulatorDevice, kind: SimulatorMountable.Kind,
        title: String, subtitle: String, mountName: String, rootPath: String
    ) -> SimulatorMountable {
        SimulatorMountable(
            deviceUDID: device.udid, deviceName: device.name, runtime: device.runtime,
            deviceIsBooted: device.isBooted, kind: kind, title: title, subtitle: subtitle,
            mountName: mountName, rootPath: rootPath
        )
    }

    /// bundleID → display name, for apps the user actually installed (those with
    /// a bundle in Bundle/Application). Filters out system daemons.
    private static func installedBundleDisplayNames(in containers: URL) -> [String: String] {
        var names: [String: String] = [:]
        let bundleApps = containers.appendingPathComponent("Bundle/Application")
        for guidDir in childDirectories(of: bundleApps) {
            guard let appBundle = childDirectories(of: guidDir).first(where: { $0.pathExtension == "app" }),
                  let info = plist(at: appBundle.appendingPathComponent("Info.plist")),
                  let bundleID = info["CFBundleIdentifier"] as? String else {
                continue
            }
            names[bundleID] = (info["CFBundleDisplayName"] as? String)
                ?? (info["CFBundleName"] as? String)
                ?? bundleID
        }
        return names
    }

    /// bundleID → data container path.
    private static func dataContainerPaths(in containers: URL) -> [String: String] {
        var map: [String: String] = [:]
        let dataApps = containers.appendingPathComponent("Data/Application")
        for guidDir in childDirectories(of: dataApps) {
            let metadata = guidDir.appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist")
            if let meta = plist(at: metadata), let bundleID = meta["MCMMetadataIdentifier"] as? String {
                map[bundleID] = guidDir.path
            }
        }
        return map
    }

    /// groupID → app group container path.
    private static func appGroupContainers(in containers: URL) -> [String: String] {
        var map: [String: String] = [:]
        let groupApps = containers.appendingPathComponent("Shared/AppGroup")
        for guidDir in childDirectories(of: groupApps) {
            let metadata = guidDir.appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist")
            if let meta = plist(at: metadata), let groupID = meta["MCMMetadataIdentifier"] as? String {
                map[groupID] = guidDir.path
            }
        }
        return map
    }

    /// A token from the bundle id used to match its app groups, e.g.
    /// "de.andreasmaser.Trackers" → "de.andreasmaser".
    private static func orgToken(for bundleID: String) -> String? {
        let parts = bundleID.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        return parts.dropLast().joined(separator: ".")
    }

    private static func device(atDeviceDirectory dir: URL) -> SimulatorDevice? {
        guard let info = plist(at: dir.appendingPathComponent("device.plist")),
              let name = info["name"] as? String else {
            return nil
        }
        let runtimeID = (info["runtime"] as? String) ?? ""
        let isBooted = (info["state"] as? Int) == 3   // CoreSimulator state 3 == Booted
        return SimulatorDevice(udid: dir.lastPathComponent, name: name,
                               runtime: prettyRuntime(runtimeID), isBooted: isBooted)
    }

    /// "com.apple.CoreSimulator.SimRuntime.iOS-18-2" → "iOS 18.2".
    private static func prettyRuntime(_ identifier: String) -> String {
        guard let last = identifier.split(separator: ".").last else { return identifier }
        let parts = last.split(separator: "-")
        guard let os = parts.first else { return String(last) }
        let version = parts.dropFirst().joined(separator: ".")
        return version.isEmpty ? String(os) : "\(os) \(version)"
    }

    private static func childDirectories(of dir: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
        )) ?? []
    }

    private static func plist(at url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url),
              let object = try? PropertyListSerialization.propertyList(from: data, format: nil) else {
            return nil
        }
        return object as? [String: Any]
    }
}

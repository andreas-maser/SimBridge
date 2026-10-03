//
//  SimulatorCatalogTests.swift
//  SimBridgeKitTests
//

import Testing
import Foundation
@testable import SimBridgeKit

@Suite("SimulatorCatalog")
struct SimulatorCatalogTests {

    private func writePlist(_ dict: [String: Any], to url: URL) throws {
        let data = try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0)
        try data.write(to: url)
    }

    /// Builds a minimal CoreSimulator `Devices` tree: one booted device with one
    /// installed user app, its App Group container, and the local "On My iPhone"
    /// storage. Mirrors the on-disk layout `SimulatorCatalog` reads.
    private func makeDevicesTree() throws -> URL {
        let fm = FileManager.default
        let devices = fm.temporaryDirectory.appendingPathComponent("SimCatalogTest-\(UUID().uuidString)")
        let device = devices.appendingPathComponent("C2164519-B3AB-48A9-94A2-19EAD59CC47F")
        let containers = device.appendingPathComponent("data/Containers")
        let metaName = ".com.apple.mobile_container_manager.metadata.plist"

        func mkdir(_ u: URL) throws { try fm.createDirectory(at: u, withIntermediateDirectories: true) }

        // device.plist — name, runtime, booted state.
        try mkdir(device)
        try writePlist([
            "name": "iPhone 16 Pro",
            "runtime": "com.apple.CoreSimulator.SimRuntime.iOS-18-2",
            "state": 3   // 3 == Booted
        ], to: device.appendingPathComponent("device.plist"))

        // Installed app bundle → CFBundleIdentifier + display name.
        let appBundle = containers.appendingPathComponent("Bundle/Application/AAAA/MyApp.app")
        try mkdir(appBundle)
        try writePlist([
            "CFBundleIdentifier": "de.andreasmaser.Trackers",
            "CFBundleDisplayName": "Trackers"
        ], to: appBundle.appendingPathComponent("Info.plist"))

        // Data container for that app.
        let dataDir = containers.appendingPathComponent("Data/Application/BBBB")
        try mkdir(dataDir)
        try writePlist(["MCMMetadataIdentifier": "de.andreasmaser.Trackers"],
                       to: dataDir.appendingPathComponent(metaName))

        // App Group container belonging to the same org.
        let groupDir = containers.appendingPathComponent("Shared/AppGroup/CCCC")
        try mkdir(groupDir)
        try writePlist(["MCMMetadataIdentifier": "group.de.andreasmaser.Trackers"],
                       to: groupDir.appendingPathComponent(metaName))

        // Local "On My iPhone" storage (needs the "File Provider Storage" subfolder).
        let localDir = containers.appendingPathComponent("Shared/AppGroup/DDDD")
        try mkdir(localDir.appendingPathComponent("File Provider Storage"))
        try writePlist(["MCMMetadataIdentifier": "group.com.apple.FileProvider.LocalStorage"],
                       to: localDir.appendingPathComponent(metaName))

        return devices
    }

    @Test("Discovers the device with name, runtime and boot state")
    func device() throws {
        let devices = try makeDevicesTree()
        defer { try? FileManager.default.removeItem(at: devices) }

        let found = SimulatorCatalog.devices(inDevicesDirectory: devices)
        #expect(found.count == 1)
        #expect(found.first?.name == "iPhone 16 Pro")
        #expect(found.first?.runtime == "iOS 18.2")
        #expect(found.first?.isBooted == true)
    }

    @Test("Discovers app data, app group and local storage as mountables")
    func mountables() throws {
        let devices = try makeDevicesTree()
        defer { try? FileManager.default.removeItem(at: devices) }

        let all = SimulatorCatalog.allMountables(inDevicesDirectory: devices)
        let kinds = Set(all.map(\.kind))
        #expect(kinds.contains(.appData))
        #expect(kinds.contains(.appGroup))
        #expect(kinds.contains(.localStorage))

        let appData = all.first { $0.kind == .appData }
        #expect(appData?.title == "Trackers")
        #expect(appData?.subtitle == "de.andreasmaser.Trackers")

        let appGroup = all.first { $0.kind == .appGroup }
        #expect(appGroup?.subtitle == "group.de.andreasmaser.Trackers")
    }

    @Test("An empty devices directory yields nothing")
    func emptyDirectory() throws {
        let fm = FileManager.default
        let empty = fm.temporaryDirectory.appendingPathComponent("SimCatalogEmpty-\(UUID().uuidString)")
        try fm.createDirectory(at: empty, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: empty) }

        #expect(SimulatorCatalog.devices(inDevicesDirectory: empty).isEmpty)
        #expect(SimulatorCatalog.allMountables(inDevicesDirectory: empty).isEmpty)
    }
}

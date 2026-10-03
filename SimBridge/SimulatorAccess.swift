//
//  SimulatorAccess.swift
//  SimBridge
//
//  Created for SimBridge.
//

import Foundation
import AppKit
import os

private let log = Logger(subsystem: "de.andreasmaser.SimBridge", category: "app")

/// Manages the app's access to the CoreSimulator `Devices` directory.
///
/// The sandboxed app can't read that folder until the user grants it once via
/// the open panel. The grant is persisted as a security-scoped bookmark in the
/// app's own defaults and re-resolved on launch. (This is the app reading its
/// *own* bookmark — unaffected by the extension's persona problem.)
@MainActor
final class SimulatorAccess {

    private let bookmarkKey = "coreSimulatorDevicesBookmark"

    /// The granted `Devices` directory, with access currently open, or `nil`.
    private(set) var devicesDirectory: URL?

    var hasAccess: Bool { devicesDirectory != nil }

    /// Default location of the Simulator devices directory.
    static var defaultDevicesDirectory: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Developer/CoreSimulator/Devices", isDirectory: true)
    }

    /// Parent of `Devices` — the panel opens here so "Devices" is visible and
    /// selectable in the list (rather than dropping the user inside the cryptic
    /// per-device UDID folders).
    static var defaultCoreSimulatorDirectory: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Developer/CoreSimulator", isDirectory: true)
    }

    /// Re-resolves a previously granted folder on launch.
    func restore() {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return }
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ), url.startAccessingSecurityScopedResource() else {
            log.error("restore: Bookmark konnte nicht aufgelöst/geöffnet werden")
            return
        }
        devicesDirectory = resolvedDevicesDirectory(from: url)
        log.info("restore: granted=\(url.path, privacy: .public) devicesDir=\(self.devicesDirectory?.path ?? "nil", privacy: .public)")
    }

    /// Shows an open panel for the user to grant access. Returns `true` on grant.
    func requestAccess() -> Bool {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = Self.defaultCoreSimulatorDirectory
        panel.prompt = String(localized: "Grant Access")
        panel.message = String(localized: "SimBridge needs access to the “Devices” folder to find your simulators.")
        panel.accessoryView = Self.makeInstructionView()
        panel.isAccessoryViewDisclosed = true

        guard panel.runModal() == .OK, let url = panel.url else { return false }

        if let data = try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            UserDefaults.standard.set(data, forKey: bookmarkKey)
        }
        _ = url.startAccessingSecurityScopedResource()
        devicesDirectory = resolvedDevicesDirectory(from: url)
        log.info("granted=\(url.path, privacy: .public) devicesDir=\(self.devicesDirectory?.path ?? "nil", privacy: .public)")
        return true
    }

    /// A prominent, clearly readable instruction shown inside the open panel,
    /// so users know they must pick the "Devices" folder.
    private static func makeInstructionView() -> NSView {
        let title = NSTextField(labelWithString: String(localized: "Select the “Devices” folder"))
        title.font = .boldSystemFont(ofSize: 15)
        title.alignment = .center

        let body = NSTextField(wrappingLabelWithString: String(localized: "Click the “Devices” folder below once, then click “Grant Access”."))
        body.font = .systemFont(ofSize: 12)
        body.textColor = .secondaryLabelColor
        body.alignment = .center
        body.preferredMaxLayoutWidth = 460

        let stack = NSStackView(views: [title, body])
        stack.orientation = .vertical
        stack.spacing = 4
        stack.alignment = .centerX
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 20, bottom: 14, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            container.widthAnchor.constraint(equalToConstant: 500)
        ])
        return container
    }

    /// Accepts either the `Devices` folder or its `CoreSimulator` parent and
    /// returns the actual `Devices` directory.
    private func resolvedDevicesDirectory(from url: URL) -> URL {
        if url.lastPathComponent == "Devices" { return url }
        let candidate = url.appendingPathComponent("Devices", isDirectory: true)
        return FileManager.default.fileExists(atPath: candidate.path) ? candidate : url
    }
}

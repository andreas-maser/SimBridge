//
//  MountWatcher.swift
//  SimBridge
//
//  Created for SimBridge.
//

import Foundation
import FileProvider
import os
import SimBridgeKit

private let watchLog = Logger(subsystem: "de.andreasmaser.SimBridge", category: "app")

/// Watches the mounted folders and asks the File Provider system to refresh the
/// Finder when they change on disk.
///
/// The watching lives in the **app**: FSEvents is blocked inside the sandboxed
/// File Provider extension for the CoreSimulator path — and even FSEvents in the
/// app proved unreliable for the user-granted folder. A GCD `DispatchSource`
/// file-system-object monitor (VNODE) on each mount root works under the sandbox
/// (the app has read access via the security-scoped grant). `signalEnumerator`
/// may be called for a domain from the app too.
///
/// Note: this monitors each mount's **root** directory (new/removed/renamed
/// entries there). That covers the common case of files appearing in a mounted
/// folder; deep nested changes refresh when that folder is (re)opened.
final class MountWatcher {

    private struct Monitor {
        let descriptor: MountDescriptor
        let source: DispatchSourceFileSystemObject
    }

    private var monitors: [Monitor] = []
    private let queue = DispatchQueue(label: "de.andreasmaser.SimBridge.mountwatcher", qos: .utility)

    /// Pending coalesced signals, keyed by domain identifier. Only ever touched
    /// on `queue` (both the event handler and the delayed work item run there).
    private var pendingSignals: [String: DispatchWorkItem] = [:]

    /// How long to wait for a burst of filesystem events to settle before
    /// signalling once. A running Simulator can emit dozens of write events per
    /// second into a store; without this, each one would wake the extension and
    /// force a full folder re-scan.
    private static let debounceInterval: DispatchTimeInterval = .milliseconds(300)

    /// Updates the set of watched mounts (call whenever mounts change).
    func update(mounts: [MountDescriptor]) {
        stop()

        for descriptor in mounts {
            guard let root = DomainIdentifierCodec.rootPath(forIdentifier: descriptor.domainIdentifier) else { continue }

            let fileDescriptor = open(root, O_EVTONLY)
            guard fileDescriptor >= 0 else {
                watchLog.error("MountWatcher: open() fehlgeschlagen für \(root, privacy: .public)")
                continue
            }

            // `.write` covers directory-entry changes (add/remove/rename inside
            // the folder); `.attrib`/`.extend` fire very frequently during file
            // writes without telling us anything new for a folder-level refresh.
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fileDescriptor,
                eventMask: [.write, .rename, .delete],
                queue: queue
            )
            source.setEventHandler { [weak self] in
                self?.scheduleSignal(descriptor: descriptor)
            }
            source.setCancelHandler { close(fileDescriptor) }
            source.resume()

            monitors.append(Monitor(descriptor: descriptor, source: source))
        }
        watchLog.info("MountWatcher: überwache \(self.monitors.count) Mount(s)")
    }

    func stop() {
        for monitor in monitors { monitor.source.cancel() }
        monitors.removeAll()
        queue.async { [weak self] in
            guard let self else { return }
            self.pendingSignals.values.forEach { $0.cancel() }
            self.pendingSignals.removeAll()
        }
    }

    /// Coalesces a burst of events into a single delayed `signal`. Runs on
    /// `queue`, so mutating `pendingSignals` here needs no extra locking.
    private func scheduleSignal(descriptor: MountDescriptor) {
        let id = descriptor.domainIdentifier
        pendingSignals[id]?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.pendingSignals[id] = nil
            self?.signal(descriptor: descriptor)
        }
        pendingSignals[id] = work
        queue.asyncAfter(deadline: .now() + Self.debounceInterval, execute: work)
    }

    /// Signals the domain's root/working-set enumerators so the extension
    /// re-reads and reports the delta.
    private func signal(descriptor: MountDescriptor) {
        watchLog.debug("MountWatcher: Änderung in \(descriptor.displayName, privacy: .public)")
        let domain = NSFileProviderDomain(
            identifier: NSFileProviderDomainIdentifier(descriptor.domainIdentifier),
            displayName: descriptor.displayName
        )
        guard let manager = NSFileProviderManager(for: domain) else {
            watchLog.error("MountWatcher: kein Manager für \(descriptor.displayName, privacy: .public)")
            return
        }
        for identifier in [NSFileProviderItemIdentifier.rootContainer, .workingSet] {
            manager.signalEnumerator(for: identifier) { error in
                if let error { watchLog.error("signalEnumerator-Fehler: \(error.localizedDescription, privacy: .public)") }
            }
        }
    }

    deinit { stop() }
}

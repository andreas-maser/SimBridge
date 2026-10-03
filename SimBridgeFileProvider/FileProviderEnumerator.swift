//
//  FileProviderEnumerator.swift
//  SimBridgeFileProvider
//
//  Created for SimBridge.
//

import FileProvider
import Foundation
import SimBridgeKit

/// Enumerates the children of one folder and reports incremental changes.
///
/// It keeps a snapshot of the last-seen children (identifier → content version
/// token). When the system asks for changes (after the extension signals it),
/// the enumerator re-reads the folder, diffs against the snapshot, and reports
/// updates and deletions — so files the running app writes appear in the Finder.
final class FileProviderEnumerator: NSObject, NSFileProviderEnumerator {

    private let reader: DirectoryReader
    private let containerRelativePath: String

    /// Last-seen children: item identifier → content version token.
    private var snapshot: [NSFileProviderItemIdentifier: String] = [:]

    /// Monotonic counter; its value is the sync anchor. Bumped on every change
    /// pass so the system knows the anchor advanced.
    private var anchorCounter = 0

    init(reader: DirectoryReader, containerRelativePath: String) {
        self.reader = reader
        self.containerRelativePath = containerRelativePath
    }

    func invalidate() { }

    // MARK: - Full enumeration

    func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
        do {
            let parentIdentifier = FileProviderExtension.itemIdentifier(forRelativePath: containerRelativePath)
            var newSnapshot: [NSFileProviderItemIdentifier: String] = [:]
            let items = try reader.children(ofRelativePath: containerRelativePath).map { child -> FileProviderItem in
                let id = FileProviderExtension.itemIdentifier(forRelativePath: child.relativePath)
                newSnapshot[id] = child.contentVersionToken
                return FileProviderItem(sandboxItem: child, identifier: id, parentIdentifier: parentIdentifier)
            }
            snapshot = newSnapshot
            observer.didEnumerate(items)
            observer.finishEnumerating(upTo: nil)
        } catch {
            // If the backing folder is gone (deleted simulator / uninstalled
            // app), present an empty folder instead of a scary Finder error.
            let containerPath = reader.url(forRelativePath: containerRelativePath).path
            if !FileManager.default.fileExists(atPath: containerPath) {
                snapshot = [:]
                observer.finishEnumerating(upTo: nil)
            } else {
                observer.finishEnumeratingWithError(error)
            }
        }
    }

    // MARK: - Incremental changes

    func currentSyncAnchor(completionHandler: @escaping (NSFileProviderSyncAnchor?) -> Void) {
        completionHandler(anchor)
    }

    func enumerateChanges(for observer: NSFileProviderChangeObserver, from syncAnchor: NSFileProviderSyncAnchor) {
        do {
            let parentIdentifier = FileProviderExtension.itemIdentifier(forRelativePath: containerRelativePath)
            var newSnapshot: [NSFileProviderItemIdentifier: String] = [:]
            var updated: [FileProviderItem] = []

            for child in try reader.children(ofRelativePath: containerRelativePath, sorted: false) {
                let id = FileProviderExtension.itemIdentifier(forRelativePath: child.relativePath)
                newSnapshot[id] = child.contentVersionToken
                if snapshot[id] != child.contentVersionToken {
                    updated.append(FileProviderItem(sandboxItem: child, identifier: id, parentIdentifier: parentIdentifier))
                }
            }
            let deleted = snapshot.keys.filter { newSnapshot[$0] == nil }

            snapshot = newSnapshot
            anchorCounter += 1

            if !updated.isEmpty { observer.didUpdate(updated) }
            if !deleted.isEmpty { observer.didDeleteItems(withIdentifiers: Array(deleted)) }
            observer.finishEnumeratingChanges(upTo: anchor, moreComing: false)
        } catch {
            // Folder vanished (e.g. deleted): report no further changes.
            observer.finishEnumeratingChanges(upTo: syncAnchor, moreComing: false)
        }
    }

    private var anchor: NSFileProviderSyncAnchor {
        NSFileProviderSyncAnchor(Data("\(anchorCounter)".utf8))
    }
}

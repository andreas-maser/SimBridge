//
//  FileProviderExtension.swift
//  SimBridgeFileProvider
//
//  Created for SimBridge.
//

import FileProvider
import UniformTypeIdentifiers
import SimBridgeKit
import os

private let log = Logger(subsystem: "de.andreasmaser.SimBridge", category: "extension")

/// Principal class of the File Provider extension. The mount's root path is
/// encoded in the domain identifier (self-describing); the CoreSimulator tree is
/// read/written directly via the extension's temporary-exception entitlement.
///
/// Supports reading, writing, and — via an FSEvents watcher — live updates when
/// the running Simulator app changes files.
final class FileProviderExtension: NSObject, NSFileProviderReplicatedExtension {

    private let domain: NSFileProviderDomain

    /// Reader über den Wurzelordner der Domain, oder `nil`, wenn die Domain-ID
    /// keinen Pfad enthält (dann liefern alle Methoden einen Fehler).
    private let reader: DirectoryReader?

    required init(domain: NSFileProviderDomain) {
        self.domain = domain

        if let rootPath = DomainIdentifierCodec.rootPath(forIdentifier: domain.identifier.rawValue) {
            let url = URL(fileURLWithPath: rootPath, isDirectory: true)
            let name = url.lastPathComponent.isEmpty ? "SimBridge" : url.lastPathComponent
            self.reader = DirectoryReader(rootURL: url, rootName: name)
        } else {
            log.error("Domain identifier without encoded path: \(domain.identifier.rawValue, privacy: .public)")
            self.reader = nil
        }

        super.init()
    }

    func invalidate() {
        // No long-lived resources. Live updates are driven by the app, which
        // watches the folders and calls signalEnumerator (FSEvents is blocked
        // inside the sandboxed extension for the CoreSimulator path).
    }

    // MARK: - Metadata

    func item(
        for identifier: NSFileProviderItemIdentifier,
        request: NSFileProviderRequest,
        completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void
    ) -> Progress {
        guard let reader else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return Progress()
        }
        guard let relativePath = Self.relativePath(for: identifier) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return Progress()
        }
        do {
            let sandboxItem = try reader.item(atRelativePath: relativePath)
            completionHandler(
                FileProviderItem(
                    sandboxItem: sandboxItem,
                    identifier: identifier,
                    parentIdentifier: Self.parentIdentifier(forRelativePath: relativePath)
                ),
                nil
            )
        } catch {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
        }
        return Progress()
    }

    // MARK: - Content

    func fetchContents(
        for itemIdentifier: NSFileProviderItemIdentifier,
        version requestedVersion: NSFileProviderItemVersion?,
        request: NSFileProviderRequest,
        completionHandler: @escaping (URL?, NSFileProviderItem?, Error?) -> Void
    ) -> Progress {
        guard let reader else {
            completionHandler(nil, nil, NSFileProviderError(.noSuchItem))
            return Progress()
        }
        guard let relativePath = Self.relativePath(for: itemIdentifier) else {
            completionHandler(nil, nil, NSFileProviderError(.noSuchItem))
            return Progress()
        }
        do {
            let sandboxItem = try reader.item(atRelativePath: relativePath)
            let sourceURL = reader.url(forRelativePath: relativePath)

            // Copy into a fresh temp file the system takes ownership of.
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let tempURL = tempDir.appendingPathComponent(sandboxItem.name)
            try FileManager.default.copyItem(at: sourceURL, to: tempURL)

            completionHandler(
                tempURL,
                FileProviderItem(
                    sandboxItem: sandboxItem,
                    identifier: itemIdentifier,
                    parentIdentifier: Self.parentIdentifier(forRelativePath: relativePath)
                ),
                nil
            )
        } catch {
            completionHandler(nil, nil, error)
        }
        return Progress()
    }

    // MARK: - Enumeration

    func enumerator(
        for containerItemIdentifier: NSFileProviderItemIdentifier,
        request: NSFileProviderRequest
    ) throws -> NSFileProviderEnumerator {
        guard let reader else { throw NSFileProviderError(.noSuchItem) }
        let relativePath: String
        if containerItemIdentifier == .workingSet {
            relativePath = "" // Phase 1: working set = whole tree from root.
        } else {
            relativePath = Self.relativePath(for: containerItemIdentifier) ?? ""
        }
        return FileProviderEnumerator(reader: reader, containerRelativePath: relativePath)
    }

    // MARK: - Writing

    func createItem(
        basedOn itemTemplate: NSFileProviderItem,
        fields: NSFileProviderItemFields,
        contents url: URL?,
        options: NSFileProviderCreateItemOptions = [],
        request: NSFileProviderRequest,
        completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void
    ) -> Progress {
        guard let reader else {
            completionHandler(nil, [], false, NSFileProviderError(.noSuchItem))
            return Progress()
        }
        let parent = Self.relativePath(for: itemTemplate.parentItemIdentifier) ?? ""
        let name = itemTemplate.filename
        let childPath = parent.isEmpty ? name : "\(parent)/\(name)"
        do {
            let created: SandboxItem
            if itemTemplate.contentType == .folder {
                created = try reader.makeDirectory(atRelativePath: childPath)
            } else {
                created = try reader.makeFile(atRelativePath: childPath, importing: url)
            }
            completionHandler(fpItem(created), [], false, nil)
        } catch {
            completionHandler(nil, [], false, fpError(error))
        }
        return Progress()
    }

    func modifyItem(
        _ item: NSFileProviderItem,
        baseVersion version: NSFileProviderItemVersion,
        changedFields: NSFileProviderItemFields,
        contents newContents: URL?,
        options: NSFileProviderModifyItemOptions = [],
        request: NSFileProviderRequest,
        completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void
    ) -> Progress {
        guard let reader, var path = Self.relativePath(for: item.itemIdentifier) else {
            completionHandler(nil, [], false, NSFileProviderError(.noSuchItem))
            return Progress()
        }
        do {
            // 1. Content change.
            if changedFields.contains(.contents), let newContents {
                _ = try reader.replaceContents(atRelativePath: path, importing: newContents)
            }
            // 2. Rename (within the same parent).
            if changedFields.contains(.filename) {
                let parent = (path as NSString).deletingLastPathComponent
                let newPath = parent.isEmpty ? item.filename : "\(parent)/\(item.filename)"
                if newPath != path { _ = try reader.move(fromRelativePath: path, toRelativePath: newPath) }
                path = newPath
            }
            // 3. Reparent (move into a different folder).
            if changedFields.contains(.parentItemIdentifier) {
                let newParent = Self.relativePath(for: item.parentItemIdentifier) ?? ""
                let name = (path as NSString).lastPathComponent
                let newPath = newParent.isEmpty ? name : "\(newParent)/\(name)"
                if newPath != path { _ = try reader.move(fromRelativePath: path, toRelativePath: newPath) }
                path = newPath
            }
            let updated = try reader.item(atRelativePath: path)
            completionHandler(fpItem(updated), [], false, nil)
        } catch {
            completionHandler(nil, [], false, fpError(error))
        }
        return Progress()
    }

    func deleteItem(
        identifier: NSFileProviderItemIdentifier,
        baseVersion version: NSFileProviderItemVersion,
        options: NSFileProviderDeleteItemOptions = [],
        request: NSFileProviderRequest,
        completionHandler: @escaping (Error?) -> Void
    ) -> Progress {
        guard let reader, let path = Self.relativePath(for: identifier) else {
            completionHandler(NSFileProviderError(.noSuchItem))
            return Progress()
        }
        do {
            try reader.delete(atRelativePath: path)
            completionHandler(nil)
        } catch {
            completionHandler(fpError(error))
        }
        return Progress()
    }

    // MARK: - Identifier helpers

    /// Builds an `NSFileProviderItem` from a `SandboxItem`, deriving its
    /// identifier and parent from the relative path.
    private func fpItem(_ sandboxItem: SandboxItem) -> FileProviderItem {
        FileProviderItem(
            sandboxItem: sandboxItem,
            identifier: Self.itemIdentifier(forRelativePath: sandboxItem.relativePath),
            parentIdentifier: Self.parentIdentifier(forRelativePath: sandboxItem.relativePath)
        )
    }

    /// Maps a filesystem error to a File Provider error where it helps the UI.
    private func fpError(_ error: Error) -> NSError {
        let ns = error as NSError
        if ns.domain == NSCocoaErrorDomain, ns.code == NSFileWriteFileExistsError {
            return NSFileProviderError(.filenameCollision) as NSError
        }
        return ns
    }

    /// File Provider identifier for a domain-relative path (root ↔ `.rootContainer`).
    static func itemIdentifier(forRelativePath path: String) -> NSFileProviderItemIdentifier {
        let normalized = ItemIdentifierMapping.normalizedRelativePath(path)
        return normalized.isEmpty
            ? .rootContainer
            : NSFileProviderItemIdentifier(ItemIdentifierMapping.identifier(forRelativePath: normalized))
    }

    /// Relative path for an identifier, mapping `.rootContainer` to `""`.
    private static func relativePath(for identifier: NSFileProviderItemIdentifier) -> String? {
        if identifier == .rootContainer { return "" }
        return ItemIdentifierMapping.relativePath(forIdentifier: identifier.rawValue)
    }

    /// Identifier of a relative path's parent folder.
    private static func parentIdentifier(forRelativePath path: String) -> NSFileProviderItemIdentifier {
        let normalized = ItemIdentifierMapping.normalizedRelativePath(path)
        guard !normalized.isEmpty else { return .rootContainer }
        let parent = (normalized as NSString).deletingLastPathComponent
        return itemIdentifier(forRelativePath: parent)
    }
}

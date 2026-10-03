//
//  FileProviderItem.swift
//  SimBridgeFileProvider
//
//  Created for SimBridge.
//

import FileProvider
import UniformTypeIdentifiers
import SimBridgeKit

/// Adapts a `SandboxItem` (pure model) to `NSFileProviderItem`, the shape the
/// File Provider framework understands.
///
/// Phase 1 exposes items as **read-only** (`allowsReading`,
/// `allowsContentEnumerating`); write capabilities are added in Phase 2.
final class FileProviderItem: NSObject, NSFileProviderItem {

    private let sandboxItem: SandboxItem
    private let id: NSFileProviderItemIdentifier
    private let parentID: NSFileProviderItemIdentifier

    init(
        sandboxItem: SandboxItem,
        identifier: NSFileProviderItemIdentifier,
        parentIdentifier: NSFileProviderItemIdentifier
    ) {
        self.sandboxItem = sandboxItem
        self.id = identifier
        self.parentID = parentIdentifier
    }

    var itemIdentifier: NSFileProviderItemIdentifier { id }
    var parentItemIdentifier: NSFileProviderItemIdentifier { parentID }
    var filename: String { sandboxItem.name }

    var contentType: UTType {
        if sandboxItem.isDirectory { return .folder }
        let ext = (sandboxItem.name as NSString).pathExtension
        return UTType(filenameExtension: ext) ?? .data
    }

    var capabilities: NSFileProviderItemCapabilities {
        if sandboxItem.isDirectory {
            return [.allowsReading, .allowsContentEnumerating, .allowsAddingSubItems,
                    .allowsRenaming, .allowsReparenting, .allowsDeleting]
        } else {
            return [.allowsReading, .allowsWriting,
                    .allowsRenaming, .allowsReparenting, .allowsDeleting]
        }
    }

    var documentSize: NSNumber? {
        sandboxItem.isDirectory ? nil : NSNumber(value: sandboxItem.size)
    }

    var contentModificationDate: Date? { sandboxItem.modifiedAt }
    var creationDate: Date? { sandboxItem.createdAt }

    /// Content + metadata versions. Both derive from size + modification time,
    /// so any change the running app makes invalidates the Finder's cached copy.
    var itemVersion: NSFileProviderItemVersion {
        let token = Data(sandboxItem.contentVersionToken.utf8)
        return NSFileProviderItemVersion(contentVersion: token, metadataVersion: token)
    }
}

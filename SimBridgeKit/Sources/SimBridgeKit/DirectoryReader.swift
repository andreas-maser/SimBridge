//
//  DirectoryReader.swift
//  SimBridgeKit
//
//  Created for SimBridge.
//

import Foundation

/// Reads files and folders under a single root directory and returns
/// `SandboxItem` snapshots. This is the read side of a mounted sandbox; it is
/// pure filesystem work and therefore easy to unit-test against a temp folder.
///
/// All paths handed in and out are *relative to the root* (the empty string is
/// the root itself). Absolute URLs never leak to the File Provider identifiers.
public struct DirectoryReader: Sendable {

    /// The mount's root on disk (a Simulator app container, or a device cache).
    public let rootURL: URL

    /// Name shown for the root item (e.g. "MyApp — iPhone 16").
    public let rootName: String

    public init(rootURL: URL, rootName: String) {
        self.rootURL = rootURL
        self.rootName = rootName
    }

    private static let resourceKeys: [URLResourceKey] = [
        .isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .creationDateKey
    ]

    /// Absolute URL for a domain-relative path.
    public func url(forRelativePath path: String) -> URL {
        let normalized = ItemIdentifierMapping.normalizedRelativePath(path)
        return normalized.isEmpty ? rootURL : rootURL.appendingPathComponent(normalized)
    }

    /// Reads metadata for a single item at a relative path.
    public func item(atRelativePath path: String) throws -> SandboxItem {
        let normalized = ItemIdentifierMapping.normalizedRelativePath(path)
        let url = url(forRelativePath: normalized)
        let values = try url.resourceValues(forKeys: Set(Self.resourceKeys))
        let isDirectory = values.isDirectory ?? false
        return SandboxItem(
            relativePath: normalized,
            name: normalized.isEmpty ? rootName : url.lastPathComponent,
            isDirectory: isDirectory,
            size: Int64(values.fileSize ?? 0),
            modifiedAt: values.contentModificationDate ?? .distantPast,
            createdAt: values.creationDate
        )
    }

    /// Lists the direct children of a folder.
    ///
    /// - Parameter sorted: when `true` (the default) the result is ordered
    ///   folders-first then by natural name order — the shape the Finder wants
    ///   for display. The incremental change path passes `false`: it only diffs
    ///   by identifier, so the (locale-aware, non-trivial) sort would be wasted
    ///   work on every signal.
    public func children(ofRelativePath path: String, sorted: Bool = true) throws -> [SandboxItem] {
        let normalized = ItemIdentifierMapping.normalizedRelativePath(path)
        let directory = url(forRelativePath: normalized)
        let urls = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: Self.resourceKeys,
            options: [.skipsHiddenFiles]
        )

        let items = urls.map { url -> SandboxItem in
            let values = try? url.resourceValues(forKeys: Set(Self.resourceKeys))
            let name = url.lastPathComponent
            let childRelativePath = normalized.isEmpty ? name : "\(normalized)/\(name)"
            return SandboxItem(
                relativePath: childRelativePath,
                name: name,
                isDirectory: values?.isDirectory ?? false,
                size: Int64(values?.fileSize ?? 0),
                modifiedAt: values?.contentModificationDate ?? .distantPast,
                createdAt: values?.creationDate
            )
        }

        guard sorted else { return items }
        return items.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    // MARK: - Writing

    /// Creates a directory at a relative path and returns its snapshot.
    public func makeDirectory(atRelativePath path: String) throws -> SandboxItem {
        try FileManager.default.createDirectory(
            at: url(forRelativePath: path), withIntermediateDirectories: false
        )
        return try item(atRelativePath: path)
    }

    /// Creates a file at a relative path, importing `sourceURL` if given
    /// (otherwise an empty file). Throws if something already exists there.
    public func makeFile(atRelativePath path: String, importing sourceURL: URL?) throws -> SandboxItem {
        let destination = url(forRelativePath: path)
        if let sourceURL {
            try FileManager.default.copyItem(at: sourceURL, to: destination)
        } else {
            try Data().write(to: destination, options: .withoutOverwriting)
        }
        return try item(atRelativePath: path)
    }

    /// Replaces a file's contents from `sourceURL` and returns the new snapshot.
    ///
    /// Uses a filesystem-level atomic swap instead of reading the source into a
    /// `Data` and writing it back — so a large file (e.g. a SwiftData store)
    /// never has to be fully resident in the extension's tight memory budget.
    public func replaceContents(atRelativePath path: String, importing sourceURL: URL) throws -> SandboxItem {
        _ = try FileManager.default.replaceItemAt(url(forRelativePath: path), withItemAt: sourceURL)
        return try item(atRelativePath: path)
    }

    /// Deletes a file or folder (folders are removed recursively).
    public func delete(atRelativePath path: String) throws {
        try FileManager.default.removeItem(at: url(forRelativePath: path))
    }

    /// Moves or renames an item and returns the moved snapshot.
    public func move(fromRelativePath: String, toRelativePath: String) throws -> SandboxItem {
        try FileManager.default.moveItem(
            at: url(forRelativePath: fromRelativePath),
            to: url(forRelativePath: toRelativePath)
        )
        return try item(atRelativePath: toRelativePath)
    }
}

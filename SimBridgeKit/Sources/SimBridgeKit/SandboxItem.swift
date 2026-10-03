//
//  SandboxItem.swift
//  SimBridgeKit
//
//  Created for SimBridge.
//

import Foundation

/// A lightweight, `Sendable` snapshot of one file or folder inside a mounted
/// sandbox. Built once while reading a directory and then handed to the File
/// Provider extension, which turns it into an `NSFileProviderItem`.
///
/// Kept free of the FileProvider and UniformTypeIdentifiers frameworks so the
/// model stays pure and testable; the extension derives the `UTType` from
/// `name`/`isDirectory` at the boundary.
public struct SandboxItem: Hashable, Sendable {

    /// Path relative to the domain root (normalized, no leading/trailing slash).
    /// The empty string denotes the root container itself.
    public let relativePath: String

    /// Display name (last path component). For the root this is the mount name.
    public let name: String

    /// Whether this entry is a directory the user can descend into.
    public let isDirectory: Bool

    /// File size in bytes. Always `0` for directories.
    public let size: Int64

    /// Last modification date, used for content versioning and sorting.
    public let modifiedAt: Date

    /// Creation date, if the file system reports one.
    public let createdAt: Date?

    public init(
        relativePath: String,
        name: String,
        isDirectory: Bool,
        size: Int64,
        modifiedAt: Date,
        createdAt: Date?
    ) {
        self.relativePath = relativePath
        self.name = name
        self.isDirectory = isDirectory
        self.size = size
        self.modifiedAt = modifiedAt
        self.createdAt = createdAt
    }

    /// A compact fingerprint of the content state (size + modification time).
    /// The extension uses this as the File Provider *content version*: when the
    /// running app rewrites a file, this value changes and the Finder refetches.
    public var contentVersionToken: String {
        "\(size)-\(Int64(modifiedAt.timeIntervalSince1970 * 1000))"
    }
}

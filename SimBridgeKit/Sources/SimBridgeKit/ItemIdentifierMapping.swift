//
//  ItemIdentifierMapping.swift
//  SimBridgeKit
//
//  Created for SimBridge.
//

import Foundation

/// Bijective, relaunch-stable mapping between a File Provider item identifier
/// (a plain string) and a domain-root-relative POSIX path.
///
/// The File Provider framework addresses every file and folder by an opaque
/// `NSFileProviderItemIdentifier`. We derive that identifier purely from the
/// item's relative path, so it is:
///
/// - **stable** across relaunches (no random UUIDs, no in-memory tables),
/// - **reversible** (identifier → path and back), and
/// - **safe** for any characters (`/`, spaces, Unicode) because the path is
///   Base64URL-encoded.
///
/// This type is intentionally free of the FileProvider framework so it can be
/// unit-tested on its own. The extension bridges the real
/// `NSFileProviderItemIdentifier.rootContainer` to the empty relative path.
public enum ItemIdentifierMapping {

    /// Sentinel identifier for the domain root. Matches the raw value of
    /// `NSFileProviderItemIdentifier.rootContainer` so the extension can pass
    /// it through unchanged.
    public static let rootRawValue = "NSFileProviderRootContainerItemIdentifier"

    /// Prefix marking a path-based identifier, to distinguish it from sentinels.
    private static let pathPrefix = "p:"

    /// Returns the stable identifier for a domain-root-relative path.
    /// The empty (or `"/"`) path maps to the root sentinel.
    public static func identifier(forRelativePath path: String) -> String {
        let normalized = normalizedRelativePath(path)
        guard !normalized.isEmpty else { return rootRawValue }
        return pathPrefix + base64URLEncode(Data(normalized.utf8))
    }

    /// Returns the domain-root-relative path for an identifier, or `nil` if the
    /// identifier is not one we produced. The root sentinel maps to `""`.
    public static func relativePath(forIdentifier identifier: String) -> String? {
        if identifier == rootRawValue { return "" }
        guard identifier.hasPrefix(pathPrefix) else { return nil }
        let encoded = String(identifier.dropFirst(pathPrefix.count))
        guard let data = base64URLDecode(encoded),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return normalizedRelativePath(string)
    }

    /// Normalizes a relative path: strips leading/trailing slashes and collapses
    /// empty components, so `"/Documents/"` and `"Documents"` are equivalent.
    public static func normalizedRelativePath(_ path: String) -> String {
        path
            .split(separator: "/", omittingEmptySubsequences: true)
            .joined(separator: "/")
    }

    // MARK: - Base64URL

    private static func base64URLEncode(_ data: Data) -> String {
        // Single pass over the ASCII base64 bytes instead of three separate
        // `replacingOccurrences` scans (each allocating a fresh String). This
        // runs per item on every enumeration, so it is a genuine hot path.
        let base64 = data.base64EncodedString().utf8
        var bytes = [UInt8]()
        bytes.reserveCapacity(base64.count)
        for byte in base64 {
            switch byte {
            case UInt8(ascii: "+"): bytes.append(UInt8(ascii: "-"))
            case UInt8(ascii: "/"): bytes.append(UInt8(ascii: "_"))
            case UInt8(ascii: "="): break
            default: bytes.append(byte)
            }
        }
        return String(decoding: bytes, as: UTF8.self)
    }

    private static func base64URLDecode(_ string: String) -> Data? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        // Restore removed padding.
        let remainder = base64.count % 4
        if remainder > 0 {
            base64.append(String(repeating: "=", count: 4 - remainder))
        }
        return Data(base64Encoded: base64)
    }
}

//
//  DomainIdentifierCodec.swift
//  SimBridgeKit
//
//  Created for SimBridge.
//

import Foundation

/// Encodes a mount's absolute root path **into the File Provider domain
/// identifier** and back.
///
/// This makes each domain self-describing: the extension can recover the root
/// path from its own `domain.identifier` — no shared file or UserDefaults
/// needed. That matters because a File Provider extension runs under a separate
/// persona and cannot reliably read what the app writes into the App Group
/// container (neither files nor preferences).
public enum DomainIdentifierCodec {

    private static let prefix = "mount-"

    /// Domain identifier for an absolute root path.
    public static func identifier(forRootPath path: String) -> String {
        prefix + base64URLEncode(Data(path.utf8))
    }

    /// Absolute root path encoded in a domain identifier, or `nil` if the
    /// identifier wasn't produced by `identifier(forRootPath:)`.
    public static func rootPath(forIdentifier identifier: String) -> String? {
        guard identifier.hasPrefix(prefix) else { return nil }
        let encoded = String(identifier.dropFirst(prefix.count))
        guard let data = base64URLDecode(encoded),
              let path = String(data: data, encoding: .utf8) else {
            return nil
        }
        return path
    }

    // MARK: - Base64URL

    private static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func base64URLDecode(_ string: String) -> Data? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 {
            base64.append(String(repeating: "=", count: 4 - remainder))
        }
        return Data(base64Encoded: base64)
    }
}

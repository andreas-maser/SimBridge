//
//  SimBridgeConfig.swift
//  SimBridgeKit
//
//  Created for SimBridge.
//

import Foundation

/// Shared configuration constants. Kept in one place so the app and the
/// extension can never drift apart on the App Group identifier.
public enum SimBridgeConfig {

    /// App Group shared by the app and the File Provider extension.
    /// MUST match the value in both entitlements files and the extension's
    /// `NSExtensionFileProviderDocumentGroup`.
    public static let appGroupIdentifier = "group.de.andreasmaser.SimBridge"
}

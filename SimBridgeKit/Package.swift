// swift-tools-version: 6.0
//
//  Package.swift
//  SimBridgeKit
//
//  Shared core logic used by both the SimBridge app and its File Provider
//  extension. Deliberately depends only on Foundation so it stays pure and
//  unit-testable without the FileProvider framework or a running Finder.
//

import PackageDescription

let package = Package(
    name: "SimBridgeKit",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "SimBridgeKit", targets: ["SimBridgeKit"])
    ],
    targets: [
        .target(
            name: "SimBridgeKit",
            swiftSettings: [
                // Modern concurrency: run under the Swift 6 language mode.
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "SimBridgeKitTests",
            dependencies: ["SimBridgeKit"]
        )
    ]
)

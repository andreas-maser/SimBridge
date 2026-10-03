//
//  DomainIdentifierCodecTests.swift
//  SimBridgeKitTests
//

import Testing
import Foundation
@testable import SimBridgeKit

@Suite("DomainIdentifierCodec")
struct DomainIdentifierCodecTests {

    @Test("Absolute paths round-trip exactly", arguments: [
        "/Users/entwickler/Library/Developer/CoreSimulator/Devices/C2164519-B3AB-48A9-94A2-19EAD59CC47F/data/Containers/Data/Application/1843D5BD-CE89-40E2-8EE0-C87E6D534AA3",
        "/tmp/x",
        "/Users/a b/Ordner mit Leerzeichen/Grüße 🚀",
        "/pfad/mit+plus/und=gleich/und_unterstrich",
        "/"
    ])
    func roundTrip(path: String) {
        let id = DomainIdentifierCodec.identifier(forRootPath: path)
        #expect(DomainIdentifierCodec.rootPath(forIdentifier: id) == path)
    }

    @Test("Every identifier carries the mount prefix")
    func prefixPresent() {
        let id = DomainIdentifierCodec.identifier(forRootPath: "/some/path")
        #expect(id.hasPrefix("mount-"))
    }

    @Test("The same path always yields the same identifier (relaunch-stable)")
    func deterministic() {
        let a = DomainIdentifierCodec.identifier(forRootPath: "/x/y/z")
        let b = DomainIdentifierCodec.identifier(forRootPath: "/x/y/z")
        #expect(a == b)
    }

    @Test("Different paths yield different identifiers")
    func distinct() {
        let a = DomainIdentifierCodec.identifier(forRootPath: "/x/y")
        let b = DomainIdentifierCodec.identifier(forRootPath: "/x/z")
        #expect(a != b)
    }

    @Test("Empty path round-trips to empty")
    func emptyPath() {
        let id = DomainIdentifierCodec.identifier(forRootPath: "")
        #expect(DomainIdentifierCodec.rootPath(forIdentifier: id) == "")
    }

    @Test("Identifiers without the mount prefix are rejected", arguments: [
        "workingSet",
        "not-ours",
        "mountwithoutdash",
        ""
    ])
    func rejectsForeignIdentifiers(identifier: String) {
        #expect(DomainIdentifierCodec.rootPath(forIdentifier: identifier) == nil)
    }

    @Test("A prefixed but undecodable identifier returns nil")
    func rejectsGarbagePayload() {
        // '@' is invalid even for base64url, so decoding must fail cleanly.
        #expect(DomainIdentifierCodec.rootPath(forIdentifier: "mount-@@@@@") == nil)
    }
}

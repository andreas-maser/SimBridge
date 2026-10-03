//
//  ItemIdentifierMappingTests.swift
//  SimBridgeKitTests
//

import Testing
import Foundation
@testable import SimBridgeKit

@Suite("ItemIdentifierMapping")
struct ItemIdentifierMappingTests {

    @Test("Root path maps to the root sentinel and back")
    func rootRoundTrip() {
        #expect(ItemIdentifierMapping.identifier(forRelativePath: "") == ItemIdentifierMapping.rootRawValue)
        #expect(ItemIdentifierMapping.identifier(forRelativePath: "/") == ItemIdentifierMapping.rootRawValue)
        #expect(ItemIdentifierMapping.relativePath(forIdentifier: ItemIdentifierMapping.rootRawValue) == "")
    }

    @Test("Ordinary paths round-trip exactly", arguments: [
        "Documents",
        "Documents/UserManual.pdf",
        "Library/Preferences/com.example.plist",
        "tmp/nested/deep/file.txt"
    ])
    func roundTrip(path: String) {
        let id = ItemIdentifierMapping.identifier(forRelativePath: path)
        #expect(ItemIdentifierMapping.relativePath(forIdentifier: id) == path)
    }

    @Test("Special characters survive the round-trip", arguments: [
        "Ordner mit Leerzeichen/Datei.txt",
        "Ümläüte/Grüße.txt",
        "emoji 🚀/rocket.json",
        "a+b/c_d/e=f"
    ])
    func specialCharacters(path: String) {
        let id = ItemIdentifierMapping.identifier(forRelativePath: path)
        #expect(ItemIdentifierMapping.relativePath(forIdentifier: id) == path)
    }

    @Test("Leading and trailing slashes are normalized away")
    func normalization() {
        let id1 = ItemIdentifierMapping.identifier(forRelativePath: "/Documents/file.txt/")
        let id2 = ItemIdentifierMapping.identifier(forRelativePath: "Documents/file.txt")
        #expect(id1 == id2)
    }

    @Test("Unknown identifiers return nil")
    func unknownIdentifier() {
        #expect(ItemIdentifierMapping.relativePath(forIdentifier: "not-ours") == nil)
        #expect(ItemIdentifierMapping.relativePath(forIdentifier: "p:!!!not-base64!!!") == nil)
    }
}

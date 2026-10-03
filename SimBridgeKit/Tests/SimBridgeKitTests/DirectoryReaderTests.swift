//
//  DirectoryReaderTests.swift
//  SimBridgeKitTests
//

import Testing
import Foundation
@testable import SimBridgeKit

@Suite("DirectoryReader")
struct DirectoryReaderTests {

    /// Builds a throwaway directory tree and cleans it up afterwards.
    private func makeTempTree() throws -> URL {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("SimBridgeTest-\(UUID().uuidString)")
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        try fm.createDirectory(at: root.appendingPathComponent("Documents"), withIntermediateDirectories: true)
        try Data("hello".utf8).write(to: root.appendingPathComponent("readme.txt"))
        try Data("{}".utf8).write(to: root.appendingPathComponent("Documents/config.json"))
        return root
    }

    @Test("Root children list folders first, then files, naturally sorted")
    func rootChildren() throws {
        let root = try makeTempTree()
        defer { try? FileManager.default.removeItem(at: root) }

        let reader = DirectoryReader(rootURL: root, rootName: "TestMount")
        let children = try reader.children(ofRelativePath: "")

        #expect(children.count == 2)
        #expect(children[0].name == "Documents")
        #expect(children[0].isDirectory)
        #expect(children[1].name == "readme.txt")
        #expect(children[1].isDirectory == false)
        #expect(children[1].size == 5) // "hello"
    }

    @Test("Nested children carry a correct relative path")
    func nestedChildren() throws {
        let root = try makeTempTree()
        defer { try? FileManager.default.removeItem(at: root) }

        let reader = DirectoryReader(rootURL: root, rootName: "TestMount")
        let children = try reader.children(ofRelativePath: "Documents")

        #expect(children.count == 1)
        #expect(children[0].relativePath == "Documents/config.json")
        #expect(children[0].name == "config.json")
    }

    @Test("Item metadata for the root uses the mount name")
    func rootItem() throws {
        let root = try makeTempTree()
        defer { try? FileManager.default.removeItem(at: root) }

        let reader = DirectoryReader(rootURL: root, rootName: "TestMount")
        let item = try reader.item(atRelativePath: "")

        #expect(item.relativePath == "")
        #expect(item.name == "TestMount")
        #expect(item.isDirectory)
    }

    @Test("Content version token changes when a file is rewritten")
    func contentVersionChanges() throws {
        let root = try makeTempTree()
        defer { try? FileManager.default.removeItem(at: root) }

        let reader = DirectoryReader(rootURL: root, rootName: "TestMount")
        let before = try reader.item(atRelativePath: "readme.txt").contentVersionToken

        // Rewrite with different content and a newer modification date.
        let fileURL = root.appendingPathComponent("readme.txt")
        try Data("hello world".utf8).write(to: fileURL)
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(5)],
            ofItemAtPath: fileURL.path
        )

        let after = try reader.item(atRelativePath: "readme.txt").contentVersionToken
        #expect(before != after)
    }

    @Test("Unsorted children contain the same set as sorted")
    func unsortedChildrenSameSet() throws {
        let root = try makeTempTree()
        defer { try? FileManager.default.removeItem(at: root) }

        let reader = DirectoryReader(rootURL: root, rootName: "TestMount")
        let sortedNames = try reader.children(ofRelativePath: "", sorted: true).map(\.name)
        let unsortedNames = try reader.children(ofRelativePath: "", sorted: false).map(\.name)

        #expect(Set(sortedNames) == Set(unsortedNames))
        #expect(sortedNames == ["Documents", "readme.txt"])   // folders first, then natural order
    }

    @Test("Reading a missing folder throws")
    func missingFolderThrows() throws {
        let root = try makeTempTree()
        defer { try? FileManager.default.removeItem(at: root) }

        let reader = DirectoryReader(rootURL: root, rootName: "TestMount")
        #expect(throws: (any Error).self) {
            _ = try reader.children(ofRelativePath: "DoesNotExist")
        }
    }
}

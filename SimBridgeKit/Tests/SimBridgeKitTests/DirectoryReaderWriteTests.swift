//
//  DirectoryReaderWriteTests.swift
//  SimBridgeKitTests
//

import Testing
import Foundation
@testable import SimBridgeKit

@Suite("DirectoryReader – Writing")
struct DirectoryReaderWriteTests {

    private func makeTempRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SimBridgeWriteTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    @Test("Create folder, then a file inside it")
    func createFolderAndFile() throws {
        let root = try makeTempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let reader = DirectoryReader(rootURL: root, rootName: "Mount")

        let folder = try reader.makeDirectory(atRelativePath: "New Folder")
        #expect(folder.isDirectory)
        #expect(folder.relativePath == "New Folder")

        let file = try reader.makeFile(atRelativePath: "New Folder/note.txt", importing: nil)
        #expect(file.isDirectory == false)
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("New Folder/note.txt").path))
    }

    @Test("Replace contents changes the content version token")
    func replaceContents() throws {
        let root = try makeTempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let reader = DirectoryReader(rootURL: root, rootName: "Mount")

        _ = try reader.makeFile(atRelativePath: "a.txt", importing: nil)
        let before = try reader.item(atRelativePath: "a.txt").contentVersionToken

        // Prepare a source file with new content.
        let source = root.appendingPathComponent("_source")
        try Data("hello world".utf8).write(to: source)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(5)],
                                               ofItemAtPath: root.appendingPathComponent("a.txt").path)
        let updated = try reader.replaceContents(atRelativePath: "a.txt", importing: source)

        #expect(updated.size == 11)
        #expect(updated.contentVersionToken != before)
    }

    @Test("Move renames and relocates")
    func move() throws {
        let root = try makeTempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let reader = DirectoryReader(rootURL: root, rootName: "Mount")

        _ = try reader.makeDirectory(atRelativePath: "Sub")
        _ = try reader.makeFile(atRelativePath: "old.txt", importing: nil)

        let moved = try reader.move(fromRelativePath: "old.txt", toRelativePath: "Sub/new.txt")
        #expect(moved.relativePath == "Sub/new.txt")
        #expect(moved.name == "new.txt")
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("old.txt").path) == false)
    }

    @Test("Delete removes a folder recursively")
    func delete() throws {
        let root = try makeTempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let reader = DirectoryReader(rootURL: root, rootName: "Mount")

        _ = try reader.makeDirectory(atRelativePath: "Trash")
        _ = try reader.makeFile(atRelativePath: "Trash/x.txt", importing: nil)

        try reader.delete(atRelativePath: "Trash")
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("Trash").path) == false)
    }

    @Test("Creating an existing file throws (collision)")
    func collision() throws {
        let root = try makeTempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let reader = DirectoryReader(rootURL: root, rootName: "Mount")

        _ = try reader.makeFile(atRelativePath: "dup.txt", importing: nil)
        #expect(throws: (any Error).self) {
            _ = try reader.makeFile(atRelativePath: "dup.txt", importing: nil)
        }
    }
}

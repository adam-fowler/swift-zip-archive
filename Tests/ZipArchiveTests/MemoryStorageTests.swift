//
// This source file is part of the swift-zip-archive project
// Copyright (c) 2025-2026 the swift-zip-archive project authors
//
// See LICENSE for license information
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import SystemPackage
import Testing

@testable import ZipArchive

struct ZipMemoryStorageTests {
    let buffer: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]

    @Test(arguments: [
        (0, []),
        (3, [0, 1, 2]),
        (8, [0, 1, 2, 3, 4, 5, 6, 7]),
        (10, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]),
    ])
    func testRead(values: (read: Int, result: [UInt8])) throws {
        let file = ZipMemoryStorage(buffer)
        #expect(try .init(file.read(values.read)) == values.result)
    }

    @Test(arguments: [-1, 11])
    func testReadFails(read: Int) throws {
        let file = ZipMemoryStorage(buffer)
        #expect(throws: ZipStorageError.self) { try file.read(read) }
    }

    @Test(arguments: [0, 5, 10])
    func testSeek(offset: Int64) throws {
        let file = ZipMemoryStorage(buffer)
        #expect(throws: Never.self) { try file.seek(offset) }
    }

    @Test(arguments: [-1, 11])
    func testSeekFails(offset: Int64) throws {
        let file = ZipMemoryStorage(buffer)
        #expect(throws: ZipStorageError.self) { try file.seek(offset) }
    }

    @Test(arguments: [
        (0, 5, [0, 1, 2, 3, 4]),
        (3, 8, [3, 4, 5, 6, 7]),
        (4, 7, [4, 5, 6]),
        (8, 10, [8, 9]),
    ])
    func testSeekAndRead(values: (seek: Int64, readTo: Int64, result: [UInt8])) throws {
        let file = ZipMemoryStorage(buffer)
        try file.seek(values.seek)
        #expect(try .init(file.read(numericCast(values.readTo - values.seek))) == values.result)
    }

    @Test(arguments: [
        (0, 15),
        (9, 20),
        (10, 1),
    ])
    func testSeekAndReadFail(values: (seek: Int64, readTo: Int)) throws {
        let file = ZipMemoryStorage(buffer)
        try file.seek(values.seek)
        #expect(throws: ZipStorageError.self) { try file.read(values.readTo) }
    }

    @Test func testWrite() throws {
        let file = ZipMemoryStorage<[UInt8]>()
        try file.seekEnd()
        file.write(bytes: [1, 2, 3])
        try file.seek(0)
        #expect(try file.read(3) == [1, 2, 3])
    }

    @Test func testAppendingWrite() throws {
        let file = ZipMemoryStorage<[UInt8]>([1, 2, 3])
        try file.seekEnd()
        file.write(bytes: [4, 5, 6])
        try file.seek(0)
        #expect(try file.read(6) == [1, 2, 3, 4, 5, 6])
    }

    @Test func testReplacingWrite() throws {
        let file = ZipMemoryStorage<[UInt8]>([1, 2, 3, 4, 5, 6])
        try file.seek(2)
        file.write(bytes: [7, 8, 9])
        try file.seek(0)
        #expect(try file.read(6) == [1, 2, 7, 8, 9, 6])
        try file.seek(5)
        file.write(bytes: [7, 8, 9])
        try file.seek(0)
        #expect(try file.read(8) == [1, 2, 7, 8, 9, 7, 8, 9])
    }

    @Test func testTruncate() throws {
        let file = ZipMemoryStorage<[UInt8]>([1, 2, 3, 4, 5, 6])
        try file.truncate(4)
        try file.seek(0)
        #expect(try file.read(4) == [1, 2, 3, 4])
    }

    @Test func testTruncateAndWrite() throws {
        let file = ZipMemoryStorage([UInt8]("Hello world".utf8))
        try file.truncate(5)
        file.write(bytes: ", world!".utf8)
        try file.seek(0)
        #expect(try file.read(13) == .init("Hello, world!".utf8))
    }
}

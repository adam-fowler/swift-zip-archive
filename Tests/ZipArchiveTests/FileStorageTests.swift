//
// This source file is part of the swift-zip-archive project
// Copyright (c) 2026 the swift-zip-archive project authors
//
// See LICENSE for license information
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import SystemPackage
import Testing

@testable import ZipArchive

final class ZipFileStorageTests {
    let filePath = Bundle.module.fixedUpPath(forResource: "test", ofType: "bin")!

    @Test(arguments: [
        (0, []),
        (3, [0, 1, 2]),
        (8, [0, 1, 2, 3, 4, 5, 6, 7]),
        (10, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]),
    ])
    func testRead(values: (read: Int, result: [UInt8])) throws {
        let fileDescriptor = try FileDescriptor.open(
            .init(filePath),
            .readOnly
        )
        let file = try ZipFileStorage(fileDescriptor)
        #expect(try .init(file.read(values.read)) == values.result)
        try fileDescriptor.close()
    }

    @Test(arguments: [-1, 11])
    func testReadFails(read: Int) throws {
        let fileDescriptor = try FileDescriptor.open(
            .init(filePath),
            .readOnly
        )
        let file = try ZipFileStorage(fileDescriptor)
        #expect(throws: ZipStorageError.self) { try file.read(read) }
        try fileDescriptor.close()
    }

    @Test(arguments: [0, 5, 10])
    func testSeek(offset: Int64) throws {
        let fileDescriptor = try FileDescriptor.open(
            .init(filePath),
            .readOnly
        )
        let file = try ZipFileStorage(fileDescriptor)
        #expect(throws: Never.self) { try file.seek(offset) }
        try fileDescriptor.close()
    }

    @Test(arguments: [-1])
    func testSeekFails(offset: Int64) throws {
        let fileDescriptor = try FileDescriptor.open(
            .init(filePath),
            .readOnly
        )
        let file = try ZipFileStorage(fileDescriptor)
        #expect(throws: ZipStorageError.self) { try file.seek(offset) }
        try fileDescriptor.close()
    }

    @Test(arguments: [
        (0, 5, [0, 1, 2, 3, 4]),
        (3, 8, [3, 4, 5, 6, 7]),
        (4, 7, [4, 5, 6]),
        (8, 10, [8, 9]),
    ])
    func testSeekAndRead(values: (seek: Int64, readTo: Int64, result: [UInt8])) throws {
        let fileDescriptor = try FileDescriptor.open(
            .init(filePath),
            .readOnly
        )
        let file = try ZipFileStorage(fileDescriptor)
        try file.seek(values.seek)
        #expect(try .init(file.read(numericCast(values.readTo - values.seek))) == values.result)
        try fileDescriptor.close()
    }

    @Test(arguments: [
        (0, 15),
        (9, 20),
        (10, 1),
    ])
    func testSeekAndReadFail(values: (seek: Int64, readTo: Int)) throws {
        let fileDescriptor = try FileDescriptor.open(
            .init(filePath),
            .readOnly
        )
        let file = try ZipFileStorage(fileDescriptor)
        try file.seek(values.seek)
        #expect(throws: ZipStorageError.self) { try file.read(values.readTo) }
        try fileDescriptor.close()
    }

    /*
    @Test func testWrite() throws {
        let file = ZipMemoryStorage<[UInt8]>()
        file.seekEnd()
        #expect(file.write(bytes: [1, 2, 3]) == 3)
        try file.seek(0)
        #expect(try file.read(3) == [1, 2, 3])
    }

    @Test func testAppendingWrite() throws {
        let file = ZipMemoryStorage<[UInt8]>([1, 2, 3])
        file.seekEnd()
        #expect(file.write(bytes: [4, 5, 6]) == 3)
        try file.seek(0)
        #expect(try file.read(6) == [1, 2, 3, 4, 5, 6])
    }

    @Test func testReplacingWrite() throws {
        let file = ZipMemoryStorage<[UInt8]>([1, 2, 3, 4, 5, 6])
        try file.seek(2)
        #expect(file.write(bytes: [7, 8, 9]) == 3)
        try file.seek(0)
        #expect(try file.read(6) == [1, 2, 7, 8, 9, 6])
        try file.seek(5)
        #expect(file.write(bytes: [7, 8, 9]) == 3)
        try file.seek(0)
        #expect(try file.read(8) == [1, 2, 7, 8, 9, 7, 8, 9])
    }*/
}

extension Bundle {
    /// Fix up paths returned by `Bundle.module.path(forResource:ofType:)` on Windows
    func fixedUpPath(forResource name: String?, ofType ext: String?) -> String? {
        #if os(Windows)
        Bundle.module.path(forResource: name, ofType: ext).map {
            if $0.first == "/" {
                String($0.dropFirst())
            } else {
                $0
            }
        }
        #else
        Bundle.module.path(forResource: name, ofType: ext)
        #endif
    }
}

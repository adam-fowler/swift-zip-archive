//
// This source file is part of the swift-zip-archive project
// Copyright (c) 2025-2026 the swift-zip-archive project authors
//
// See LICENSE for license information
// SPDX-License-Identifier: Apache-2.0
//

/// Protocol for storage of a Zip archive
public protocol ZipStorage {
    func currentPosition() throws(ZipStorageError) -> Int64
}

/// Error thrown by ZipStorage
public struct ZipStorageError: Error {
    internal enum Value {
        case fileOffsetOutOfRange
        case readPastEndOfFile
        case internalError
    }
    internal let value: Value

    /// File offset is outside of size of storage
    public static var fileOffsetOutOfRange: Self { .init(value: .fileOffsetOutOfRange) }
    /// Trying to read past the end of the storage
    public static var readingPastEndOfFile: Self { .init(value: .readPastEndOfFile) }
    /// Internal, should not be thrown. If you receive this please add an issue
    /// to https://github.com/adam-fowler/swift-zip-archive
    public static var internalError: Self { .init(value: .internalError) }
}

//
// This source file is part of the swift-zip-archive project
// Copyright (c) 2025-2026 the swift-zip-archive project authors
//
// See LICENSE for license information
// SPDX-License-Identifier: Apache-2.0
//

/// Protocol for storage that can be written to
public protocol ZipWriteableStorage: ZipStorage {
    /// Write buffer to storage
    /// - Parameter bytes: Buffer to write to storage
    /// - Throws: ``ZipStorageError``
    func write<Bytes: Collection>(bytes: Bytes) throws(ZipStorageError) where Bytes.Element == UInt8

    ///  Drop storage after offset in storage and seek to that position
    /// - Parameter size: Size of truncated storage
    /// - Throws: ``ZipStorageError``
    func truncate(_ size: Int64) throws(ZipStorageError)
}

extension ZipWriteableStorage {
    /// Write string to storage
    /// - Parameter string: String to write
    /// - Throws: ``ZipStorageError``
    @inlinable
    public func writeString(_ string: String) throws(ZipStorageError) {
        try self.write(bytes: string.utf8)
    }

    /// Write integer to storage
    /// - Parameter value: Integer to write
    /// - Throws: ``ZipStorageError``
    @inlinable
    public func writeInteger<T: FixedWidthInteger>(
        _ value: T
    ) throws(ZipStorageError) {
        do {
            try withUnsafeBytes(of: value.littleEndian) { valuePtr in
                try write(bytes: valuePtr)
            }
        } catch let error as ZipStorageError {
            throw error
        } catch {
            throw .internalError
        }
    }

    ///  Write a list of integers to storage
    /// - Parameter value: Integers to write
    /// - Throws: ``ZipStorageError``
    @inlinable
    public func writeIntegers<each T: FixedWidthInteger>(_ value: repeat each T) throws(ZipStorageError) {
        try (repeat self.writeInteger(each value))
    }
}

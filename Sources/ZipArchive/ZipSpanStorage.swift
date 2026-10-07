//
// This source file is part of the swift-zip-archive project
// Copyright (c) 2025-2026 the swift-zip-archive project authors
//
// See LICENSE for license information
// SPDX-License-Identifier: Apache-2.0
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Protocol for storage that can be read from
public struct ZipSpanStorage: ZipReadableStorage, ~Escapable {
    @usableFromInline
    let bytes: RawSpan
    @usableFromInline
    var startIndex: Int
    @usableFromInline
    var endIndex: Int
    @usableFromInline
    var position: Int

    public typealias OutputBuffer = [UInt8]

    @_lifetime(copy bytes)
    @inlinable
    public init(_ bytes: RawSpan) {
        self.bytes = bytes
        self.startIndex = bytes.byteOffsets.lowerBound
        self.endIndex = bytes.byteOffsets.upperBound
        self.position = self.startIndex
    }

    @inlinable
    public mutating func read(_ count: Int) throws(ZipStorageError) -> OutputBuffer {
        let newPosition = self.position + count
        defer { self.position = newPosition }
        guard count >= 0, newPosition <= self.endIndex else {
            throw .readingPastEndOfFile
        }
        return [UInt8](capacity: count) { outputSpan in
            outputSpan.withUnsafeMutableBufferPointer { outputBytes, initializedCount in
                _ = self.bytes.extracting(self.position..<newPosition).withUnsafeBytes { bytes in
                    outputBytes.update(fromContentsOf: bytes)
                }
                initializedCount = count
            }
        }
    }

    @inlinable
    public mutating func withBytes<Value>(
        count: Int,
        operation: (consuming ZipSpanStorage) throws(ZipStorageError) -> Value
    ) throws(ZipStorageError) -> Value {
        let newPosition = self.position + count
        guard count >= 0, newPosition <= self.endIndex else {
            throw .readingPastEndOfFile
        }
        let bytes = self.bytes.extracting(self.position..<newPosition)
        self.position = newPosition
        let storage = ZipSpanStorage(bytes)
        return try operation(storage)
    }

    @inlinable
    public mutating func seek(_ index: Int64) throws(ZipStorageError) -> Int64 {
        let newPosition = self.startIndex + Int(index)
        defer { self.position = newPosition }

        guard newPosition >= 0, newPosition <= self.endIndex else {
            throw .readingPastEndOfFile
        }
        return index
    }

    @inlinable
    public mutating func seekOffset(_ offset: Int64) throws(ZipStorageError) -> Int64 {
        let newPosition = self.position + Int(offset)
        defer { self.position = newPosition }

        guard newPosition >= self.startIndex, newPosition <= self.endIndex else {
            throw .readingPastEndOfFile
        }
        return Int64(newPosition - self.startIndex)
    }

    @inlinable
    public mutating func seekEnd(_ offset: Int64) throws(ZipStorageError) -> Int64 {
        let newPosition = self.endIndex + Int(offset)
        defer { self.position = newPosition }

        guard newPosition >= self.startIndex, newPosition <= self.endIndex else {
            throw .readingPastEndOfFile
        }
        return Int64(newPosition - self.startIndex)
    }

    @inlinable
    public func currentPosition() throws(ZipStorageError) -> Int64 {
        Int64(self.position - self.startIndex)
    }

    /// Read integer from buffer
    /// - Parameter as: Integer type to read
    /// - Returns: Value read from storage
    /// - Throws: ``ZipStorageError``
    @inlinable
    public mutating func readInteger<T: FixedWidthInteger & BitwiseCopyable>(
        as: T.Type = T.self
    ) throws(ZipStorageError) -> T {
        let newPosition = self.endIndex + Int(MemoryLayout<T>.size)
        defer { self.position = newPosition }
        guard newPosition <= self.endIndex else {
            throw .readingPastEndOfFile
        }
        return self.bytes.unsafeLoad(fromUncheckedByteOffset: self.position, as: T.self).littleEndian
    }

    /// Read string of length from buffer
    /// - Parameter length: Length of string in bytes.
    /// - Returns: String read from storage
    /// - Throws: ``ZipStorageError``
    @inlinable
    public mutating func readString(length: Int) throws(ZipStorageError) -> String {
        let newPosition = self.endIndex + length
        defer { self.position = newPosition }
        return self.bytes.extracting(self.position..<newPosition).withUnsafeBytes { bytes in
            String(decoding: bytes, as: UTF8.self)
        }
    }

    /// Read buffer and copy into array of `UInt8`
    /// - Parameter length: Length of buffer to read
    /// - Returns: Array read from storage
    /// - Throws: ``ZipStorageError``
    @inlinable
    public mutating func readBytes(length: Int) throws(ZipStorageError) -> [UInt8] {
        try read(length)
    }

    /// Read a list of integers from storage
    /// - Parameter type: list of integer types to read
    /// - Returns: Integers read from storage
    /// - Throws: ``ZipStorageError``
    @inlinable
    public mutating func readIntegers<each T: FixedWidthInteger & BitwiseCopyable>(
        _ type: repeat (each T).Type
    ) throws(ZipStorageError) -> (repeat each T) {
        (repeat try self.readInteger(as: (each T).self))
    }
}

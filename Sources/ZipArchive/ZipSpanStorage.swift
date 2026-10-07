//
// This source file is part of the swift-zip-archive project
// Copyright (c) 2025-2026 the swift-zip-archive project authors
//
// See LICENSE for license information
// SPDX-License-Identifier: Apache-2.0
//

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
        defer { self.position += count }
        return [UInt8](capacity: count) { outputSpan in
            outputSpan.withUnsafeMutableBufferPointer { outputBytes, initializedCount in
                _ = self.bytes.extracting(self.position..<self.position + count).withUnsafeBytes { bytes in
                    outputBytes.update(fromContentsOf: bytes)
                }
                initializedCount = count
            }
        }
    }

    @inlinable
    public mutating func seek(_ index: Int64) throws(ZipStorageError) -> Int64 {
        self.position = self.startIndex + Int(index)
        return Int64(self.position)
    }

    @inlinable
    public mutating func seekOffset(_ offset: Int64) throws(ZipStorageError) -> Int64 {
        self.position = self.position + Int(offset)
        return Int64(self.position)
    }

    @inlinable
    public mutating func seekEnd(_ offset: Int64) throws(ZipStorageError) -> Int64 {
        self.position = self.endIndex + Int(offset)
        return Int64(self.position)
    }

    @inlinable
    public func currentPosition() throws(ZipStorageError) -> Int64 {
        Int64(self.position - self.startIndex)
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
        func memorySize<Value>(_ value: Value.Type) -> Int {
            MemoryLayout<Value>.size
        }
        var size = 0
        for t in repeat each type {
            size += memorySize(t)
        }
        func readInteger<Value: FixedWidthInteger & BitwiseCopyable>(_ int: some FixedWidthInteger & BitwiseCopyable) throws -> Value {
            self.bytes.unsafeLoadUnaligned(fromByteOffset: self.position, as: Value.self)
        }
        
        let bytes = try read(size)
        var buffer = MemoryBuffer(bytes)
        do {
            return try buffer.readIntegers(repeat (each type))
        } catch {
            throw .init(from: error)
        }
    }
}

//
// This source file is part of the swift-zip-archive project
// Copyright (c) 2025-2026 the swift-zip-archive project authors
//
// See LICENSE for license information
// SPDX-License-Identifier: Apache-2.0
//

/// Storage in a memory buffer
public struct ZipMemoryStorage<Bytes: Collection>: ZipReadableStorage, ZipInMemoryReadableStorage
where Bytes.Element == UInt8, Bytes.Index == Int {
    @usableFromInline
    var buffer: MemoryBuffer<Bytes>

    @inlinable
    init(_ buffer: Bytes) {
        self.buffer = .init(buffer)
    }

    @inlinable
    public mutating func read(_ count: Int) throws(ZipStorageError) -> Bytes.SubSequence {
        do {
            return try self.buffer.read(count)
        } catch {
            throw .init(from: error)
        }
    }

    @inlinable
    public mutating func withInMemoryStorage<Return, Failure>(
        _ count: Int,
        operation: (inout ZipMemoryStorage<Bytes.SubSequence>) throws(Failure) -> Return
    ) throws(EitherError<ZipStorageError, Failure>) -> Return where Failure: Error {
        let buffer: Bytes.SubSequence
        do {
            buffer = try self.read(count)
        } catch {
            throw .first(error)
        }
        do {
            var storage = ZipMemoryStorage<Bytes.SubSequence>(buffer)
            return try operation(&storage)
        } catch {
            throw .second(error)
        }
    }

    @inlinable
    @discardableResult
    public mutating func seek(_ baseOffset: Int64) throws(ZipStorageError) -> Int64 {
        do {
            try self.buffer.seek(numericCast(baseOffset))
            return numericCast(self.buffer.index)
        } catch {
            throw .init(from: error)
        }
    }

    @inlinable
    @discardableResult
    public mutating func seekOffset(_ offset: Int64) throws(ZipStorageError) -> Int64 {
        do {
            return try numericCast(self.buffer.seekOffset(numericCast(offset)))
        } catch {
            throw .init(from: error)
        }
    }

    @inlinable
    @discardableResult
    public mutating func seekEnd(_ offset: Int64 = 0) throws(ZipStorageError) -> Int64 {
        do {
            return try numericCast(self.buffer.seekEnd(numericCast(offset)))
        } catch {
            throw .init(from: error)
        }
    }

    @inlinable
    public var length: Int { self.buffer.length }

    /// Read integer from buffer
    /// - Parameter as: Integer type to read
    /// - Returns: Value read from storage
    /// - Throws: ``ZipStorageError``
    @inlinable
    public mutating func readInteger<T: FixedWidthInteger & BitwiseCopyable>(
        as: T.Type = T.self
    ) throws(ZipStorageError) -> T {
        let buffer = try read(MemoryLayout<T>.size)
        var value: T = 0
        withUnsafeMutableBytes(of: &value) { valuePtr in
            valuePtr.copyBytes(from: buffer)
        }
        return value.littleEndian
    }

    /// Read string of length from buffer
    /// - Parameter length: Length of string in bytes.
    /// - Returns: String read from storage
    /// - Throws: ``ZipStorageError``
    @inlinable
    public mutating func readString(length: Int) throws(ZipStorageError) -> String {
        let buffer = try read(length)
        return String(decoding: buffer, as: UTF8.self)
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
        let bytes = try read(size)
        var buffer = MemoryBuffer(bytes)
        do {
            return try buffer.readIntegers(repeat (each type))
        } catch {
            throw .init(from: error)
        }
    }
}

extension ZipMemoryStorage: ZipWriteableStorage where Bytes: RangeReplaceableCollection {
    @inlinable
    public init() {
        self.init(.init())
    }

    @inlinable
    public mutating func write<WriteBytes: Collection>(bytes: WriteBytes) where WriteBytes.Element == UInt8 {
        self.buffer.write(bytes: bytes)
    }

    @inlinable
    public mutating func truncate(_ size: Int64) throws(ZipStorageError) {
        do {
            try self.buffer.truncate(size)
        } catch {
            throw .init(from: error)
        }
    }
}

extension ZipStorageError {
    @usableFromInline
    init(from memoryBufferError: MemoryBufferError) {
        switch memoryBufferError {
        case MemoryBufferError.readingPastEndOfBuffer:
            self = .readingPastEndOfFile
        case MemoryBufferError.offsetOutOfRange:
            self = .fileOffsetOutOfRange
        }
    }
}

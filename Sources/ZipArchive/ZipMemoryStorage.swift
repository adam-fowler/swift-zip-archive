//
// This source file is part of the swift-zip-archive project
// Copyright (c) 2025-2026 the swift-zip-archive project authors
//
// See LICENSE for license information
// SPDX-License-Identifier: Apache-2.0
//

#if canImport(FoundationEssentials)
public import FoundationEssentials
#else
public import Foundation
#endif

/// Storage in a memory buffer
public struct ZipMemoryStorage<Bytes: ContiguousBytes & Collection>: ZipReadableStorage
where Bytes.Element == UInt8, Bytes.Index == Int, Bytes.SubSequence: ContiguousBytes, Bytes.SubSequence.SubSequence: ContiguousBytes {
    @usableFromInline
    var buffer: MemoryBuffer<Bytes>

    @inlinable
    init(_ buffer: Bytes) {
        self.buffer = .init(buffer)
    }

    public func currentPosition() throws(ZipStorageError) -> Int64 {
        Int64(self.buffer.position)
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

//
// This source file is part of the swift-zip-archive project
// Copyright (c) 2025-2026 the swift-zip-archive project authors
//
// See LICENSE for license information
// SPDX-License-Identifier: Apache-2.0
//

/// Storage in a memory buffer
public final class ZipMemoryStorage<Bytes: RangeReplaceableCollection>: ZipReadableStorage, ZipWriteableStorage
where Bytes.Element == UInt8, Bytes.Index == Int {
    @usableFromInline
    var buffer: MemoryBuffer<Bytes>

    @inlinable
    public init() {
        self.buffer = .init()
    }

    @inlinable
    init(_ buffer: Bytes) {
        self.buffer = .init(buffer)
    }

    @inlinable
    public func read(_ count: Int) throws(ZipStorageError) -> Bytes.SubSequence {
        do {
            return try self.buffer.read(count)
        } catch {
            throw .init(from: error)
        }
    }

    @inlinable
    public func write<WriteBytes: Collection>(bytes: WriteBytes) where WriteBytes.Element == UInt8 {
        self.buffer.write(bytes: bytes)
    }

    @inlinable
    public func truncate(_ size: Int64) throws(ZipStorageError) {
        do {
            try self.buffer.truncate(size)
        } catch {
            throw .init(from: error)
        }
    }

    @inlinable
    @discardableResult
    public func seek(_ baseOffset: Int64) throws(ZipStorageError) -> Int64 {
        do {
            try self.buffer.seek(numericCast(baseOffset))
            return numericCast(self.buffer.position)
        } catch {
            throw .init(from: error)
        }
    }

    @inlinable
    @discardableResult
    public func seekOffset(_ offset: Int64) throws(ZipStorageError) -> Int64 {
        do {
            try self.buffer.seekOffset(numericCast(offset))
            return numericCast(self.buffer.position)
        } catch {
            throw .init(from: error)
        }
    }

    @inlinable
    @discardableResult
    public func seekEnd(_ offset: Int64 = 0) throws(ZipStorageError) -> Int64 {
        do {
            try self.buffer.seekEnd(numericCast(offset))
            return numericCast(self.buffer.position)
        } catch {
            throw .init(from: error)
        }
    }

    @inlinable
    public var length: Int { self.buffer.length }
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

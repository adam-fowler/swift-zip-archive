//
// This source file is part of the swift-zip-archive project
// Copyright (c) 2025-2026 the swift-zip-archive project authors
//
// See LICENSE for license information
// SPDX-License-Identifier: Apache-2.0
//

/// Storage in a memory buffer
public final class ZipMemoryStorage<Bytes: Collection>: ZipReadableStorage
where Bytes.Element == UInt8, Bytes.Index == Int {
    @usableFromInline
    var buffer: MemoryBuffer<Bytes>

    @inlinable
    init(_ buffer: Bytes) {
        self.buffer = .init(buffer)
    }

    @inlinable
    public func read(_ count: Int) throws(ZipStorageError) -> Bytes.SubSequence {
        try self.buffer.read(count)
    }

    @inlinable
    @discardableResult
    public func seek(_ baseOffset: Int64) throws(ZipStorageError) -> Int64 {
        try self.buffer.seek(numericCast(baseOffset))
        return numericCast(self.buffer.index)
    }

    @inlinable
    @discardableResult
    public func seekOffset(_ offset: Int64) throws(ZipStorageError) -> Int64 {
        try numericCast(self.buffer.seekOffset(numericCast(offset)))
    }

    @inlinable
    @discardableResult
    public func seekEnd(_ offset: Int64 = 0) throws(ZipStorageError) -> Int64 {
        try numericCast(self.buffer.seekEnd(numericCast(offset)))
    }

    @inlinable
    public var length: Int { self.buffer.length }
}

extension ZipMemoryStorage: ZipWriteableStorage where Bytes: RangeReplaceableCollection {
    @inlinable
    public convenience init() {
        self.init(.init())
    }

    @inlinable
    public func write<WriteBytes: Collection>(bytes: WriteBytes) where WriteBytes.Element == UInt8 {
        self.buffer.write(bytes: bytes)
    }

    @inlinable
    public func truncate(_ size: Int64) throws(ZipStorageError) {
        try self.buffer.truncate(size)
    }
}

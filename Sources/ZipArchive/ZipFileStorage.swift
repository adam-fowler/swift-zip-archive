//
// This source file is part of the swift-zip-archive project
// Copyright (c) 2025-2026 the swift-zip-archive project authors
//
// See LICENSE for license information
// SPDX-License-Identifier: Apache-2.0
//

import SystemPackage

/// Zip storage on disk
public struct ZipFileStorage: ZipReadableStorage, ZipWriteableStorage {
    @usableFromInline
    let fileDescriptor: FileDescriptor
    @usableFromInline
    let length: Int64

    @inlinable
    init(_ fileDescriptor: FileDescriptor) throws {
        self.fileDescriptor = fileDescriptor
        self.length = try fileDescriptor.seek(offset: 0, from: .end)
        _ = try fileDescriptor.seek(offset: 0, from: .start)
    }

    @inlinable
    public func read(_ count: Int) throws(ZipStorageError) -> [UInt8] {
        guard count >= 0 else { throw .fileOffsetOutOfRange }
        guard count > 0 else { return [] }
        let buffer: [UInt8]
        do {
            buffer = try .init(unsafeUninitializedCapacity: count) { buffer, readCount in
                readCount = try self.fileDescriptor.read(into: .init(buffer))
            }
        } catch {
            throw .internalError
        }
        guard buffer.count == count else { throw ZipStorageError.readingPastEndOfFile }
        return buffer
    }

    @inlinable
    @discardableResult
    public func seek(_ index: Int64) throws(ZipStorageError) -> Int64 {
        do {
            let offset = try self.fileDescriptor.seek(offset: index, from: .start)
            return offset
        } catch let error as Errno where error == .invalidArgument {
            throw .fileOffsetOutOfRange
        } catch {
            throw .internalError
        }
    }

    @inlinable
    @discardableResult
    public func seekOffset(_ offset: Int64) throws(ZipStorageError) -> Int64 {
        do {
            let offset = try self.fileDescriptor.seek(offset: offset, from: .current)
            return offset
        } catch let error as Errno where error == .invalidArgument {
            throw .fileOffsetOutOfRange
        } catch {
            throw .internalError
        }
    }

    @inlinable
    @discardableResult
    public func seekEnd(_ offset: Int64 = 0) throws(ZipStorageError) -> Int64 {
        do {
            let offset = try self.fileDescriptor.seek(offset: offset, from: .end)
            return offset
        } catch {
            throw .internalError
        }
    }

    public func write<Bytes>(bytes: Bytes) throws(ZipStorageError) where Bytes: Collection, Bytes.Element == UInt8 {
        do {
            guard
                try bytes.withContiguousStorageIfAvailable({ buffer in
                    try self.fileDescriptor.write(.init(buffer))
                }) != nil
            else {
                throw ZipStorageError.internalError
            }
        } catch {
            throw .internalError
        }
    }

    public func truncate(_ size: Int64) throws(ZipStorageError) {
        do {
            try self.fileDescriptor.resize(to: size)
        } catch {
            throw .internalError
        }
    }
}

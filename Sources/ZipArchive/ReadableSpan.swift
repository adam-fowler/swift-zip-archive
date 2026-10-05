//
// This source file is part of the swift-zip-archive project
// Copyright (c) 2025-2026 the swift-zip-archive project authors
//
// See LICENSE for license information
// SPDX-License-Identifier: Apache-2.0
//

@inlinable
public struct ZipReadableSpanStorage: ZipReadableStorage, ~Copyable, ~Escapable {
    @inlinable
    public mutating func read(_ count: Int) throws(ZipStorageError) -> [UInt8] {
        let newPosition = position + count
        guard newPosition <= self.upperBound else { throw ZipStorageError.readingPastEndOfFile }
        defer { position = newPosition }
        return [UInt8].init(capacity: count) { outputBytes in
            outputBytes.withUnsafeMutableBufferPointer { outputBuffer, outputCount in
                let extracted = bytes.extracting(position..<position + count)
                _ = extracted.withUnsafeBytes { buffer in
                    outputBuffer.update(fromContentsOf: buffer)
                }
                outputCount = count
            }
        }
    }

    @inlinable
    public mutating func withBytesReadIntoTemporaryBuffer<Return>(count: Int, operation: (RawSpan) throws -> Return) throws -> Return {
        let newPosition = position + count
        guard newPosition <= self.upperBound else { throw ZipStorageError.readingPastEndOfFile }
        defer { position = newPosition }
        return try operation(self.bytes.extracting(position..<newPosition))
    }

    @inlinable
    public mutating func seek(_ index: Int64) throws(ZipStorageError) -> Int64 {
        let newPosition = self.lowerBound + Int(index)
        guard newPosition <= self.upperBound && newPosition >= lowerBound else { throw .readingPastEndOfFile }
        self.position = newPosition
    }

    @inlinable
    public mutating func seekOffset(_ offset: Int64) throws(ZipStorageError) -> Int64 {
        let newPosition = self.position + Int(offset)
        guard newPosition <= self.upperBound && newPosition >= lowerBound else { throw .readingPastEndOfFile }
        self.position = newPosition
    }

    @inlinable
    public mutating func seekEnd(_ offset: Int64) throws(ZipStorageError) -> Int64 {
        let newPosition = self.upperBound + Int(offset)
        guard newPosition <= self.upperBound && newPosition >= lowerBound else { throw .readingPastEndOfFile }
        self.position = newPosition
    }

    @usableFromInline
    let bytes: RawSpan
    @usableFromInline
    var position: Int
    @usableFromInline
    let lowerBound: Int
    @usableFromInline
    let upperBound: Int

    @inlinable
    @_lifetime(copy bytes)
    public init(_ bytes: RawSpan) {
        self.bytes = bytes
        self.position = 0
        self.lowerBound = 0
        self.upperBound = bytes.byteCount
    }

    @unsafe
    @inlinable
    #if compiler(<6.3)
    @_lifetime(copy self)
    #endif
    mutating func consumeUnchecked<T: FixedWidthInteger & BitwiseCopyable>(
        as: T.Type
    ) -> T {
        defer { position += MemoryLayout<T>.stride }
        return unsafe bytes.unsafeLoadUnaligned(
            fromByteOffset: position,
            as: T.self
        )
    }

    @unsafe
    @inlinable
    @_lifetime(copy self)
    mutating func consumeUnchecked(count: Int) -> RawSpan {
        let upperBound = position + count
        defer { position = upperBound }
        return self.bytes.extracting(unchecked: position..<upperBound)
    }
}

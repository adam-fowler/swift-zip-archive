//
// This source file is part of the swift-zip-archive project
// Copyright (c) 2025-2026 the swift-zip-archive project authors
//
// See LICENSE for license information
// SPDX-License-Identifier: Apache-2.0
//

@usableFromInline
struct MemoryBuffer<Bytes: Collection> where Bytes.Element == UInt8, Bytes.Index == Int {
    @usableFromInline
    var buffer: Bytes.SubSequence
    @usableFromInline
    internal var index: Bytes.Index

    var position: Bytes.Index { self.index - self.buffer.startIndex }

    @usableFromInline
    init(size: Int) where Bytes == [UInt8] {
        self.buffer = .init(repeating: 0, count: size)[...]
        self.index = self.buffer.startIndex
    }

    @usableFromInline
    init(_ buffer: Bytes) {
        self.buffer = buffer[...]
        self.index = self.buffer.startIndex
    }

    @usableFromInline
    mutating func read(_ count: Int) throws(ZipStorageError) -> Bytes.SubSequence {
        guard count >= 0, count <= buffer.distance(from: self.index, to: self.buffer.endIndex) else {
            throw .readingPastEndOfFile
        }
        let position = self.index
        self.index = buffer.index(self.index, offsetBy: count)
        return self.buffer[position..<self.index]
    }

    @usableFromInline
    mutating func seek(_ baseOffset: Int) throws(ZipStorageError) {
        guard baseOffset <= self.buffer.count && baseOffset >= 0 else { throw .fileOffsetOutOfRange }
        self.index = buffer.index(self.buffer.startIndex, offsetBy: baseOffset)
    }

    @usableFromInline
    @discardableResult
    mutating func seekOffset(_ offset: Int) throws(ZipStorageError) -> Int {
        let baseOffset = self.buffer.index(self.index, offsetBy: offset)
        guard (self.buffer.startIndex...self.buffer.endIndex).contains(baseOffset) else { throw .fileOffsetOutOfRange }
        self.index = baseOffset
        return self.index - self.buffer.startIndex
    }

    @usableFromInline
    @discardableResult
    mutating func seekEnd(_ offset: Int = 0) throws(ZipStorageError) -> Int {
        let baseOffset = self.buffer.index(self.buffer.endIndex, offsetBy: offset)
        guard (self.buffer.startIndex...self.buffer.endIndex).contains(baseOffset) else { throw .fileOffsetOutOfRange }
        self.index = baseOffset
        return self.index - self.buffer.startIndex
    }

    @usableFromInline
    mutating func truncate(_ size: Int64) throws(ZipStorageError) {
        guard size <= self.buffer.count else { throw .fileOffsetOutOfRange }
        let endIndex = self.buffer.index(self.buffer.startIndex, offsetBy: numericCast(size))
        self.buffer = self.buffer[..<endIndex]
        self.index = self.buffer.endIndex
    }

    @usableFromInline
    var length: Int { self.buffer.count }

    @inlinable
    public mutating func readInteger<T: FixedWidthInteger>(
        as: T.Type = T.self
    ) throws(ZipStorageError) -> T {
        let buffer = try read(MemoryLayout<T>.size)
        var value: T = 0
        withUnsafeMutableBytes(of: &value) { valuePtr in
            valuePtr.copyBytes(from: buffer)
        }
        return value.littleEndian
    }

    @inlinable
    public mutating func readIntegers<each T: FixedWidthInteger>(_ type: repeat (each T).Type) throws(ZipStorageError) -> (repeat each T) {
        (repeat try self.readInteger(as: (each T).self))
    }
}

extension MemoryBuffer: CustomStringConvertible {
    @usableFromInline
    var description: String {
        if self.buffer.count > 50 {
            let endIndex = self.buffer.index(self.buffer.startIndex, offsetBy: 50)
            return "[\(self.buffer[..<endIndex].map{String($0)}.joined(separator: ", ")), ...]"
        } else {
            return "[\(self.buffer.map{String($0)}.joined(separator: ", "))]"
        }
    }
}

extension MemoryBuffer where Bytes: RangeReplaceableCollection {
    @usableFromInline
    init() {
        self.buffer = Bytes()[...]
        self.index = self.buffer.startIndex
    }

    @usableFromInline
    mutating func write<WriteBytes: Collection>(bytes: WriteBytes) where WriteBytes.Element == UInt8 {
        if self.index == self.buffer.endIndex {
            self.buffer.append(contentsOf: bytes)
            self.index = self.buffer.endIndex
        } else if bytes.count <= buffer.distance(from: self.index, to: self.buffer.endIndex) {
            let replaceEndIndex = buffer.index(self.index, offsetBy: bytes.count)
            self.buffer.replaceSubrange(self.index..<replaceEndIndex, with: bytes)
            self.index = replaceEndIndex
        } else {
            self.buffer.replaceSubrange(self.index..., with: bytes)
            self.index = self.buffer.endIndex
        }
    }

    @inlinable
    mutating func writeString(_ string: String) {
        self.write(bytes: string.utf8)
    }

    @inlinable
    mutating func writeInteger<T: FixedWidthInteger>(
        _ value: T
    ) {
        withUnsafeBytes(of: value.littleEndian) { valuePtr in
            write(bytes: valuePtr)
        }
    }

    @inlinable
    mutating func writeIntegers<each T: FixedWidthInteger>(_ value: repeat each T) {
        (repeat self.writeInteger(each value))
    }
}

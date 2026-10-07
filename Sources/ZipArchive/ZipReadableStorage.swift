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

/// Protocol for storage that can be read from
public protocol ZipReadableStorage: ZipStorage, ~Copyable, ~Escapable {
    /// Buffer type returned by `read`
    associatedtype OutputBuffer: ContiguousBytes, Collection where OutputBuffer.Element == UInt8, OutputBuffer.Index == Int
    ///  Read so many bytes from storage
    /// - Parameters
    ///   - count: Number of bytes to read
    /// - Returns: Bytes read from storage
    /// - Throws: ``ZipStorageError``
    mutating func read(_ count: Int) throws(ZipStorageError) -> OutputBuffer
    ///  Read so many bytes from storage and return as Array
    /// - Parameters
    ///   - count: Number of bytes to read
    /// - Returns: Bytes read from storage
    /// - Throws: ``ZipStorageError``
    mutating func readBytes(length: Int) throws(ZipStorageError) -> [UInt8]
    /// Seek to position in storage
    /// - Parameters
    ///   - index: Absolute offset in file
    /// - Throws: ``ZipStorageError``
    @discardableResult mutating func seek(_ index: Int64) throws(ZipStorageError) -> Int64
    /// Seek to position relative to current position
    /// - Parameters
    ///   - offset: Relative offset in file
    /// - Returns: Absolute offset after seek
    /// - Throws: ``ZipStorageError``
    @discardableResult mutating func seekOffset(_ offset: Int64) throws(ZipStorageError) -> Int64
    ///  Seek to position relative to end of file
    /// - Parameter offset: Offset relative to end of file
    /// - Returns: Absolute offset after seek
    /// - Throws: ``ZipStorageError``
    @discardableResult mutating func seekEnd(_ offset: Int64) throws(ZipStorageError) -> Int64
}

extension ZipReadableStorage where Self: ~Copyable & ~Escapable {
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

    /// Read buffer and copy into array of `UInt8`
    /// - Parameter length: Length of buffer to read
    /// - Returns: Array read from storage
    /// - Throws: ``ZipStorageError``
    @inlinable
    public mutating func readBytes(length: Int) throws(ZipStorageError) -> [UInt8] {
        let buffer = try read(length)
        return .init(buffer)
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

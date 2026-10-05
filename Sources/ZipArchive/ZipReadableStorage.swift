//
// This source file is part of the swift-zip-archive project
// Copyright (c) 2025-2026 the swift-zip-archive project authors
//
// See LICENSE for license information
// SPDX-License-Identifier: Apache-2.0
//

public enum EitherError<First: Error, Second: Error>: Error {
    /// An error of the first type.
    case first(First)

    /// An error of the second type.
    case second(Second)
}

/// Protocol for storage that can be read from
public protocol ZipReadableStorage: ZipStorage, ~Copyable, ~Escapable {
    /// Buffer type returned by `read`
    associatedtype OutputBuffer

    ///  Read so many bytes from storage
    /// - Parameters
    ///   - count: Number of bytes to read
    /// - Returns: Bytes read from storage
    /// - Throws: ``ZipStorageError``
    mutating func read(_ count: Int) throws(ZipStorageError) -> OutputBuffer
    ///  Read so many bytes from storage into temporary buffer
    /// - Parameters
    ///   - count: Number of bytes to read
    ///   - operation: Operation to run on bytes
    /// - Returns: Bytes read from storage
    /// - Throws: ``ZipStorageError``
    mutating func withBytesReadIntoTemporaryBuffer<Return, Failure>(
        count: Int,
        operation: (RawSpan) throws(Failure) -> Return
    ) throws(EitherError<ZipStorageError, Failure>) -> Return
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
    /// Read integer from buffer
    /// - Parameter as: Integer type to read
    /// - Returns: Value read from storage
    /// - Throws: ``ZipStorageError``
    mutating func readInteger<T: FixedWidthInteger & BitwiseCopyable>(
        as: T.Type
    ) throws(ZipStorageError) -> T
    /// Read string of length from buffer
    /// - Parameter length: Length of string in bytes.
    /// - Returns: String read from storage
    /// - Throws: ``ZipStorageError``
    mutating func readString(length: Int) throws(ZipStorageError) -> String
    /// Read a list of integers from storage
    /// - Parameter type: list of integer types to read
    /// - Returns: Integers read from storage
    /// - Throws: ``ZipStorageError``
    mutating func readIntegers<each T: FixedWidthInteger>(_ type: repeat (each T).Type) throws(ZipStorageError) -> (repeat each T)
}

extension ZipReadableStorage where Self: ~Copyable & ~Escapable {
    public mutating func currentPosition() throws(ZipStorageError) -> Int64 {
        try seekOffset(0)
    }
}

extension ZipReadableStorage where Self: ~Copyable & ~Escapable {
    /// Read integer from buffer
    /// - Parameter as: Integer type to read
    /// - Returns: Value read from storage
    /// - Throws: ``ZipStorageError``
    @inlinable
    public mutating func readInteger<T: FixedWidthInteger & BitwiseCopyable>(
        as: T.Type = T.self
    ) throws -> T {
        let size = MemoryLayout<T>.size
        return try withBytesReadIntoTemporaryBuffer(count: size) { bytes in
            bytes.unsafeLoad(
                fromUncheckedByteOffset: 0,
                as: T.self
            )
        }
    }

    /// Read string of length from buffer
    /// - Parameter length: Length of string in bytes.
    /// - Returns: String read from storage
    /// - Throws: ``ZipStorageError``
    @inlinable
    public mutating func readString(length: Int) throws -> String {
        try withBytesReadIntoTemporaryBuffer(count: length) { bytes in
            bytes.withUnsafeBytes { bytes in
                String(decoding: bytes, as: UTF8.self)
            }
        }
    }

    /// Read a list of integers from storage
    /// - Parameter type: list of integer types to read
    /// - Returns: Integers read from storage
    /// - Throws: ``ZipStorageError``
    @inlinable
    public mutating func readIntegers<each T: FixedWidthInteger>(_ type: repeat (each T).Type) throws(ZipStorageError) -> (repeat each T) {
        func memorySize<Value>(_ value: Value.Type) -> Int {
            MemoryLayout<Value>.size
        }
        var size = 0
        for t in repeat each type {
            size += memorySize(t)
        }
        return try withBytesReadIntoTemporaryBuffer(count: size) { bytes in
            var spanStorage = ZipReadableSpanStorage(bytes)
            return try spanStorage.readIntegers(repeat (each type))
        }
    }
}

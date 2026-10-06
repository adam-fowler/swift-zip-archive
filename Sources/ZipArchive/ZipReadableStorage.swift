//
// This source file is part of the swift-zip-archive project
// Copyright (c) 2025-2026 the swift-zip-archive project authors
//
// See LICENSE for license information
// SPDX-License-Identifier: Apache-2.0
//

public enum EitherError<First: Error, Second: Error>: Error {
    case first(First)
    case second(Second)
}

/// Protocol for storage that can be read from
public protocol ZipReadableStorage: ZipStorage {
    /// Buffer type returned by `read`
    associatedtype OutputBuffer: Collection where OutputBuffer.Element == UInt8, OutputBuffer.Index == Int
    /// Buffer type returned by `read`
    associatedtype TempStorage: ZipReadableStorage
    ///  Read so many bytes from storage
    /// - Parameters
    ///   - count: Number of bytes to read
    /// - Returns: Bytes read from storage
    /// - Throws: ``ZipStorageError``
    func read(_ count: Int) throws(ZipStorageError) -> OutputBuffer
    ///  Read so many bytes from storage and store in temporary buffer
    /// - Parameters
    ///   - count: Number of bytes to read
    ///   - operation: closure provided temporary bytes
    /// - Throws: ``EitherError`` holding either a ``ZipStorageError`` or the error returned by the operation closure
    func withInMemoryStorage<Return, Failure>(
        _ count: Int,
        operation: (TempStorage) throws(Failure) -> Return
    ) throws(EitherError<ZipStorageError, Failure>) -> Return
    /// Read integer from buffer
    /// - Parameter as: Integer type to read
    /// - Returns: Value read from storage
    /// - Throws: ``ZipStorageError``
    func readInteger<T: FixedWidthInteger & BitwiseCopyable>(
        as: T.Type
    ) throws(ZipStorageError) -> T
    /// Read string of length from buffer
    /// - Parameter length: Length of string in bytes.
    /// - Returns: String read from storage
    /// - Throws: ``ZipStorageError``
    func readString(length: Int) throws(ZipStorageError) -> String
    /// Read a list of integers from storage
    /// - Parameter type: list of integer types to read
    /// - Returns: Integers read from storage
    /// - Throws: ``ZipStorageError``
    func readIntegers<each T: FixedWidthInteger & BitwiseCopyable>(_ type: repeat (each T).Type) throws(ZipStorageError) -> (repeat each T)

    /// Seek to position in storage
    /// - Parameters
    ///   - index: Absolute offset in file
    /// - Throws: ``ZipStorageError``
    @discardableResult func seek(_ index: Int64) throws(ZipStorageError) -> Int64
    /// Seek to position relative to current position
    /// - Parameters
    ///   - offset: Relative offset in file
    /// - Returns: Absolute offset after seek
    /// - Throws: ``ZipStorageError``
    @discardableResult func seekOffset(_ offset: Int64) throws(ZipStorageError) -> Int64
    ///  Seek to position relative to end of file
    /// - Parameter offset: Offset relative to end of file
    /// - Returns: Absolute offset after seek
    /// - Throws: ``ZipStorageError``
    @discardableResult func seekEnd(_ offset: Int64) throws(ZipStorageError) -> Int64
}

extension ZipReadableStorage {
    public func currentPosition() throws(ZipStorageError) -> Int64 {
        try seekOffset(0)
    }
}

extension ZipReadableStorage {
    /// Read integer from buffer
    /// - Parameter as: Integer type to read
    /// - Returns: Value read from storage
    /// - Throws: ``ZipStorageError``
    @inlinable
    public func readInteger<T: FixedWidthInteger & BitwiseCopyable>(
        as: T.Type = T.self
    ) throws(ZipStorageError) -> T {
        do {
            return try withInMemoryStorage(MemoryLayout<T>.size) { (storage) throws(ZipStorageError) in
                try storage.readInteger()
            }
        } catch {
            switch error {
            case .first(let error): throw error
            case .second(let error): throw error
            }
        }
    }

    /// Read string of length from buffer
    /// - Parameter length: Length of string in bytes.
    /// - Returns: String read from storage
    /// - Throws: ``ZipStorageError``
    @inlinable
    public func readString(length: Int) throws(ZipStorageError) -> String {
        do {
            return try withInMemoryStorage(length) { (storage) throws(ZipStorageError) in
                try storage.readString(length: length)
            }
        } catch {
            switch error {
            case .first(let error): throw error
            case .second(let error): throw error
            }
        }
    }

    /// Read a list of integers from storage
    /// - Parameter type: list of integer types to read
    /// - Returns: Integers read from storage
    /// - Throws: ``ZipStorageError``
    @inlinable
    public func readIntegers<each T: FixedWidthInteger & BitwiseCopyable>(_ type: repeat (each T).Type) throws(ZipStorageError) -> (repeat each T) {
        func memorySize<Value>(_ value: Value.Type) -> Int {
            MemoryLayout<Value>.size
        }
        var size = 0
        for t in repeat each type {
            size += memorySize(t)
        }
        do {
            return try withInMemoryStorage(size) { (storage) throws(ZipStorageError) in
                try storage.readIntegers(repeat each type)
            }
        } catch {
            switch error {
            case .first(let error): throw error
            case .second(let error): throw error
            }
        }
    }
}

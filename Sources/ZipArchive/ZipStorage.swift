/// Protocol for storage of a Zip archive
public protocol ZipStorage {
    func currentPosition() throws(ZipStorageError) -> Int64
}

/// Protocol for storage that can be read from
public protocol ZipReadableStorage: ZipStorage {
    /// Buffer type returned by `read`
    associatedtype Buffer: RangeReplaceableCollection where Buffer.Element == UInt8, Buffer.Index == Int
    ///  Read so many bytes from storage
    /// - Parameter count: Number of bytes to read
    /// - Throws: ``ZipStorageError``
    /// - Returns: Bytes read from storage
    func read(_ count: Int) throws(ZipStorageError) -> Buffer
    /// Seek to position in storage
    /// - Parameter index: Absolute offset in file
    /// - Throws: ``ZipStorageError``
    @discardableResult func seek(_ index: Int64) throws(ZipStorageError) -> Int64
    /// Seek to position relative to current position
    /// - Parameter offset: Relative offset in file
    /// - Throws: ``ZipStorageError``
    /// - Returns: Absolute offset after seek
    @discardableResult func seekOffset(_ offset: Int64) throws(ZipStorageError) -> Int64
    ///  Seek to position relative to end of file
    /// - Parameter offset: Offset relative to end of file
    /// - Throws: ``ZipStorageError``
    /// - Returns: Absolute offset after seek
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
    /// - Throws: ``ZipStorageError``
    /// - Returns: Value read from storage
    @inlinable
    public func readInteger<T: FixedWidthInteger>(
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
    /// - Throws: ``ZipStorageError``
    /// - Returns: String read from storage
    @inlinable
    public func readString(length: Int) throws(ZipStorageError) -> String {
        let buffer = try read(length)
        return String(decoding: buffer, as: UTF8.self)
    }

    /// Read buffer and copy into array of `UInt8`
    /// - Parameter length: Length of buffer to read
    /// - Throws: ``ZipStorageError``
    /// - Returns: Array read from storage
    @inlinable
    public func readBytes(length: Int) throws(ZipStorageError) -> [UInt8] {
        let buffer = try read(length)
        return .init(buffer)
    }

    /// Read a list of integers from storage
    /// - Parameter type: list of integer types to read
    /// - Throws: ``ZipStorageError``
    /// - Returns: Integers read from storage
    @inlinable
    public func readIntegers<each T: FixedWidthInteger>(_ type: repeat (each T).Type) throws(ZipStorageError) -> (repeat each T) {
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

/// Protocol for storage that can be written to
public protocol ZipWriteableStorage: ZipStorage {
    /// Write buffer to storage
    /// - Parameter bytes: Buffer to write to storage
    /// - Throws: ``ZipStorageError``
    func write<Bytes: Collection>(bytes: Bytes) throws(ZipStorageError) where Bytes.Element == UInt8

    ///  Drop storage after offset in storage and seek to that position
    /// - Parameter size: Size of truncated storage
    /// - Throws: ``ZipStorageError``
    func truncate(_ size: Int64) throws(ZipStorageError)
}

extension ZipWriteableStorage {
    /// Write string to storage
    /// - Parameter string: String to write
    /// - Throws: ``ZipStorageError``
    @inlinable
    public func writeString(_ string: String) throws(ZipStorageError) {
        try self.write(bytes: string.utf8)
    }

    /// Write integer to storage
    /// - Parameter value: Integer to write
    /// - Throws: ``ZipStorageError``
    @inlinable
    public func writeInteger<T: FixedWidthInteger>(
        _ value: T
    ) throws(ZipStorageError) {
        do {
            try withUnsafeBytes(of: value.littleEndian) { valuePtr in
                try write(bytes: valuePtr)
            }
        } catch let error as ZipStorageError {
            throw error
        } catch {
            throw .internalError
        }
    }

    ///  Write a list of integers to storage
    /// - Parameter value: Integers to write
    /// - Throws: ``ZipStorageError``
    @inlinable
    public func writeIntegers<each T: FixedWidthInteger>(_ value: repeat each T) throws(ZipStorageError) {
        try (repeat self.writeInteger(each value))
    }
}

/// Error thrown by ZipStorage
public struct ZipStorageError: Error {
    internal enum Value {
        case fileOffsetOutOfRange
        case readPastEndOfFile
        case internalError
    }
    internal let value: Value

    /// File offset is outside of size of storage
    public static var fileOffsetOutOfRange: Self { .init(value: .fileOffsetOutOfRange) }
    /// Trying to read past the end of the storage
    public static var readingPastEndOfFile: Self { .init(value: .readPastEndOfFile) }
    /// Internal, should not be thrown. If you receive this please add an issue
    /// to https://github.com/adam-fowler/swift-zip-archive
    public static var internalError: Self { .init(value: .internalError) }
}

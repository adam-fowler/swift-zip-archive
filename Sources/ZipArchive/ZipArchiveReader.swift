//
// This source file is part of the swift-zip-archive project
// Copyright (c) 2025-2026 the swift-zip-archive project authors
//
// See LICENSE for license information
// SPDX-License-Identifier: Apache-2.0
//

import SystemPackage

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// ZipArchiveReader configuration
public struct ZipArchiveReaderConfiguration {
    /// Additional supported compression methods
    public var compressionMethods: [any ZipCompression]

    /// Initialize ZipArchiveReaderConfiguration
    /// - Parameter compressionMethods: Additional supported compression methods
    public init(compressionMethods: [any ZipCompression] = []) {
        self.compressionMethods = compressionMethods
    }
}

/// Zip archive reader type
public final class ZipArchiveReader<Storage: ZipReadableStorage> {
    let storage: Storage
    let endOfCentralDirectoryRecord: Zip.EndOfCentralDirectory
    let compressionMethods: ZipCompressionMethodsMap
    var parsingDirectory: Bool

    init(_ file: Storage, configuration: ZipArchiveReaderConfiguration) throws {
        self.storage = file
        self.endOfCentralDirectoryRecord = try self.storage.readEndOfCentralDirectory()

        let compressionKeyValuePairs = configuration.compressionMethods.map { (key: $0.method, value: $0) }
        self.compressionMethods = [
            Zip.FileCompressionMethod.noCompression: NoZipCompression(),
            Zip.FileCompressionMethod.deflate: ZlibDeflateCompression(),
        ].merging(compressionKeyValuePairs) { first, second in second }

        self.parsingDirectory = false
    }

    /// Initialize ZipArchiveReader to read from a memory buffer
    ///
    /// - Parameters:
    ///   - buffer: Buffer containing zip archive
    ///   - configuration: ZipArchiveReader configuration
    /// - Throws:
    convenience public init<Bytes: RangeReplaceableCollection>(
        buffer: Bytes,
        configuration: ZipArchiveReaderConfiguration = .init()
    ) throws where Bytes.Element == UInt8, Bytes.Index == Int, Storage == ZipMemoryStorage<Bytes> {
        try self.init(ZipMemoryStorage(buffer), configuration: configuration)
    }

    /// Read directory from zip archive into an array
    public func readDirectory() throws -> [Zip.FileHeader] {
        try storage.seek(numericCast(endOfCentralDirectoryRecord.offsetOfCentralDirectory))
        let bytes = try storage.read(numericCast(endOfCentralDirectoryRecord.centralDirectorySize))
        let memoryStorage = ZipMemoryStorage(bytes)
        return try memoryStorage.readDirectory(numEntries: Int(endOfCentralDirectoryRecord.diskEntries))
    }

    /// Parse directory from zip file and run process on each entry
    ///
    /// Use this function if you don't want to load the whole of the zip file directory
    /// into memory
    ///
    /// WARNING: You cannot call `readFile` while parsing the directory
    public func parseDirectory(_ process: (Zip.FileHeader) throws -> Void) throws {
        self.parsingDirectory = true
        defer {
            self.parsingDirectory = false
        }
        try storage.seek(numericCast(endOfCentralDirectoryRecord.offsetOfCentralDirectory))
        for _ in 0..<endOfCentralDirectoryRecord.diskEntries {
            let fileHeader = try self.storage.readFileHeader()
            try process(fileHeader)
        }
    }

    /// Read file from zip file
    ///
    /// - Parameters:
    ///   - file: File header, from zip directory
    ///   - password: Password used to decrypt file
    /// - Returns: Buffer containing file
    public func readFile(_ file: Zip.FileHeader, password: String? = nil) throws -> [UInt8] {
        precondition(self.parsingDirectory == false, "Cannot read file while parsing the directory")
        try self.storage.seek(numericCast(file.offsetOfLocalHeader))
        return try self.storage.readFile(file, password: password, compressionMethods: self.compressionMethods)
    }
}

extension ZipArchiveReader where Storage == ZipFileStorage {
    /// Use ZipArchiveReader to load zip archive from disk and process it contents.
    ///
    /// Opens file, create ``ZipArchiveReader`` using file descriptor, run supplied closure with
    /// ``ZipArchiveReader`` and then close file.
    ///
    /// - Parameters:
    ///   - filename: Filename of zip archive
    ///   - configuration: ZipArchiveReader configuration
    ///   - process: Process to run with ZipArchiveReader
    /// - Returns: Value returned by process function
    public static func withFile<Value>(
        _ filename: String,
        configuration: ZipArchiveReaderConfiguration = .init(),
        process: (ZipArchiveReader) throws -> Value
    ) throws -> Value {
        let fileDescriptor = try FileDescriptor.open(
            .init(filename),
            .readOnly
        )
        return try fileDescriptor.closeAfter {
            let zipArchiveReader = try ZipArchiveReader(ZipFileStorage(fileDescriptor), configuration: configuration)
            return try process(zipArchiveReader)
        }
    }
}

/// Errors received while reading zip archive
public struct ZipArchiveReaderError: Error, Equatable {
    internal enum Value {
        case invalidFileHeader
        case invalidDirectory
        case failedToFindCentralDirectory
        case internalError
        case compressionError
        case unsupportedCompressionMethod
        case failedToReadFromBuffer
        case crc32FileValidationFailed
        case encryptedFilesRequirePassword
    }
    internal let value: Value

    /// Local file header was invalid
    public static var invalidFileHeader: Self { .init(value: .invalidFileHeader) }
    /// Directory entry was invalid
    public static var invalidDirectory: Self { .init(value: .invalidDirectory) }
    /// Failed to find the central directory
    public static var failedToFindCentralDirectory: Self { .init(value: .failedToFindCentralDirectory) }
    /// Internal error, should not be seen. If you receive this please add an issue
    /// to https://github.com/adam-fowler/swift-zip-archive
    public static var internalError: Self { .init(value: .internalError) }
    /// Received an error while trying to decompress data
    public static var compressionError: Self { .init(value: .compressionError) }
    /// Archive uses an unsupported compression method
    public static var unsupportedCompressionMethod: Self { .init(value: .unsupportedCompressionMethod) }
    /// CRC32 validation of file failed
    public static var crc32FileValidationFailed: Self { .init(value: .crc32FileValidationFailed) }
    /// File is encrypted and requires a password
    public static var encryptedFilesRequirePassword: Self { .init(value: .encryptedFilesRequirePassword) }
}

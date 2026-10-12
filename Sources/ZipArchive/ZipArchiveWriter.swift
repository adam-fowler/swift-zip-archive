//
// This source file is part of the swift-zip-archive project
// Copyright (c) 2025-2026 the swift-zip-archive project authors
//
// See LICENSE for license information
// SPDX-License-Identifier: Apache-2.0
//

public import SystemPackage

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Zip Archive writer configuration
public struct ZipArchiveWriterConfiguration {
    /// Compression method to use
    public var compression: any ZipCompression

    ///  Initialize ZipArchiveWriterConfiguration
    /// - Parameter compression: Compression method to use
    public init(compression: any ZipCompression = ZlibDeflateCompression()) {
        self.compression = compression
    }
}

/// Zip archive writer type
public final class ZipArchiveWriter<Storage: ZipWriteableStorage> {
    var storage: Storage
    var endOfCentralDirectoryRecord: Zip.EndOfCentralDirectory
    let directory: [Zip.FileHeader]
    let directoryBuffer: [UInt8]?
    let configuration: ZipArchiveWriterConfiguration
    var newDirectoryEntries: [Zip.FileHeader]

    /// Initialize ZipArchiveWriter
    /// - Parameter configuration: ZipArchiveWriter configuration
    public init(configuration: ZipArchiveWriterConfiguration = .init()) where Storage == ZipMemoryStorage<[UInt8]> {
        self.configuration = configuration
        self.newDirectoryEntries = []
        self.storage = .init()
        self.endOfCentralDirectoryRecord = .init(
            diskNumber: 0,
            diskNumberCentralDirectoryStarts: 0,
            diskEntries: 0,
            totalEntries: 0,
            centralDirectorySize: 0,
            offsetOfCentralDirectory: 0,
            comment: ""
        )
        self.directory = []
        self.directoryBuffer = nil
    }

    ///  Initialize archive writer with zip archive
    ///
    /// - Parameters:
    ///   - buffer: Buffer containing zip archive
    ///   - configuration: ZipArchiveWriter configuration
    convenience public init(
        buffer: [UInt8],
        configuration: ZipArchiveWriterConfiguration = .init()
    ) throws where Storage == ZipMemoryStorage<[UInt8]> {
        try self.init(.init(buffer), appending: true, configuration: configuration)
    }

    ///  Initialize archive writer with zip archive
    ///
    /// - Parameters:
    ///   - buffer: Buffer containing zip archive
    ///   - configuration: ZipArchiveWriter configuration
    convenience public init(
        bytes: ArraySlice<UInt8>,
        configuration: ZipArchiveWriterConfiguration = .init()
    ) throws where Storage == ZipMemoryStorage<ArraySlice<UInt8>> {
        try self.init(.init(bytes), appending: true, configuration: configuration)
    }

    init(_ storage: Storage, appending: Bool, configuration: ZipArchiveWriterConfiguration) throws where Storage: ZipReadableStorage {
        self.configuration = configuration
        self.newDirectoryEntries = []
        self.storage = storage
        if appending {
            let reader = try ZipArchiveReader(storage, configuration: .init())
            self.endOfCentralDirectoryRecord = reader.endOfCentralDirectoryRecord
            // read directory before we truncate it
            try self.storage.seek(endOfCentralDirectoryRecord.offsetOfCentralDirectory)
            // Zip files support a central directory larger then 0xffff_ffff but we don't
            self.directoryBuffer = try self.storage.readBytes(length: numericCast(endOfCentralDirectoryRecord.centralDirectorySize))
            let memoryStorage = ZipMemoryStorage(self.directoryBuffer!)
            self.directory = try memoryStorage.readDirectory(numEntries: Int(endOfCentralDirectoryRecord.diskEntries))
            // truncate zip file
            try self.storage.truncate(endOfCentralDirectoryRecord.offsetOfCentralDirectory)
        } else {
            self.endOfCentralDirectoryRecord = .init(
                diskNumber: 0,
                diskNumberCentralDirectoryStarts: 0,
                diskEntries: 0,
                totalEntries: 0,
                centralDirectorySize: 0,
                offsetOfCentralDirectory: 0,
                comment: ""
            )
            self.directoryBuffer = nil
            self.directory = []
            // truncate zip file
            try self.storage.truncate(0)
        }
    }

    /// Finish writing zip archive to buffer and return buffer
    ///
    /// Writes directory and end of directory sections
    /// - Returns: Buffer containing finalized zip archive
    public func finalizeBuffer() throws -> Storage.OutputBuffer where Storage: ZipMemoryStorage<[UInt8]> {
        try writeDirectory()
        return self.storage.buffer.buffer
    }

    /// Finish writing zip archive to buffer and return buffer
    ///
    /// Writes directory and end of directory sections
    /// - Returns: Buffer containing finalized zip archive
    public func finalizeBuffer() throws -> Storage.OutputBuffer where Storage: ZipMemoryStorage<ArraySlice<UInt8>> {
        try writeDirectory()
        return self.storage.buffer.buffer
    }

    ///  Write file to zip archive
    ///
    /// If any of the files containing folders don't exist in the zip directory they will
    /// also be added.
    /// - Parameters:
    ///   - filename: Filename of file
    ///   - contents: Contents of file
    ///   - password: Password to encrypt file with
    public func writeFile(filename: String, sourceFile: String, password: String? = nil) throws {
        try writeFile(filePath: .init(filename), sourceFilePath: .init(sourceFile), password: password)
    }

    ///  Write file to zip archive
    ///
    /// If any of the files containing folders don't exist in the zip directory they will
    /// also be added.
    /// - Parameters:
    ///   - filePath: File path of file
    ///   - contents: Contents of file
    ///   - password: Password to encrypt file with
    public func writeFile(filePath: FilePath, sourceFilePath: FilePath, password: String? = nil) throws {
        let fileDescriptor = try FileDescriptor.open(
            sourceFilePath,
            .readOnly
        )
        let contents = try fileDescriptor.closeAfter {
            let size: Int = numericCast(try fileDescriptor.seek(offset: 0, from: .end))
            try fileDescriptor.seek(offset: 0, from: .start)
            return try [UInt8].init(unsafeUninitializedCapacity: size) { buffer, initializedCount in
                initializedCount = try fileDescriptor.read(fromAbsoluteOffset: 0, into: .init(buffer))
            }
        }
        try writeFile(filePath: filePath, contents: contents, password: password)
    }

    ///  Write file to zip archive
    ///
    /// If any of the files containing folders don't exist in the zip directory they will
    /// also be added.
    /// - Parameters:
    ///   - filename: Filename of file
    ///   - contents: Contents of file
    ///   - password: Password to encrypt file with
    public func writeFile(filename: String, contents: [UInt8], password: String? = nil) throws {
        try writeFile(filePath: .init(filename), contents: contents, password: password)
    }

    ///  Write file to zip archive
    ///
    /// If any of the files containing folders don't exist in the zip directory they will
    /// also be added.
    /// - Parameters:
    ///   - filePath: File path of file
    ///   - contents: Contents of file
    ///   - password: Password to encrypt file with
    public func writeFile(filePath: FilePath, contents: [UInt8], password: String? = nil) throws {
        let existingFileHeader =
            self.directory.first(where: { $0.filename == filePath })
            ?? self.newDirectoryEntries.first(where: { $0.filename == filePath })
        guard existingFileHeader == nil else {
            throw ZipArchiveWriterError.fileAlreadyExists
        }
        try addFolder(filePath.removingRoot().removingLastComponent())

        let fileHeader = try self.storage.writeFile(filePath: filePath, contents: contents, compression: self.configuration.compression)

        self.newDirectoryEntries.append(fileHeader)
    }

    func addFolder(_ filePath: FilePath) throws {
        guard !filePath.isEmpty else { return }
        let existingFileHeader =
            self.directory.first(where: { $0.filename == filePath })
            ?? self.newDirectoryEntries.first(where: { $0.filename == filePath })
        if let existingFileHeader {
            // if uncompressedSize is zero then we can assume this is a folder (Can we?)
            guard existingFileHeader.uncompressedSize == 0 else {
                throw ZipArchiveWriterError.fileAlreadyExists
            }
            return
        }
        let fileHeader = try self.storage.writeFolder(filePath: filePath)

        self.newDirectoryEntries.append(fileHeader)
    }

    func writeDirectory() throws {
        let centralDirectoryOffset = try storage.currentPosition()

        // write original directory
        if let directoryBuffer {
            try storage.write(bytes: directoryBuffer)
        }
        // write new files to directory
        for file in newDirectoryEntries {
            try self.storage.writeFileHeader(file)
        }
        let centralDirectoryEndOffset = try storage.currentPosition()

        endOfCentralDirectoryRecord.offsetOfCentralDirectory = centralDirectoryOffset
        endOfCentralDirectoryRecord.centralDirectorySize = centralDirectoryEndOffset - centralDirectoryOffset
        endOfCentralDirectoryRecord.diskEntries += numericCast(newDirectoryEntries.count)
        endOfCentralDirectoryRecord.totalEntries += numericCast(newDirectoryEntries.count)

        try self.storage.writeEndOfCentralDirectory(endOfCentralDirectoryRecord)
    }
}

extension ZipArchiveWriter {
    /// Options when writing zip archive to file
    public struct FileOptions: OptionSet {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        /// Create new zip archive
        public static var create: Self { .init(rawValue: (1 << 0)) }
    }

    /// Use ZipArchiveWriter to write to a file
    ///
    /// Opens or creates new file depending on `.create` option. If opening file then read
    /// as zip archive. Run supplied closure and then write zip directory and end of directory
    /// sections and close the file.
    ///
    /// - Parameters:
    ///   - filename: Filename of file
    ///   - options: Options when opening file
    ///   - configuration: ZipArchiveWriter configuration
    ///   - process: Function to call with opened zip archive
    public static func withFile(
        _ filename: String,
        options: FileOptions = [],
        configuration: ZipArchiveWriterConfiguration = .init(),
        process: (
            ZipArchiveWriter
        ) throws -> Void
    ) throws where Storage == ZipFileStorage {
        let fileDescriptor = try FileDescriptor.open(
            .init(filename),
            .readWrite,
            options: options.contains(.create) ? [.create, .truncate] : [],
            permissions: options.contains(.create) ? [.ownerReadWrite, .groupRead, .otherRead] : nil
        )
        return try fileDescriptor.closeAfter {
            let writer = try ZipArchiveWriter<ZipFileStorage>(
                ZipFileStorage(fileDescriptor),
                appending: !options.contains(.create),
                configuration: configuration
            )
            try process(writer)
            try writer.writeDirectory()
        }
    }
}

/// Errors thrown when writing zip archives
public struct ZipArchiveWriterError: Error, Equatable {
    internal enum Value {
        case fileAlreadyExists
    }
    internal let value: Value

    /// File being added to zip archive already exists
    public static var fileAlreadyExists: Self { .init(value: .fileAlreadyExists) }
}

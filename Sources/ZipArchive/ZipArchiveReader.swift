import CZipZlib
import SystemPackage

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// ZipArchiveReader configuration
public struct ZipArchiveReaderConfiguration {
    /// Additional supported compression methods
    public var compressionMethods: [ZipCompression]

    /// Initialize ZipArchiveReaderConfiguration
    /// - Parameter compressionMethods: Additional supported compression methods
    public init(compressionMethods: [ZipCompression] = []) {
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
        self.endOfCentralDirectoryRecord = try Self.readEndOfCentralDirectory(file: file)

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
        return try readDirectory(memoryStorage)
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
            let fileHeader = try self.readFileHeader(from: storage)
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
        let localFileHeader = try readLocalFileHeader()
        guard localFileHeader.filename == file.filename else { throw ZipArchiveReaderError.invalidFileHeader }
        guard let compressor = self.compressionMethods[localFileHeader.compressionMethod] else {
            throw ZipArchiveReaderError.unsupportedCompressionMethod
        }
        var encryptionKeys: [UInt8]?
        var fileSize = localFileHeader.compressedSize
        // if encrypted read encryption header
        if localFileHeader.flags.contains(.encrypted) {
            encryptionKeys = try self.storage.readBytes(length: 12)
            fileSize -= 12
        } else {
            encryptionKeys = nil
        }

        // Read bytes and uncompress
        var fileBytes = try self.storage.readBytes(length: numericCast(fileSize))

        // if we have a password and encryption keys
        if let password, var encryptionKeys {
            var cryptKey = CryptKey(password: password)
            cryptKey.decryptBytes(&encryptionKeys)
            cryptKey.decryptBytes(&fileBytes)
        } else if encryptionKeys != nil {
            throw ZipArchiveReaderError.encryptedFilesRequirePassword
        }
        let uncompressedBytes = try compressor.inflate(from: fileBytes, uncompressedSize: numericCast(localFileHeader.uncompressedSize))
        // Verify CRC32
        let crc = crc32(0, bytes: uncompressedBytes)
        guard crc == localFileHeader.crc32 else {
            throw ZipArchiveReaderError.crc32FileValidationFailed
        }
        return uncompressedBytes
    }

    /// Read directory from byffer
    func readDirectory(_ storage: some ZipReadableStorage) throws -> [Zip.FileHeader] {
        var directory: [Zip.FileHeader] = []
        for _ in 0..<endOfCentralDirectoryRecord.diskEntries {
            let fileHeader = try self.readFileHeader(from: storage)
            directory.append(fileHeader)
        }
        return directory
    }

    func readLocalFileHeader() throws -> Zip.LocalFileHeader {
        let (
            signature, versionNeeded, flags, compression, modTime, modDate, crc32, compressedSize, uncompressedSize, fileNameLength, extraFieldsLength
        ) =
            try storage.readIntegers(
                UInt32.self,
                UInt16.self,
                UInt16.self,
                UInt16.self,
                UInt16.self,
                UInt16.self,
                UInt32.self,
                UInt32.self,
                UInt32.self,
                UInt16.self,
                UInt16.self
            )
        guard signature == Zip.localFileHeaderSignature else { throw ZipArchiveReaderError.invalidFileHeader }
        let filename = try storage.readString(length: numericCast(fileNameLength))
        let extraFieldsBuffer = try storage.readBytes(length: numericCast(extraFieldsLength))
        let extraFields = try readExtraFields(extraFieldsBuffer)

        /// Extract ZIP64 extra field
        var uncompressedSize64: Int64 = numericCast(uncompressedSize)
        var compressedSize64: Int64 = numericCast(compressedSize)
        var fileModification = Date(msdosTime: modTime, msdosDate: modDate)
        for extraField in extraFields {
            switch extraField.header {
            case .zip64:
                var memoryBuffer = MemoryBuffer(extraField.data)
                if uncompressedSize == 0xffff_ffff {
                    uncompressedSize64 = try memoryBuffer.readInteger(as: Int64.self)
                }
                if compressedSize == 0xffff_ffff {
                    compressedSize64 = try memoryBuffer.readInteger(as: Int64.self)
                }

            case .extendedTimestamp:
                var memoryBuffer = MemoryBuffer(extraField.data)
                try memoryBuffer.seekOffset(1)
                let modifiedSince1970 = try memoryBuffer.readInteger(as: Int32.self)
                fileModification = Date(timeIntervalSince1970: Double(modifiedSince1970))

            default:
                break
            }
        }
        guard let compressionMethod = Zip.FileCompressionMethod(rawValue: compression) else {
            throw ZipArchiveReaderError.unsupportedCompressionMethod
        }
        return .init(
            versionNeeded: versionNeeded,
            flags: .init(rawValue: flags),
            compressionMethod: compressionMethod,
            fileModification: fileModification,
            crc32: crc32,
            compressedSize: compressedSize64,
            uncompressedSize: uncompressedSize64,
            filename: .init(filename),
            extraFields: extraFields
        )
    }

    func readFileHeader(from storage: some ZipReadableStorage) throws -> Zip.FileHeader {
        let (
            signature, versionMadeBy, versionNeeded, flags, compression, modTime, modDate, crc32, compressedSize, uncompressedSize, fileNameLength,
            extraFieldsLength, commentLength, diskStart, internalAttribute, externalAttribute, offsetOfLocalHeader
        ) =
            try storage.readIntegers(
                UInt32.self,
                UInt16.self,
                UInt16.self,
                UInt16.self,
                UInt16.self,
                UInt16.self,
                UInt16.self,
                UInt32.self,
                UInt32.self,
                UInt32.self,
                UInt16.self,
                UInt16.self,
                UInt16.self,
                UInt16.self,
                UInt16.self,
                UInt32.self,
                UInt32.self
            )
        guard signature == Zip.fileHeaderSignature else { throw ZipArchiveReaderError.invalidDirectory }

        let filename = try storage.readString(length: numericCast(fileNameLength))
        let extraFieldsBuffer = try storage.readBytes(length: numericCast(extraFieldsLength))
        let comment = try storage.readString(length: numericCast(commentLength))

        let extraFields = try readExtraFields(extraFieldsBuffer)

        /// Extract ZIP64 extra field
        var uncompressedSize64: Int64 = numericCast(uncompressedSize)
        var compressedSize64: Int64 = numericCast(compressedSize)
        var offsetOfLocalHeader64: Int64 = numericCast(offsetOfLocalHeader)
        var diskStart32: UInt32 = numericCast(diskStart)
        var fileModification = Date(msdosTime: modTime, msdosDate: modDate)
        for extraField in extraFields {
            switch extraField.header {
            case .zip64:
                var memoryBuffer = MemoryBuffer(extraField.data)
                if uncompressedSize == 0xffff_ffff {
                    uncompressedSize64 = try memoryBuffer.readInteger(as: Int64.self)
                }
                if compressedSize == 0xffff_ffff {
                    compressedSize64 = try memoryBuffer.readInteger(as: Int64.self)
                }
                if offsetOfLocalHeader == 0xffff_ffff {
                    offsetOfLocalHeader64 = try memoryBuffer.readInteger(as: Int64.self)
                }
                if diskStart == 0xffff {
                    diskStart32 = try memoryBuffer.readInteger(as: UInt32.self)
                }

            case .extendedTimestamp:
                var memoryBuffer = MemoryBuffer(extraField.data)
                try memoryBuffer.seekOffset(1)
                let modifiedSince1970 = try memoryBuffer.readInteger(as: Int32.self)
                fileModification = Date(timeIntervalSince1970: Double(modifiedSince1970))

            default:
                // ignore extra field
                break
            }
        }
        guard let compressionMethod = Zip.FileCompressionMethod(rawValue: compression) else {
            throw ZipArchiveReaderError.unsupportedCompressionMethod
        }
        return .init(
            versionMadeBy: .init(rawValue: versionMadeBy),
            versionNeeded: versionNeeded,
            flags: .init(rawValue: flags),
            compressionMethod: compressionMethod,
            fileModification: fileModification,
            crc32: crc32,
            compressedSize: compressedSize64,
            uncompressedSize: uncompressedSize64,
            filename: .init(filename),
            extraFields: extraFields,
            comment: comment,
            diskStart: diskStart32,
            internalAttribute: internalAttribute,
            externalAttributes: .init(rawValue: externalAttribute),
            offsetOfLocalHeader: offsetOfLocalHeader64
        )
    }

    func readExtraFields(_ buffer: [UInt8]) throws -> [Zip.ExtraField] {
        var extraFieldsBuffer = MemoryBuffer(buffer)
        var extraFields: [Zip.ExtraField] = []
        while extraFieldsBuffer.position < extraFieldsBuffer.length {
            let (header, size) = try extraFieldsBuffer.readIntegers(UInt16.self, UInt16.self)
            let data = try extraFieldsBuffer.read(numericCast(size))
            extraFields.append(.init(header: .init(rawValue: header), data: data))
        }
        return extraFields
    }

    static func readEndOfCentralDirectory(file: some ZipReadableStorage) throws -> Zip.EndOfCentralDirectory {
        _ = try searchForEndOfCentralDirectory(file: file)

        let zip64EndOfCentralLocator: Zip.Zip64EndOfCentralLocator?
        // verify we have space to read the zip64 end of central directory locator, before reading it
        if try file.seekOffset(0) > 20 {
            try file.seekOffset(-20)
            zip64EndOfCentralLocator = try Self.readZip64EndOfCentralLocator(file: file)
        } else {
            zip64EndOfCentralLocator = nil
        }

        let (
            signature, diskNumber, diskNumberCentralDirectoryStarts, diskEntries, totalEntries, centralDirectorySize, offsetOfCentralDirectory,
            commentLength
        ) = try file.readIntegers(
            UInt32.self,
            UInt16.self,
            UInt16.self,
            UInt16.self,
            UInt16.self,
            UInt32.self,
            UInt32.self,
            UInt16.self
        )

        guard signature == Zip.endOfCentralDirectorySignature else { throw ZipArchiveReaderError.internalError }

        let comment = try file.readString(length: numericCast(commentLength))

        // Zip64
        var diskNumber32: UInt32 = numericCast(diskNumber)
        var diskEntries64: Int64 = numericCast(diskEntries)
        var totalEntries64: Int64 = numericCast(totalEntries)
        var centralDirectorySize64: Int64 = numericCast(centralDirectorySize)
        var offsetOfCentralDirectory64: Int64 = numericCast(offsetOfCentralDirectory)
        var diskNumberCentralDirectoryStarts32: UInt32 = numericCast(diskNumberCentralDirectoryStarts)
        if let zip64EndOfCentralLocator {
            if diskNumberCentralDirectoryStarts == 0xffff {
                diskNumberCentralDirectoryStarts32 = zip64EndOfCentralLocator.diskNumberCentralDirectoryStarts
            }
            // jump to zip64 central directory
            //let offset = zip64EndOfCentralLocator.relativeOffsetEndOfCentralDirectory
            try file.seek(numericCast(zip64EndOfCentralLocator.relativeOffsetEndOfCentralDirectory))
            let zip64EndOfCentralDirectory = try Self.readZip64EndOfCentralDirectory(file: file)
            if diskNumber == 0xffff {
                diskNumber32 = zip64EndOfCentralDirectory.diskNumber
            }
            if diskEntries == 0xffff {
                diskEntries64 = zip64EndOfCentralDirectory.diskEntries
            }
            if totalEntries == 0xffff {
                totalEntries64 = zip64EndOfCentralDirectory.totalEntries
            }
            if centralDirectorySize == 0xffff_ffff {
                centralDirectorySize64 = zip64EndOfCentralDirectory.centralDirectorySize
            }
            if offsetOfCentralDirectory == 0xffff_ffff {
                offsetOfCentralDirectory64 = zip64EndOfCentralDirectory.offsetOfCentralDirectory
            }
            // do stuff
        }
        return .init(
            diskNumber: diskNumber32,
            diskNumberCentralDirectoryStarts: diskNumberCentralDirectoryStarts32,
            diskEntries: diskEntries64,
            totalEntries: totalEntries64,
            centralDirectorySize: centralDirectorySize64,
            offsetOfCentralDirectory: offsetOfCentralDirectory64,
            comment: comment
        )
    }

    static func readZip64EndOfCentralLocator(file: some ZipReadableStorage) throws -> Zip.Zip64EndOfCentralLocator? {
        let (signature, diskNumberCentralDirectoryStarts, relativeOffsetEndOfCentralDirectory, totalNumberOfDisks) = try file.readIntegers(
            UInt32.self,
            UInt32.self,
            Int64.self,
            UInt32.self
        )
        guard signature == Zip.zip64EndOfCentralLocatorSignature else { return nil }
        return .init(
            diskNumberCentralDirectoryStarts: diskNumberCentralDirectoryStarts,
            relativeOffsetEndOfCentralDirectory: relativeOffsetEndOfCentralDirectory,
            totalNumberOfDisks: totalNumberOfDisks
        )
    }

    static func readZip64EndOfCentralDirectory(file: some ZipReadableStorage) throws -> Zip.Zip64EndOfCentralDirectory {
        let (
            signature, _, versionNeeded, diskNumber, diskNumberCentralDirectoryStarts, diskEntries, totalEntries, centralDirectorySize,
            offsetOfCentralDirectory
        ) =
            try file.readIntegers(
                UInt32.self,
                UInt16.self,
                UInt16.self,
                UInt32.self,
                UInt32.self,
                Int64.self,
                Int64.self,
                Int64.self,
                Int64.self
            )
        guard signature == Zip.zip64EndOfCentralDirectorySignature else { throw ZipArchiveReaderError.invalidDirectory }
        return .init(
            versionNeeded: versionNeeded,
            diskNumber: diskNumber,
            diskNumberCentralDirectoryStarts: diskNumberCentralDirectoryStarts,
            diskEntries: diskEntries,
            totalEntries: totalEntries,
            centralDirectorySize: centralDirectorySize,
            offsetOfCentralDirectory: offsetOfCentralDirectory
        )
    }

    static func searchForEndOfCentralDirectory(file: some ZipReadableStorage) throws -> Int {
        let fileChunkLength: Int64 = 1024
        let fileSize = try file.seekEnd(0)

        var filePosition = fileSize - 18

        while filePosition > 0, filePosition + 0xffff > fileSize {
            let readSize = min(filePosition, fileChunkLength)
            filePosition -= readSize
            try file.seek(filePosition)
            let bytes = try file.read(numericCast(readSize))
            for index in (bytes.startIndex..<bytes.index(bytes.endIndex, offsetBy: -3)).reversed() {
                if bytes[index] == 0x50, bytes[index + 1] == 0x4b, bytes[index + 2] == 0x5, bytes[index + 3] == 0x6 {
                    let offset = try file.seekOffset(numericCast(index - bytes.startIndex) - readSize)
                    return numericCast(offset)
                }
            }
        }

        throw ZipArchiveReaderError.failedToFindCentralDirectory
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

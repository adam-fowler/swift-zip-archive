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

extension ZipReadableStorage {
    /// Read directory from byffer
    func readDirectory(numEntries: Int) throws -> [Zip.FileHeader] {
        var directory: [Zip.FileHeader] = []
        for _ in 0..<numEntries {
            let fileHeader = try self.readFileHeader()
            directory.append(fileHeader)
        }
        return directory
    }

    func readLocalFileHeader() throws -> Zip.LocalFileHeader {
        let (
            signature, versionNeeded, flags, compression, modTime, modDate, crc32, compressedSize, uncompressedSize, fileNameLength, extraFieldsLength
        ) =
            try self.readIntegers(
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
        let filename = try self.readString(length: numericCast(fileNameLength))
        let extraFieldsBuffer = try self.readBytes(length: numericCast(extraFieldsLength))
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

    func readFileHeader() throws -> Zip.FileHeader {
        let (
            signature, versionMadeBy, versionNeeded, flags, compression, modTime, modDate, crc32, compressedSize, uncompressedSize, fileNameLength,
            extraFieldsLength, commentLength, diskStart, internalAttribute, externalAttribute, offsetOfLocalHeader
        ) =
            try self.readIntegers(
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

        let filename = try self.readString(length: numericCast(fileNameLength))
        let extraFieldsBuffer = try self.readBytes(length: numericCast(extraFieldsLength))
        let comment = try self.readString(length: numericCast(commentLength))

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
        while extraFieldsBuffer.index < extraFieldsBuffer.length {
            let (header, size) = try extraFieldsBuffer.readIntegers(UInt16.self, UInt16.self)
            let data = try extraFieldsBuffer.read(numericCast(size))
            extraFields.append(.init(header: .init(rawValue: header), data: data))
        }
        return extraFields
    }

    /// Read file from zip file
    ///
    /// - Parameters:
    ///   - file: File header, from zip directory
    ///   - password: Password used to decrypt file
    /// - Returns: Buffer containing file
    func readFile(_ file: Zip.FileHeader, password: String? = nil, compressionMethods: ZipCompressionMethodsMap) throws -> [UInt8] {
        let localFileHeader = try self.readLocalFileHeader()
        guard localFileHeader.filename == file.filename else { throw ZipArchiveReaderError.invalidFileHeader }
        guard let compressor = compressionMethods[localFileHeader.compressionMethod] else {
            throw ZipArchiveReaderError.unsupportedCompressionMethod
        }
        var encryptionKeys: [UInt8]?
        var fileSize = file.flags.contains(.dataDescriptor) ? file.compressedSize : localFileHeader.compressedSize
        // if encrypted read encryption header
        if localFileHeader.flags.contains(.encrypted) {
            encryptionKeys = try self.readBytes(length: 12)
            fileSize -= 12
        } else {
            encryptionKeys = nil
        }

        // Read bytes and uncompress
        var fileBytes = try self.readBytes(length: numericCast(fileSize))

        // if we have a password and encryption keys
        if let password, var encryptionKeys {
            var cryptKey = CryptKey(password: password)
            cryptKey.decryptBytes(&encryptionKeys)
            cryptKey.decryptBytes(&fileBytes)
        } else if encryptionKeys != nil {
            throw ZipArchiveReaderError.encryptedFilesRequirePassword
        }
        let uncompressedSize = file.flags.contains(.dataDescriptor) ? file.uncompressedSize : localFileHeader.uncompressedSize
        let uncompressedBytes = try compressor.inflate(from: fileBytes, uncompressedSize: numericCast(uncompressedSize))
        // Verify CRC32
        let crc = crc32(0, bytes: uncompressedBytes)
        guard crc == (file.flags.contains(.dataDescriptor) ? file.crc32 : localFileHeader.crc32) else {
            throw ZipArchiveReaderError.crc32FileValidationFailed
        }
        return uncompressedBytes
    }

    func readEndOfCentralDirectory() throws -> Zip.EndOfCentralDirectory {
        _ = try self.searchForEndOfCentralDirectory()

        let zip64EndOfCentralLocator: Zip.Zip64EndOfCentralLocator?
        // verify we have space to read the zip64 end of central directory locator, before reading it
        if try self.seekOffset(0) > 20 {
            try self.seekOffset(-20)
            zip64EndOfCentralLocator = try self.readZip64EndOfCentralLocator()
        } else {
            zip64EndOfCentralLocator = nil
        }

        let (
            signature, diskNumber, diskNumberCentralDirectoryStarts, diskEntries, totalEntries, centralDirectorySize, offsetOfCentralDirectory,
            commentLength
        ) = try self.readIntegers(
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

        let comment = try self.readString(length: numericCast(commentLength))

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
            try self.seek(numericCast(zip64EndOfCentralLocator.relativeOffsetEndOfCentralDirectory))
            let zip64EndOfCentralDirectory = try self.readZip64EndOfCentralDirectory()
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

    func readZip64EndOfCentralLocator() throws -> Zip.Zip64EndOfCentralLocator? {
        let (signature, diskNumberCentralDirectoryStarts, relativeOffsetEndOfCentralDirectory, totalNumberOfDisks) = try self.readIntegers(
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

    func readZip64EndOfCentralDirectory() throws -> Zip.Zip64EndOfCentralDirectory {
        let (
            signature, _, versionNeeded, diskNumber, diskNumberCentralDirectoryStarts, diskEntries, totalEntries, centralDirectorySize,
            offsetOfCentralDirectory
        ) =
            try self.readIntegers(
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

    func searchForEndOfCentralDirectory() throws -> Int {
        let fileChunkLength: Int64 = 1024
        let fileSize = try self.seekEnd(0)

        var filePosition = fileSize - 18

        while filePosition > 0, filePosition + 0xffff > fileSize {
            let readSize = min(filePosition, fileChunkLength)
            filePosition -= readSize
            try self.seek(filePosition)
            let bytes = try self.read(numericCast(readSize))
            for index in (bytes.startIndex..<bytes.index(bytes.endIndex, offsetBy: -3)).reversed() {
                if bytes[index] == 0x50, bytes[index + 1] == 0x4b, bytes[index + 2] == 0x5, bytes[index + 3] == 0x6 {
                    let offset = try self.seekOffset(numericCast(index - bytes.startIndex) - readSize)
                    return numericCast(offset)
                }
            }
        }

        throw ZipArchiveReaderError.failedToFindCentralDirectory
    }
}

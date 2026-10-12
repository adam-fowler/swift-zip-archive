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

extension ZipWriteableStorage {
    func writeFile(filePath: FilePath, contents: [UInt8], password: String? = nil, compression: any ZipCompression) throws -> Zip.FileHeader {
        // Calculate CRC32
        let crc = crc32(0, bytes: contents)
        let currentOffest = try self.currentPosition()

        var compressedContents =
            if compression.method == .noCompression {
                contents
            } else {
                try compression.deflate(from: contents)
            }

        var flags: Zip.FileFlags = []
        var cryptKey: CryptKey? = nil
        var fileSize = Int64(compressedContents.count)
        if let password {
            flags.insert(.encrypted)
            cryptKey = CryptKey(password: password)
            fileSize += 12
        }
        let fileHeader = Zip.FileHeader(
            versionMadeBy: Zip.versionMadeBy,
            versionNeeded: 20,
            flags: flags,
            compressionMethod: compression.method,
            fileModification: .now,
            crc32: crc,
            compressedSize: fileSize,
            uncompressedSize: numericCast(contents.count),
            filename: filePath,
            extraFields: [],
            comment: "",
            diskStart: 0,
            internalAttribute: 0,
            externalAttributes: [.unix([.isRegularFile, .permissions([.ownerReadWrite, .groupRead, .otherRead])])],
            offsetOfLocalHeader: currentOffest
        )
        try self.writeLocalFileHeader(fileHeader)

        if var cryptKey {
            // Add random 12 byte encryption header before file
            var encryptionKeys = (0..<12).map { _ in UInt8.random(in: 0...255) }
            encryptionKeys[11] = UInt8(crc >> 24)
            cryptKey.encryptBytes(&encryptionKeys)
            try write(bytes: encryptionKeys)

            // encrypt contents
            cryptKey.encryptBytes(&compressedContents)
        }

        try write(bytes: compressedContents)

        return fileHeader
    }

    func writeFolder(filePath: FilePath) throws -> Zip.FileHeader {
        let currentOffset = try self.currentPosition()

        let fileHeader = Zip.FileHeader(
            versionMadeBy: Zip.versionMadeBy,
            versionNeeded: 10,
            flags: [],
            compressionMethod: .noCompression,
            fileModification: .now,
            crc32: 0,
            compressedSize: 0,
            uncompressedSize: 0,
            filename: filePath,
            extraFields: [],
            comment: "",
            diskStart: 0,
            internalAttribute: 0,
            externalAttributes: [
                .unix([.isDirectory, .permissions([.ownerReadWriteExecute, .groupReadExecute, .otherReadExecute])]),
                .msdos(.isDirectory),
            ],  //0x4000_0000 | (0o755 << 16) | 0x10,  // directory | permissions 755 | MS-DOS directory flag
            offsetOfLocalHeader: currentOffset
        )
        try self.writeLocalFileHeader(fileHeader)
        return fileHeader
    }

    func writeFileHeader(_ fileHeader: Zip.FileHeader) throws {
        var fileHeader = fileHeader
        let extraFieldsBuffer = getExtraFieldBuffer(&fileHeader, localFileHeader: false)
        let (fileModificationTime, fileModificationDate) = fileHeader.fileModification.msdosDate()
        let filename = fileHeader.isDirectory ? "\(fileHeader.filename)/" : fileHeader.filename.string

        try self.writeIntegers(
            Zip.fileHeaderSignature,
            fileHeader.versionMadeBy.rawValue,
            fileHeader.versionNeeded,
            fileHeader.flags.rawValue,
            fileHeader.compressionMethod.rawValue,
            fileModificationTime,
            fileModificationDate,
            fileHeader.crc32,
            UInt32(fileHeader.compressedSize),
            UInt32(fileHeader.uncompressedSize),
            UInt16(filename.utf8.count),
            UInt16(extraFieldsBuffer.count),
            UInt16(fileHeader.comment.utf8.count),
            UInt16(fileHeader.diskStart),
            fileHeader.internalAttribute,
            fileHeader.externalAttributes.rawValue,
            UInt32(fileHeader.offsetOfLocalHeader)
        )
        try self.writeString(filename)
        try self.write(bytes: extraFieldsBuffer)
        try self.writeString(fileHeader.comment)
    }

    func writeLocalFileHeader(_ fileHeader: Zip.FileHeader) throws {
        var fileHeader = fileHeader
        let extraFields = getExtraFieldBuffer(&fileHeader, localFileHeader: true)
        let filename = fileHeader.isDirectory ? "\(fileHeader.filename)/" : fileHeader.filename.string

        let (fileModificationTime, fileModificationDate) = fileHeader.fileModification.msdosDate()
        try self.writeIntegers(
            Zip.localFileHeaderSignature,
            fileHeader.versionNeeded,
            fileHeader.flags.rawValue,
            fileHeader.compressionMethod.rawValue,
            fileModificationTime,
            fileModificationDate,
            fileHeader.crc32,
            UInt32(fileHeader.compressedSize),
            UInt32(fileHeader.uncompressedSize),
            UInt16(filename.utf8.count),
            UInt16(extraFields.count)
        )
        try self.writeString(filename)
        try self.write(bytes: extraFields)
    }

    func getExtraFieldBuffer(_ fileHeader: inout Zip.FileHeader, localFileHeader: Bool) -> ArraySlice<UInt8> {
        // Extended timestamp extra field
        let extendedTimestampExtraFieldSize = localFileHeader ? 4 + 9 : 4 + 5
        // Zip64 extra field
        let compressedSize32 = fileHeader.compressedSize > 0xffff_ffff ? 0xffff_ffff : numericCast(fileHeader.compressedSize)
        let uncompressedSize32 = fileHeader.uncompressedSize > 0xffff_ffff ? 0xffff_ffff : numericCast(fileHeader.uncompressedSize)
        let offsetOfLocalHeader32 = fileHeader.offsetOfLocalHeader > 0xffff_ffff ? 0xffff_ffff : numericCast(fileHeader.offsetOfLocalHeader)

        let includeZip64 = compressedSize32 == 0xffff_ffff || uncompressedSize32 == 0xffff_ffff || offsetOfLocalHeader32 == 0xffff_ffff

        var zip64ExtraFieldSize: Int
        if includeZip64 {
            zip64ExtraFieldSize = 4
            if compressedSize32 == 0xffff_ffff { zip64ExtraFieldSize += 8 }
            if uncompressedSize32 == 0xffff_ffff { zip64ExtraFieldSize += 8 }
            if offsetOfLocalHeader32 == 0xffff_ffff { zip64ExtraFieldSize += 8 }
        } else {
            zip64ExtraFieldSize = 0
        }
        // extra field size is timestamp + zip64 sizes + size of all the other extra fields
        let extraFieldsSize = fileHeader.extraFields.reduce(
            extendedTimestampExtraFieldSize + zip64ExtraFieldSize
        ) { $0 + $1.data.count + 4 }

        var memoryBuffer = MemoryBuffer(size: extraFieldsSize)
        // write extended timestamp
        memoryBuffer.writeIntegers(
            Zip.ExtraFieldHeader.extendedTimestamp.rawValue,
            UInt16(extendedTimestampExtraFieldSize - 4),
            UInt8(3),
            Int32(fileHeader.fileModification.timeIntervalSince1970)
        )
        // local file header also includes
        if localFileHeader {
            memoryBuffer.writeInteger(Int32(fileHeader.fileModification.timeIntervalSince1970))
        }
        // write zip64
        if includeZip64 {
            memoryBuffer.writeIntegers(Zip.ExtraFieldHeader.zip64.rawValue, UInt16(zip64ExtraFieldSize - 4))
            if uncompressedSize32 == 0xffff_ffff {
                memoryBuffer.writeInteger(fileHeader.uncompressedSize)
            }
            if compressedSize32 == 0xffff_ffff {
                memoryBuffer.writeInteger(fileHeader.compressedSize)
            }
            if offsetOfLocalHeader32 == 0xffff_ffff {
                memoryBuffer.writeInteger(fileHeader.offsetOfLocalHeader)
            }
        }
        for field in fileHeader.extraFields {
            memoryBuffer.writeIntegers(field.header.rawValue, UInt16(field.data.count))
            memoryBuffer.write(bytes: field.data)
        }
        return memoryBuffer.buffer
    }

    func writeZip64EndOfCentralDirectory(_ zip64EndOfCentralDirectory: Zip.Zip64EndOfCentralDirectory) throws {
        try self.writeIntegers(
            Zip.zip64EndOfCentralDirectorySignature,
            Zip.versionMadeBy.rawValue,
            zip64EndOfCentralDirectory.versionNeeded,  // version needed (zip64 requires v4.5)
            zip64EndOfCentralDirectory.diskNumber,
            zip64EndOfCentralDirectory.diskNumberCentralDirectoryStarts,
            zip64EndOfCentralDirectory.diskEntries,
            zip64EndOfCentralDirectory.totalEntries,
            zip64EndOfCentralDirectory.centralDirectorySize,
            zip64EndOfCentralDirectory.offsetOfCentralDirectory
        )
    }

    func writeZip64EndOfCentralLocator(_ zip64EndOfCentralLocator: Zip.Zip64EndOfCentralLocator) throws {
        try self.writeIntegers(
            Zip.zip64EndOfCentralLocatorSignature,
            zip64EndOfCentralLocator.diskNumberCentralDirectoryStarts,
            zip64EndOfCentralLocator.relativeOffsetEndOfCentralDirectory,
            zip64EndOfCentralLocator.totalNumberOfDisks
        )
    }

    func writeEndOfCentralDirectory(_ endOfCentralDirectory: Zip.EndOfCentralDirectory) throws {
        /// Check the size of values to see whether we need a zip64 block
        let diskNumber16: UInt16 = endOfCentralDirectory.diskNumber > 0xffff ? 0xffff : numericCast(endOfCentralDirectory.diskNumber)
        let diskNumberCentralDirectoryStarts16: UInt16 =
            endOfCentralDirectory.diskNumberCentralDirectoryStarts > 0xffff
            ? 0xffff : numericCast(endOfCentralDirectory.diskNumberCentralDirectoryStarts)
        let diskEntries16: UInt16 = endOfCentralDirectory.diskEntries > 0xffff ? 0xffff : numericCast(endOfCentralDirectory.diskEntries)
        let totalEntries16: UInt16 = endOfCentralDirectory.totalEntries > 0xffff ? 0xffff : numericCast(endOfCentralDirectory.totalEntries)
        let centralDirectorySize32: UInt32 =
            endOfCentralDirectory.centralDirectorySize > 0xffff_ffff ? 0xffff_ffff : numericCast(endOfCentralDirectory.centralDirectorySize)
        let offsetOfCentralDirectory32: UInt32 =
            endOfCentralDirectory.offsetOfCentralDirectory > 0xffff_ffff ? 0xffff_ffff : numericCast(endOfCentralDirectory.offsetOfCentralDirectory)

        // do we need Zip64 records
        if diskNumber16 == 0xffff || diskNumberCentralDirectoryStarts16 == 0xffff || diskEntries16 == 0xffff || totalEntries16 == 0xffff
            || centralDirectorySize32 == 0xffff_ffff || offsetOfCentralDirectory32 == 0xffff_ffff
        {
            let zip64EndOfCentralDirectory = Zip.Zip64EndOfCentralDirectory(
                versionNeeded: 45,  // Zip64 requires 4.5
                diskNumber: endOfCentralDirectory.diskNumber,
                diskNumberCentralDirectoryStarts: endOfCentralDirectory.diskNumberCentralDirectoryStarts,
                diskEntries: endOfCentralDirectory.diskEntries,
                totalEntries: endOfCentralDirectory.totalEntries,
                centralDirectorySize: endOfCentralDirectory.centralDirectorySize,
                offsetOfCentralDirectory: endOfCentralDirectory.offsetOfCentralDirectory
            )
            try writeZip64EndOfCentralDirectory(zip64EndOfCentralDirectory)

            let zip64EndOfCentralLocator = Zip.Zip64EndOfCentralLocator(
                diskNumberCentralDirectoryStarts: endOfCentralDirectory.diskNumberCentralDirectoryStarts,
                relativeOffsetEndOfCentralDirectory: endOfCentralDirectory.offsetOfCentralDirectory + endOfCentralDirectory.centralDirectorySize,
                totalNumberOfDisks: 1
            )
            try writeZip64EndOfCentralLocator(zip64EndOfCentralLocator)
        }

        try self.writeIntegers(
            Zip.endOfCentralDirectorySignature,
            diskNumber16,
            diskNumberCentralDirectoryStarts16,
            diskEntries16,
            totalEntries16,
            centralDirectorySize32,
            offsetOfCentralDirectory32,
            UInt16(endOfCentralDirectory.comment.utf8.count)
        )
        try self.writeString(endOfCentralDirectory.comment)
    }
}

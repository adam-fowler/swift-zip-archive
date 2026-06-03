//
// This source file is part of the swift-zip-archive project
// Copyright (c) 2025-2026 the swift-zip-archive project authors
//
// See LICENSE for license information
// SPDX-License-Identifier: Apache-2.0
//

public import SystemPackage

extension ZipArchiveReader {
    ///  Extract the contents of the zip file into a directory
    /// - Parameters:
    ///   - rootFolder: Root folder to extract into
    ///   - password: Password to use when decrypting files
    /// - Throws:
    public func extract(to rootFolder: FilePath, password: String? = nil) throws {
        let directory = try self.readDirectory()
        for entry in directory {
            let fullFilePath = rootFolder.appending(entry.filename.components)
            // Is either unix or msdos directory flag set
            if entry.isDirectory {
                let permissions = entry.externalAttributes.unixAttributes.filePermissions.union([.ownerRead, .ownerExecute])
                try DirectoryDescriptor.mkdir(fullFilePath, options: .ignoreExistingDirectoryError, permissions: permissions)
            } else {
                let permissions = entry.externalAttributes.unixAttributes.filePermissions.union([.ownerRead])
                let contents = try self.readFile(entry, password: password)
                let fileDescriptor = try FileDescriptor.open(
                    fullFilePath,
                    .writeOnly,
                    options: .create,
                    permissions: permissions
                )
                _ = try fileDescriptor.closeAfter {
                    try fileDescriptor.writeAll(contents)
                }
            }
        }
    }
}

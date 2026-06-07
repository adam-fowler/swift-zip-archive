//
// This source file is part of the swift-zip-archive project
// Copyright (c) 2025-2026 the swift-zip-archive project authors
//
// See LICENSE for license information
// SPDX-License-Identifier: Apache-2.0
//

public import SystemPackage

extension ZipArchiveWriter {
    /// Options when writing folder contents to zip
    public struct WriteFolderOptions: OptionSet {
        public let rawValue: Int
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        /// Should process recurs into sub folders
        public static var recursive: Self { .init(rawValue: 1 << 0) }
        /// When adding files to the zip should the filename in the zip directory include the last
        /// folder of the root file path.
        public static var includeContainingFolder: Self { .init(rawValue: 1 << 1) }
        /// Should we include hidden files
        public static var includeHiddenFiles: Self { .init(rawValue: 1 << 2) }
    }

    ///  Write the contents of a folder into a zip file
    /// - Parameters:
    ///   - folder: Folder name
    ///   - options:
    ///     - recursive: Should process recurs into sub folders
    ///     - includeContainingFolder: When adding files to the zip should the filename in the zip directory include the last
    ///         folder of the root file path.
    ///     - includeHiddenFiles: should we include hidden files
    ///   - filter: Closure that returns whether file should be included. Closure is called with FilePath and isDirectory boolean.
    public func writeFolderContents(_ folder: FilePath, options: WriteFolderOptions, filter: (FilePath, Bool) -> Bool = { _, _ in true }) throws {
        var rootFolder = folder
        if options.contains(.includeContainingFolder) {
            rootFolder.removeLastComponent()
        }
        func _writeFolderContents(_ folder: FilePath, options: WriteFolderOptions) throws {
            try DirectoryDescriptor.forFilesInDirectory(folder) { filePath, isDirectory in
                guard options.contains(.includeHiddenFiles) || filePath.lastComponent?.string.first != "." else {
                    return
                }
                guard filter(filePath, isDirectory) else { return }
                if isDirectory {
                    if options.contains(.recursive) {
                        try _writeFolderContents(filePath, options: options)
                    }
                } else {
                    var zipFilePath = filePath
                    _ = zipFilePath.removePrefix(rootFolder)
                    try self.writeFile(filePath: zipFilePath, sourceFilePath: filePath, password: nil)
                }
            }
        }
        try _writeFolderContents(folder, options: options)
    }
}

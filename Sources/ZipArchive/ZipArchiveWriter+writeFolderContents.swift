import SystemPackage

extension ZipArchiveWriter {
    public struct WriteFolderOptions: OptionSet {
        public let rawValue: Int
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        static var recursive: Self { .init(rawValue: 1 << 0) }
        static var includeContainingFolder: Self { .init(rawValue: 1 << 1) }
        static var includeHiddenFiles: Self { .init(rawValue: 1 << 2) }
    }

    ///  Write the contents of a folder into a zip file
    /// - Parameters:
    ///   - folder: Folder name
    ///   - recursive: Should process recurs into sub folders
    ///   - includeContainingFolder: When adding files to the zip should the filename in the zip directory include the last
    ///         folder of the root file path.
    public func writeFolderContents(_ folder: FilePath, options: WriteFolderOptions) throws {
        var rootFolder = folder
        if options.contains(.includeContainingFolder) {
            rootFolder.removeLastComponent()
        }
        func _writeFolderContents(_ folder: FilePath, options: WriteFolderOptions) throws {
            try DirectoryDescriptor.forFilesInDirectory(folder) { filePath, isDirectory in
                guard options.contains(.includeHiddenFiles) || filePath.lastComponent?.string.first != "." else {
                    return
                }
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

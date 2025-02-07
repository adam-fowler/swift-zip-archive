import SystemPackage

extension ZipArchiveWriter {
    ///  Write the contents of a folder into a zip file
    /// - Parameters:
    ///   - folder: Folder name
    ///   - recursive: Should process recurs into sub folders
    ///   - includeContainingFolder: When adding files to the zip should the filename in the zip directory include the last
    ///         folder of the root file path.
    public func writeFolderContents(_ folder: FilePath, recursive: Bool, includeContainingFolder: Bool) throws {
        var rootFolder = folder
        if includeContainingFolder {
            rootFolder.removeLastComponent()
        }
        func _writeFolderContents(_ folder: FilePath, recursive: Bool) throws {
            try DirectoryDescriptor.forFilesInDirectory(folder) { filePath, isDirectory in
                if isDirectory {
                    if recursive {
                        try _writeFolderContents(filePath, recursive: true)
                    }
                } else {
                    var zipFilePath = filePath
                    _ = zipFilePath.removePrefix(rootFolder)
                    try self.writeFile(filePath: zipFilePath, sourceFilePath: filePath, password: nil)
                }
            }
        }
        try _writeFolderContents(folder, recursive: recursive)
    }
}

import SystemPackage

#if !os(Windows)

extension ZipArchiveWriter {
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

#endif

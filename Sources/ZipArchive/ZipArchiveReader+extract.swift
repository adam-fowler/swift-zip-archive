import SystemPackage

#if !os(Windows)

extension ZipArchiveReader {
    func extract(to rootFolder: FilePath, password: String? = nil) throws {
        let directory = try self.readDirectory()
        for entry in directory {
            let fullFilePath = rootFolder.appending(entry.filename.components)
            // Is either unix or msdos directory flag set
            if entry.isDirectory {
                let permissions = entry.externalAttributes.unixAttributes.filePermissions.union([.ownerRead, .ownerExecute])
                do {
                    try FileDescriptor.mkdir(fullFilePath, permissions: permissions)
                } catch let error as Errno where error == .fileExists {
                    // if directory already exists ignore
                }
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

#endif

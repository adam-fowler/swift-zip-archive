import SystemPackage

#if os(Windows)
import Foundation
#endif

#if !os(Windows)

/// DirectoryDescriptor using C functions
struct DirectoryDescriptor {
    let rawValue: system_DIRPtr

    init(_ folder: FilePath) throws {
        guard
            let dir = folder.withPlatformString({ path in
                system_opendir(path)
            })
        else {
            throw Errno.current
        }
        self.rawValue = dir
    }

    func close() throws {
        try nothingOrErrno(retryOnInterrupt: true) {
            system_closedir(rawValue)
        }.get()
    }

    func closeAfter<R: Sendable>(
        body: () throws -> R
    ) throws -> R {
        // No underscore helper, since the closure's throw isn't necessarily typed.
        let result: R
        do {
            result = try body()
        } catch {
            _ = try? self.close()  // Squash close error and throw closure's
            throw error
        }
        try self.close()
        return result
    }

    /// Do shallow parse of files in a directory
    static func forFilesInDirectory(_ folder: FilePath, operation: (FilePath, Bool) throws -> Void) throws {
        let dirDescriptor = try DirectoryDescriptor(folder)
        try dirDescriptor.closeAfter {
            while let dirent = system_readdir(dirDescriptor.rawValue) {
                // Skip . and ..
                if dirent.pointee.d_name.0 == 46 && (dirent.pointee.d_name.1 == 0 || (dirent.pointee.d_name.1 == 46 && dirent.pointee.d_name.2 == 0))
                {
                    continue
                }
                let filename = withUnsafeBytes(of: dirent.pointee.d_name) { pointer -> FilePath in
                    let ptr = pointer.baseAddress!.assumingMemoryBound(to: CChar.self)
                    return FilePath(platformString: ptr)
                }
                try operation(folder.appending(filename.components), dirent.pointee.d_type == SYSTEM_DT_DIR)
            }
        }
    }

    /// Create a new directory
    static func mkdir(
        _ filePath: FilePath,
        options: MakeDirectoryOptions,
        permissions: FilePermissions
    ) throws {
        do {
            try filePath.withPlatformString { filename in
                try nothingOrErrno(retryOnInterrupt: true) { system_mkdir(filename, permissions.rawValue) }.get()
            }
        } catch let error as Errno where error == .fileExists {}
    }
}

#else

/// DirectoryDescriptor using FileManager (Required for Windows)
struct DirectoryDescriptor {
    /// Do shallow parse of files in a directory
    static func forFilesInDirectory(_ folder: FilePath, operation: (FilePath, Bool) throws -> Void) throws {
        let fileURL = URL(fileURLWithPath: folder.string, isDirectory: true)
        let urls = try FileManager.default.contentsOfDirectory(at: fileURL, includingPropertiesForKeys: [.isDirectoryKey])
        for url in urls {
            let path = folder.appending(url.lastPathComponent)
            try operation(path, url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true)
        }
    }

    /// Create a new directory
    static func mkdir(
        _ folder: FilePath,
        options: MakeDirectoryOptions,
        permissions: FilePermissions
    ) throws {
        do {
            try FileManager.default.createDirectory(
                atPath: folder.string,
                withIntermediateDirectories: false,
                attributes: [.posixPermissions: permissions.rawValue]
            )
        } catch let error as CocoaError where error.code == .fileWriteFileExists {
            guard options.contains(.ignoreExistingDirectoryError) else { throw error }
        }
    }
}

#endif

extension DirectoryDescriptor {
    struct MakeDirectoryOptions: OptionSet {
        let rawValue: Int

        static var ignoreExistingDirectoryError: Self { .init(rawValue: 1 << 0) }
    }

    /// Resursive parse of files in a directory
    static func recursiveForFilesInDirectory(_ folder: FilePath, operation: (FilePath) throws -> Void) throws {
        try Self.forFilesInDirectory(folder) { filePath, isDirectory in
            if isDirectory {
                try recursiveForFilesInDirectory(filePath, operation: operation)
            }
            try operation(filePath)
        }
    }

    /// Delete contents of directory and itself
    static func recursiveDelete(_ folder: FilePath) throws {
        try recursiveForFilesInDirectory(folder) { filePath in
            try FileDescriptor.remove(filePath)
        }
        try FileDescriptor.remove(folder)
    }
}

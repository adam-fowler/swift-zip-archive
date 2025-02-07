import Foundation
import SystemPackage
import Testing

@testable import ZipArchive

struct ZipArchiveReaderTests {
    @Test func testMSDOSDateAndBack() async throws {
        let msdosDate = 3 | (6 << 5) | (24 << 9)
        let msdosTime = 21 | (45 << 5) | (19 << 11)
        let date = Date(msdosTime: UInt16(msdosTime), msdosDate: UInt16(msdosDate))
        let (msdosTime2, msdosDate2) = date.msdosDate()
        #expect(msdosTime == msdosTime2)
        #expect(msdosDate == msdosDate2)
    }
    @Test
    func loadZipDirectoryFromMemory() throws {
        let filePath = Bundle.module.fixedUpPath(forResource: "source", ofType: "zip")!
        let fileHandle = FileHandle(forReadingAtPath: filePath)
        let data = try #require(try fileHandle?.readToEnd())
        let zipArchiveReader = try ZipArchiveReader(buffer: data)
        let zipArchiveDirectory = try zipArchiveReader.readDirectory()
        #expect(zipArchiveDirectory.count == 9)
        #expect(zipArchiveDirectory[0].filename == "Sources/Zip/")
        #expect(zipArchiveDirectory[8].filename == "Tests/ZipTests/ZipFileReaderTests.swift")
    }

    @Test
    func loadZipArchiveFromMemory() throws {
        let filePath = Bundle.module.fixedUpPath(forResource: "source", ofType: "zip")!
        let fileHandle = FileHandle(forReadingAtPath: filePath)
        let data = try #require(try fileHandle?.readToEnd())
        let ZipArchiveReader = try ZipArchiveReader(buffer: data)
        let zipArchiveDirectory = try ZipArchiveReader.readDirectory()
        _ = try ZipArchiveReader.readFile(zipArchiveDirectory[2])
    }

    @Test
    func loadZipDirectory() throws {
        let filePath = Bundle.module.fixedUpPath(forResource: "source", ofType: "zip")!
        try ZipArchiveReader.withFile(filePath) { zipArchiveReader in
            let zipArchiveDirectory = try zipArchiveReader.readDirectory()
            #expect(zipArchiveDirectory.count == 9)
            #expect(zipArchiveDirectory[0].filename == "Sources/Zip/")
            #expect(zipArchiveDirectory[8].filename == "Tests/ZipTests/ZipFileReaderTests.swift")
        }
    }

    @Test
    func parseZipDirectory() throws {
        let filePath = Bundle.module.fixedUpPath(forResource: "source", ofType: "zip")!
        try ZipArchiveReader.withFile(filePath) { zipArchiveReader in
            var fileHeader: Zip.FileHeader?
            try zipArchiveReader.parseDirectory { file in
                if file.filename == "Tests/ZipTests/ZipFileReaderTests.swift" {
                    fileHeader = file
                }
            }
            #expect(fileHeader != nil)
        }
    }

    @Test
    func loadZipArchive() throws {
        let filePath = Bundle.module.fixedUpPath(forResource: "source", ofType: "zip")!
        try ZipArchiveReader.withFile(filePath) { zipArchiveReader in
            let zipArchiveDirectory = try zipArchiveReader.readDirectory()
            let packageSwiftRecord = try #require(zipArchiveDirectory.first { $0.filename == "Sources/Zip/MemoryFileStorage.swift" })
            let file = try zipArchiveReader.readFile(packageSwiftRecord)
            #expect(String(decoding: file[...26], as: UTF8.self) == "public final class ZipFileM")
        }
    }

    @Test
    func loadEmptyZipArchive() throws {
        let writer = ZipArchiveWriter()
        let buffer = try writer.finalizeBuffer()
        let reader = try ZipArchiveReader(buffer: buffer)
        let directory = try reader.readDirectory()
        #expect(directory.count == 0)
    }

    @Test
    func loadLinuxZipArchive() throws {
        let filePath = Bundle.module.fixedUpPath(forResource: "linux", ofType: "zip")!
        try ZipArchiveReader.withFile(filePath) { zipArchiveReader in
            let zipArchiveDirectory = try zipArchiveReader.readDirectory()
            let folder = try #require(zipArchiveDirectory.first)
            #expect(folder.isDirectory)
            #expect(folder.filename == "Sources")
            let packageSwiftRecord = try #require(zipArchiveDirectory.first { $0.filename == "Sources/ZipArchive/ZipMemoryStorage.swift" })
            let file = try zipArchiveReader.readFile(packageSwiftRecord)
            #expect(String(decoding: file[...29], as: UTF8.self) == "/// Storage in a memory buffer")
        }
    }

    @Test
    func loadEncryptedZipArchive() throws {
        let filePath = Bundle.module.fixedUpPath(forResource: "encrypted", ofType: "zip")!
        try ZipArchiveReader.withFile(filePath) { zipArchiveReader in
            let zipArchiveDirectory = try zipArchiveReader.readDirectory()
            let packageSwiftRecord = try #require(zipArchiveDirectory.first { $0.filename == "Sources/ZipArchive/ZipArchiveReader.swift" })
            let file = try zipArchiveReader.readFile(packageSwiftRecord, password: "testing123")
            #expect(String(decoding: file[...14], as: UTF8.self) == "import CZipZlib")
        }
    }

    @Test
    func loadZipArchiveWithUTF8EncodedFilenames() throws {
        let filePath = Bundle.module.fixedUpPath(forResource: "encoding", ofType: "zip")!
        try ZipArchiveReader.withFile(filePath) { zipArchiveReader in
            let zipArchiveDirectory = try zipArchiveReader.readDirectory()
            // zip files created on mac don't set encoding flag for utf8 encoded filenames

            _ = try #require(zipArchiveDirectory.first { $0.filename == "encoding/tést.txt" })
            _ = try #require(zipArchiveDirectory.first { $0.filename == "encoding/smiley😀.txt" })
        }
    }

    @Test
    func loadZip64File() throws {
        let filePath = Bundle.module.fixedUpPath(forResource: "hello64", ofType: "zip")!
        try ZipArchiveReader.withFile(filePath) { zipArchiveReader in
            let ZipArchiveDirectory = try zipArchiveReader.readDirectory()
            let file = try zipArchiveReader.readFile(ZipArchiveDirectory[0])
            #expect(ZipArchiveDirectory[0].filename == "-")
            #expect(String(decoding: file, as: UTF8.self) == "Hello, world!\n")
        }
    }

    @Test
    func extractToFolder() throws {
        let writer = ZipArchiveWriter()
        try writer.writeFile(filename: "Hello/Hello.txt", contents: .init("Hello,".utf8))
        try writer.writeFile(filename: "World/World.txt", contents: .init("world!".utf8))
        let buffer = try writer.finalizeBuffer()
        let reader = try ZipArchiveReader(buffer: buffer)
        try DirectoryDescriptor.mkdir("Temp", options: .ignoreExistingDirectoryError, permissions: [.ownerReadWriteExecute])
        defer {
            try? DirectoryDescriptor.recursiveDelete("Temp")
        }
        try reader.extract(to: "Temp")
        var files: [FilePath] = []
        try DirectoryDescriptor.recursiveForFilesInDirectory("Temp") { filePath in
            files.append(filePath)
        }
        #expect(Set(files) == Set(["Temp/Hello/Hello.txt", "Temp/Hello", "Temp/World/World.txt", "Temp/World"]))
    }
}

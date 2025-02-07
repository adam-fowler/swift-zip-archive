import SystemPackage
import Testing

@testable import ZipArchive

struct ZipArchiveWriterTests {
    @Test
    func testCreateEmptyZipArchive() throws {
        let writer = ZipArchiveWriter()
        let buffer = try writer.finalizeBuffer()
        #expect(buffer == [UInt8]([80, 75, 5, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])[...])
    }

    @Test
    func testAddingFileToEmptyZipArchive() throws {
        let writer = ZipArchiveWriter()
        try writer.writeFile(filename: "Hello.txt", contents: .init("Hello, world!".utf8))
        let buffer = try writer.finalizeBuffer()
        let zipArchiveReader = try ZipArchiveReader(buffer: buffer)
        let directory = try zipArchiveReader.readDirectory()
        #expect(directory.count == 1)
        #expect(directory.first?.filename == "Hello.txt")
        let fileHeader = try #require(directory.first)
        let fileContents = try zipArchiveReader.readFile(fileHeader)
        #expect(fileContents == .init("Hello, world!".utf8))
    }

    @Test
    func testAddingFileToNonEmptyZipArchive() throws {
        // write original zip archive
        let writer = ZipArchiveWriter()
        try writer.writeFile(filename: "Hello.txt", contents: .init("Hello, world!".utf8))
        let buffer = try writer.finalizeBuffer()
        let writer2 = try ZipArchiveWriter(bytes: buffer)
        try writer2.writeFile(filename: "Goodbye.txt", contents: .init("Goodbye, world!".utf8))
        let buffer2 = try writer2.finalizeBuffer()

        let zipArchiveReader = try ZipArchiveReader(buffer: buffer2)
        let directory = try zipArchiveReader.readDirectory()
        #expect(directory.count == 2)
        #expect(directory.first?.filename == "Hello.txt")
        let fileHeader = try #require(directory.first)
        let fileContents = try zipArchiveReader.readFile(fileHeader)
        #expect(fileContents == .init("Hello, world!".utf8))
        #expect(directory.last?.filename == "Goodbye.txt")
        let fileHeader2 = try #require(directory.last)
        let fileContents2 = try zipArchiveReader.readFile(fileHeader2)
        #expect(fileContents2 == .init("Goodbye, world!".utf8))
    }

    @Test
    func testAddingFilesWithDirectory() throws {
        let writer = ZipArchiveWriter()
        try writer.writeFile(filename: "Tests/Hello.txt", contents: .init("Hello, world!".utf8))
        let buffer = try writer.finalizeBuffer()
        let writer2 = try ZipArchiveWriter(bytes: buffer)

        #expect(writer2.directory.count == 2)
        let firstFilename = try #require(writer2.directory.first?.filename)
        #expect(firstFilename == "Tests/")
        try writer2.writeFile(filename: "Tests/Two/Hello2.txt", contents: .init("Hello, world!".utf8))
        try writer2.writeFile(filename: "Tests/Two/Hello3.txt", contents: .init("Hello, world!".utf8))
        let buffer2 = try writer2.finalizeBuffer()
        let zipArchiveReader = try ZipArchiveReader(buffer: buffer2)
        let directory = try zipArchiveReader.readDirectory()
        #expect(directory.count == 5)
        #expect(directory.map { $0.filename } == ["Tests/", "Tests/Hello.txt", "Tests/Two/", "Tests/Two/Hello2.txt", "Tests/Two/Hello3.txt"])
    }

    @Test
    func testAddingDuplicateFilesErrors() throws {
        let writer = ZipArchiveWriter()
        try writer.writeFile(filename: "Tests/Hello.txt", contents: .init("Hello, world!".utf8))
        let buffer = try writer.finalizeBuffer()
        let writer2 = try ZipArchiveWriter(bytes: buffer)

        #expect(throws: ZipArchiveWriterError.fileAlreadyExists) {
            try writer2.writeFile(filename: "Tests", contents: .init("Hello, world!".utf8))
        }
        #expect(throws: ZipArchiveWriterError.fileAlreadyExists) {
            try writer2.writeFile(filename: "Tests/Hello.txt", contents: .init("Hello, world!".utf8))
        }
        try writer2.writeFile(filename: "Tests2/Hello.txt", contents: .init("Hello, world!".utf8))
        #expect(throws: ZipArchiveWriterError.fileAlreadyExists) {
            try writer2.writeFile(filename: "Tests2", contents: .init("Hello, world!".utf8))
        }
        #expect(throws: ZipArchiveWriterError.fileAlreadyExists) {
            try writer2.writeFile(filename: "Tests2/Hello.txt", contents: .init("Hello, world!".utf8))
        }
    }

    @Test
    func testAddingDuplicateFolderErrors() throws {
        let writer = ZipArchiveWriter()
        try writer.writeFile(filename: "Hello.txt", contents: .init("Hello, world!".utf8))
        let buffer = try writer.finalizeBuffer()
        let writer2 = try ZipArchiveWriter(bytes: buffer)

        #expect(throws: ZipArchiveWriterError.fileAlreadyExists) {
            try writer2.writeFile(filename: "Hello.txt/Hello.txt", contents: .init("Hello, world!".utf8))
        }
        try writer2.writeFile(filename: "Hello2.txt", contents: .init("Hello, world!".utf8))
        #expect(throws: ZipArchiveWriterError.fileAlreadyExists) {
            try writer2.writeFile(filename: "Hello2.txt/Hello.txt", contents: .init("Hello, world!".utf8))
        }
    }

    @Test
    func testAddingEncryptedFileToZipArchive() throws {
        let writer = ZipArchiveWriter()
        try writer.writeFile(filename: "Hello.txt", contents: .init("Hello, world!".utf8), password: "testAddingEncryptedFileToZipArchive")
        let buffer = try writer.finalizeBuffer()
        let zipArchiveReader = try ZipArchiveReader(buffer: buffer)
        let directory = try zipArchiveReader.readDirectory()
        #expect(directory.count == 1)
        #expect(directory.first?.filename == "Hello.txt")
        let fileHeader = try #require(directory.first)
        let fileContents = try zipArchiveReader.readFile(fileHeader, password: "testAddingEncryptedFileToZipArchive")
        #expect(fileContents == .init("Hello, world!".utf8))
    }

    @Test
    func testAddingFileToEmptyFileZipArchive() throws {
        let filename = "testAddingFileToEmptyFileZipArchive.zip"
        defer {
            try? FileDescriptor.remove(.init(filename))
        }
        try ZipArchiveWriter.withFile(filename, options: .create) { writer in
            try writer.writeFile(filename: "Hello.txt", contents: .init("Hello, world!".utf8))
        }
        try ZipArchiveReader.withFile(filename) { reader in
            let directory = try reader.readDirectory()
            #expect(directory.count == 1)
            #expect(directory.first?.filename == "Hello.txt")
            let fileHeader = try #require(directory.first)
            let fileContents = try reader.readFile(fileHeader)
            #expect(fileContents == .init("Hello, world!".utf8))
        }
    }

    @Test
    func testAddingFileToNonEmptyFileZipArchive() throws {
        let filename = "testAddingFileToNonEmptyFileZipArchive.zip"
        defer {
            try? FileDescriptor.remove(.init(filename))
        }
        try ZipArchiveWriter.withFile(filename, options: .create) { writer in
            try writer.writeFile(filename: "Hello.txt", contents: .init("Hello, world!".utf8))
        }
        try ZipArchiveWriter.withFile(filename) { writer in
            try writer.writeFile(filename: "Goodbye.txt", contents: .init("Goodbye, world!".utf8))
        }
        try ZipArchiveReader.withFile(filename) { reader in
            let directory = try reader.readDirectory()
            #expect(directory.count == 2)
            #expect(directory.first?.filename == "Hello.txt")
            let fileHeader = try #require(directory.first)
            let fileContents = try reader.readFile(fileHeader)
            #expect(fileContents == .init("Hello, world!".utf8))
            #expect(directory.last?.filename == "Goodbye.txt")
            let fileHeader2 = try #require(directory.last)
            let fileContents2 = try reader.readFile(fileHeader2)
            #expect(fileContents2 == .init("Goodbye, world!".utf8))
        }
    }

    @Test
    func testWritingFolderContents() throws {
        let writer = ZipArchiveWriter()
        // write contents of sources folder into zip
        try writer.writeFolderContents("./Sources", options: [.recursive, .includeContainingFolder])
        try writer.writeFolderContents("./Tests", options: .recursive)
        let buffer = try writer.finalizeBuffer()

        let reader = try ZipArchiveReader(buffer: buffer)
        let directory = try reader.readDirectory()
        #expect(directory.first { $0.filename == "Sources/ZipArchive/ZipStorage.swift" } != nil)
        #expect(directory.first { $0.filename == "ZipArchiveTests/EncryptionTests.swift" } != nil)
    }

    @Test
    func testNoCompression() throws {
        let writer = ZipArchiveWriter(configuration: .init(compression: .noCompression))
        try writer.writeFile(filename: "Hello.txt", contents: .init("Hello, world!".utf8))
        let buffer = try writer.finalizeBuffer()
        let zipArchiveReader = try ZipArchiveReader(buffer: buffer)
        let directory = try zipArchiveReader.readDirectory()
        #expect(directory.count == 1)
        let fileHeader = try #require(directory.first)
        #expect(fileHeader.filename == "Hello.txt")
        #expect(fileHeader.compressionMethod == .noCompression)
        let file = try zipArchiveReader.readFile(fileHeader)
        #expect(String(decoding: file, as: UTF8.self) == "Hello, world!")
    }

    @Test
    func testCustomCompression() throws {
        struct XorCompressor: ZipCompression {
            var method = Zip.FileCompressionMethod.reserved1
            func inflate(from: [UInt8], uncompressedSize: Int) throws -> [UInt8] {
                .init(unsafeUninitializedCapacity: max(uncompressedSize, from.count)) { buffer, initializedCount in
                    for index in 0..<uncompressedSize {
                        buffer[index] = from[index] ^ 0xff
                    }
                    initializedCount = uncompressedSize
                }
            }

            func deflate(from: [UInt8]) throws -> [UInt8] {
                .init(unsafeUninitializedCapacity: from.count) { buffer, initializedCount in
                    for index in 0..<from.count {
                        buffer[index] = from[index] ^ 0xff
                    }
                    initializedCount = from.count
                }
            }

        }
        let writer = ZipArchiveWriter(configuration: .init(compression: XorCompressor()))
        try writer.writeFile(filename: "Hello.txt", contents: .init("Hello, world!".utf8))
        let buffer = try writer.finalizeBuffer()
        let zipArchiveReader = try ZipArchiveReader(buffer: buffer, configuration: .init(compressionMethods: [XorCompressor()]))
        let directory = try zipArchiveReader.readDirectory()
        #expect(directory.count == 1)
        let fileHeader = try #require(directory.first)
        #expect(fileHeader.filename == "Hello.txt")
        #expect(fileHeader.compressionMethod == .reserved1)
        let file = try zipArchiveReader.readFile(fileHeader)
        #expect(String(decoding: file, as: UTF8.self) == "Hello, world!")
    }
}

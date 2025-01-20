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
        try writer.addFile(filename: "Hello.txt", contents: .init("Hello, world!".utf8))
        let buffer = try writer.finalizeBuffer()
        let zipArchiveReader = try ZipArchiveReader(bytes: buffer)
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
        try writer.addFile(filename: "Hello.txt", contents: .init("Hello, world!".utf8))
        let buffer = try writer.finalizeBuffer()
        let writer2 = try ZipArchiveWriter(bytes: buffer)
        try writer2.addFile(filename: "Goodbye.txt", contents: .init("Goodbye, world!".utf8))
        let buffer2 = try writer2.finalizeBuffer()

        let zipArchiveReader = try ZipArchiveReader(bytes: buffer2)
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
    func testAddingFileToEmptyFileZipArchive() throws {
        try ZipArchiveWriter.withFile("test.zip", options: .create) { writer in
            try writer.addFile(filename: "Hello.txt", contents: .init("Hello, world!".utf8))
        }
        try ZipArchiveReader.withFile("test.zip") { reader in
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
        try ZipArchiveWriter.withFile("test2.zip", options: .create) { writer in
            try writer.addFile(filename: "Hello.txt", contents: .init("Hello, world!".utf8))
        }
        try ZipArchiveWriter.withFile("test2.zip") { writer in
            try writer.addFile(filename: "Goodbye.txt", contents: .init("Goodbye, world!".utf8))
        }
        try ZipArchiveReader.withFile("test2.zip") { reader in
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
}

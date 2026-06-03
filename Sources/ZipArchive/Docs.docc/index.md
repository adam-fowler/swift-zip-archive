# ``ZipArchive``

A library for reading and editing zip archives.

Zip archives are a standard method for collating, compressing and encrypting collections of files. They are universally used to aggregate, compress, and encrypt files into a single interoperable container. `ZipArchive` provides support for reading and writing zip archives from either memory or disk.

## Reading Zip archives

To parse a zip archive stored on disk use the function ``ZipArchiveReader.withFile(_:process:)``. This creates a ``ZipArchiveReader`` that can be used in the supplied closure to read the directory from a zip file and then read individual files.

```swift
let fileContents = try ZipArchiveReader.withFile("MyFile.zip") { reader in
    let directory = try reader.readDirectory()
    let fileHeader = directory.first { $0.filename == "File.txt"}
    return try reader.readFile(fileHeader)
}
```

## Writing Zip Archives

The ``ZipArchiveWriter`` is used to write zip archives. You can use ``ZipArchiveWriter.withFile(_:options:configuration:process:)`` to either create a new zip archive or append files to an existing zip archive. This function has a closure parameter in which you can add new files to the zip using the provided `ZipArchiveWriter`. When you exit the closure the zip archive is finalized ie the directory and end of directory sections are written to disk and file descriptor is closed. The following loads zip archive MyFile.zip and then appends a new file called Hello.txt to the archive.

```swift
try ZipArchiveWriter.withFile("MyFile.zip") { writer in
    try writer.writeFile(filename: "Hello.txt", contents: .init("Hello, world!".utf8))
}
```

If you want to create a new zip archive you can call `withFile("MyFile.zip", options: .create)`.

## Password Protected Zip Archives

`ZipArchive` supports the traditional PKZIP encrytion method. You can decrypt a file by adding a password parameter to ``ZipArchiveReader.readFile(_:password:)``. For example

```swift
try reader.readFile(fileHeader, password: "testing123")
```

And you can add encryption to a file by adding a password to ``ZipArchiveWriter.writeFile(filename:contents:password:)``. For example

```swift
try writer.writeFile(filename: "Hello.txt", contents: fileContents, password: "testing123")
```

## Zip Archive Memory Buffers

It is also possible to use `ZipArchiveReader` and `ZipArchiveWriter` to read and write from a zip archive stored in memory. A `ZipArchiveReader` can be constructed from a memory buffer and then its directory and files can be read in a similar manner to how they with archives stored on disk.

```swift
let reader = try ZipFileReader(buffer: zipArchiveMemoryBuffer)
let directory = try reader.readDirectory()
let fileHeader = directory.first { $0.filename == "File.txt"}
let fileContents = try reader.readFile(fileHeader)
```

To write to a zip archive in memory you can create a `ZipFileWriter` from a buffer. When you want to create your finalized zip archive with a complete directory you call ``ZipFileWriter.finalizeBuffer()`` which will return the complete zip archive.

```swift
let writer = try ZipArchiveWriter(buffer: zipArchiveMemoryBuffer)
try writer.writeFile(filename: "Hello.txt", contents: fileContents, password: "testing123")
let zipBuffer = try writer.finalizeBuffer()
```
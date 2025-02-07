import CZipZlib

/// protocol for zip compression method
public protocol ZipCompression {
    /// Compression method stored in file header
    var method: Zip.FileCompressionMethod { get }
    func inflate(from: [UInt8], uncompressedSize: Int) throws -> [UInt8]
    func deflate(from: [UInt8]) throws -> [UInt8]
}

extension ZipCompression where Self == NoZipCompression {
    /// No compression
    static var noCompression: Self { .init() }
}

extension ZipCompression where Self == ZlibDeflateCompression {
    /// Zlib deflate compression
    static var deflate: Self { .init() }
}

typealias ZipCompressionMethodsMap = [Zip.FileCompressionMethod: any ZipCompression]

public struct NoZipCompression: ZipCompression {
    public var method: Zip.FileCompressionMethod { .noCompression }

    public func inflate(from: [UInt8], uncompressedSize: Int) throws -> [UInt8] {
        from
    }
    public func deflate(from: [UInt8]) throws -> [UInt8] {
        from
    }
}

/// Zip zlib deflate compression method
public class ZlibDeflateCompression: ZipCompression {
    public var method: Zip.FileCompressionMethod { .deflate }

    let windowBits: Int32 = 15

    public init() {}

    public func inflate(from: [UInt8], uncompressedSize: Int) throws -> [UInt8] {
        var stream = z_stream()
        stream.zalloc = nil
        stream.zfree = nil
        stream.opaque = nil
        let rt = CZipZlib_inflateInit2(&stream, -windowBits)
        guard rt == Z_OK else { throw ZipArchiveReaderError.compressionError }

        var from = from
        return try .init(unsafeUninitializedCapacity: uncompressedSize) { toBuffer, count in
            try from.withUnsafeMutableBytes { fromBuffer in
                stream.avail_in = UInt32(fromBuffer.count)
                stream.next_in = CZipZlib_voidPtr_to_BytefPtr(fromBuffer.baseAddress!)
                stream.avail_out = UInt32(toBuffer.count)
                stream.next_out = CZipZlib_voidPtr_to_BytefPtr(toBuffer.baseAddress!)

                let rt = CZipZlib.inflate(&stream, Z_FINISH)
                switch rt {
                case Z_OK:
                    break
                case Z_BUF_ERROR:
                    throw ZipArchiveReaderError.compressionError
                case Z_DATA_ERROR:
                    throw ZipArchiveReaderError.compressionError
                case Z_MEM_ERROR:
                    throw ZipArchiveReaderError.compressionError
                case Z_STREAM_END:
                    break
                default:
                    throw ZipArchiveReaderError.compressionError
                }
            }
            count = uncompressedSize
        }
    }

    public func deflate(from: [UInt8]) throws -> [UInt8] {
        var stream = z_stream()
        stream.zalloc = nil
        stream.zfree = nil
        stream.opaque = nil
        let rt = CZipZlib_deflateInit2(&stream, 9, Z_DEFLATED, -windowBits, 9, Z_DEFAULT_STRATEGY)
        guard rt == Z_OK else { throw ZipArchiveReaderError.compressionError }

        var from = from
        // deflateBound() provides an upper limit on the number of bytes the input can
        // compress to. We add 5 bytes to handle the fact that Z_SYNC_FLUSH will append
        // an empty stored block that is 5 bytes long.
        // From zlib docs (https://www.zlib.net/manual.html)
        // "If the parameter flush is set to Z_SYNC_FLUSH, all pending output is flushed to the output buffer and the output is
        // aligned on a byte boundary, so that the decompressor can get all input data available so far. (In particular avail_in
        // is zero after the call if enough output space has been provided before the call.) Flushing may degrade compression for
        // some compression algorithms and so it should be used only when necessary. This completes the current deflate block and
        // follows it with an empty stored block that is three bits plus filler bits to the next byte, followed by four bytes
        // (00 00 ff ff)."
        #if os(Windows)
        let largestCompressedSize = deflateBound(&stream, UInt32(from.count)) + 6
        #else
        let largestCompressedSize = deflateBound(&stream, UInt(from.count)) + 6
        #endif

        return try .init(unsafeUninitializedCapacity: Int(largestCompressedSize)) { toBuffer, count in
            try from.withUnsafeMutableBytes { fromBuffer in
                stream.avail_in = UInt32(fromBuffer.count)
                stream.next_in = CZipZlib_voidPtr_to_BytefPtr(fromBuffer.baseAddress!)
                stream.avail_out = UInt32(toBuffer.count)
                stream.next_out = CZipZlib_voidPtr_to_BytefPtr(toBuffer.baseAddress!)

                let rt = CZipZlib.deflate(&stream, Z_FINISH)
                switch rt {
                case Z_OK:
                    throw ZipArchiveReaderError.compressionError
                case Z_BUF_ERROR:
                    throw ZipArchiveReaderError.compressionError
                case Z_DATA_ERROR:
                    throw ZipArchiveReaderError.compressionError
                case Z_MEM_ERROR:
                    throw ZipArchiveReaderError.compressionError
                case Z_STREAM_END:
                    break
                default:
                    throw ZipArchiveReaderError.compressionError
                }
                count = stream.next_out - CZipZlib_voidPtr_to_BytefPtr(toBuffer.baseAddress)
            }
        }
    }
}

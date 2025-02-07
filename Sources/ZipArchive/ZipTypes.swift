import SystemPackage

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Zip file types
/// Details on these can be found in the PKZIP AppNotes https://support.pkware.com/pkzip/application-note-archives
public enum Zip {
    static let versionMadeBy = VersionMadeBy(system: .unix, version: 0x1e)

    /// zip file header options
    public struct FileFlags: OptionSet {
        public let rawValue: UInt16

        public init(rawValue: UInt16) {
            self.rawValue = rawValue
        }

        public static var encrypted: Self { .init(rawValue: 1 << 0) }
        public static var compressionOption1: Self { .init(rawValue: 1 << 1) }
        public static var compressionOption2: Self { .init(rawValue: 1 << 2) }
        public static var dataDescriptor: Self { .init(rawValue: 1 << 3) }
        public static var enhancedDeflation: Self { .init(rawValue: 1 << 4) }
        public static var compressedPatchedData: Self { .init(rawValue: 1 << 5) }
        public static var strongEncryption: Self { .init(rawValue: 1 << 6) }
        public static var languageEncoding: Self { .init(rawValue: 1 << 11) }
        static var reserved1: Self { .init(rawValue: 1 << 12) }
        public static var maskHeaderValues: Self { .init(rawValue: 1 << 13) }
        static var reserved2: Self { .init(rawValue: 1 << 14) }
        static var reserved3: Self { .init(rawValue: 1 << 15) }

    }
    /// zip file compression method
    public enum FileCompressionMethod: UInt16, Hashable {
        case noCompression = 0
        case shrunk = 1
        case compressionFactor1 = 2
        case compressionFactor2 = 3
        case compressionFactor3 = 4
        case compressionFactor4 = 5
        case imploded = 6
        case reserved1 = 7
        case deflate = 8
        case enhancedDeflated = 9
        case pkWareDCLImploded = 10
        case reserved2 = 11
        case bZip2 = 12
        case reserved3 = 13
        case lzma = 14
        case reserved4 = 15
        case reserved5 = 16
        case reserved6 = 17
        case ibmTerse = 18
        case ibmLZ77 = 19
        case ppmd = 98
    }

    /// zip file header external attributes for unix files
    public struct UnixAttributes: OptionSet {
        public let rawValue: UInt16

        public init(rawValue: UInt16) {
            self.rawValue = rawValue
        }

        public static func permissions(_ permissions: FilePermissions) -> Self { .init(rawValue: numericCast(permissions.rawValue)) }
        public static var isDirectory: Self { .init(rawValue: 0o40000) }
        public static var isRegularFile: Self { .init(rawValue: 0o100000) }

        public var filePermissions: FilePermissions { .init(rawValue: numericCast(rawValue) & 0o7777) }
    }

    /// zip file header external attributes for msdos files
    public struct MSDOSAttributes: OptionSet {
        public let rawValue: UInt32

        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }

        public static func permissions(_ permissions: FilePermissions) -> Self { .init(rawValue: numericCast(permissions.rawValue)) }
        public static var isDirectory: Self { .init(rawValue: 0x10) }
    }

    /// zip file header external attributes
    public struct ExternalAttributes: OptionSet {
        public let rawValue: UInt32

        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }

        public static func msdos(_ attributes: MSDOSAttributes) -> Self { .init(rawValue: attributes.rawValue) }
        public static func unix(_ attributes: UnixAttributes) -> Self { .init(rawValue: numericCast(attributes.rawValue) << 16) }

        var unixAttributes: UnixAttributes { .init(rawValue: numericCast(rawValue >> 16)) }
        var msdosAttributes: MSDOSAttributes { .init(rawValue: rawValue & 0xffff) }
    }

    public struct VersionMadeBy: RawRepresentable, Sendable, Equatable {
        public let rawValue: UInt16
        public init(rawValue: UInt16) {
            self.rawValue = rawValue
        }

        public struct System: RawRepresentable {
            public let rawValue: UInt8
            public init(rawValue: UInt8) {
                self.rawValue = rawValue
            }
            static var msdos: Self { .init(rawValue: 0) }
            static var unix: Self { .init(rawValue: 0x3) }
        }
        public init(system: System, version: UInt8) {
            self.init(rawValue: numericCast(system.rawValue) << 8 | numericCast(version))
        }

        var version: UInt8 { numericCast(rawValue & 0xff) }
        var system: System { .init(rawValue: numericCast(rawValue >> 8)) }
    }

    /// File header for a file in a zip archive.
    public struct FileHeader {
        let versionMadeBy: VersionMadeBy
        var versionNeeded: UInt16
        public var flags: FileFlags
        public var compressionMethod: FileCompressionMethod
        public var fileModification: Date
        public var crc32: UInt32
        var compressedSize: Int64
        public var uncompressedSize: Int64
        public var filename: FilePath
        var extraFields: [ExtraField]
        public var comment: String
        var diskStart: UInt32
        var internalAttribute: UInt16
        public var externalAttributes: ExternalAttributes
        var offsetOfLocalHeader: Int64

        var isDirectory: Bool {
            versionMadeBy.system == .unix
                ? self.externalAttributes.unixAttributes.contains(.isDirectory)
                : self.externalAttributes.msdosAttributes.contains(.isDirectory)
        }
    }

    /// File header extra field
    public struct ExtraField {
        public let header: ExtraFieldHeader
        public let data: ArraySlice<UInt8>
    }

    /// File header extra field header
    public struct ExtraFieldHeader: RawRepresentable, Equatable, CustomStringConvertible {
        public let rawValue: UInt16
        public init(rawValue: UInt16) {
            self.rawValue = rawValue
        }
        public var description: String {
            switch self {
            case .zip64:
                ".zip64"
            case .extendedTimestamp:
                ".extendedTimestamp"
            default:
                "0x\(("000" + String(rawValue, radix: 16)).suffix(4))"
            }
        }
        /// Zip64 extra field (stores 64 bit file sizes and offset)
        public static var zip64: Self { .init(rawValue: 1) }
        /// Extended timestamp extra field (stores created and updated dates as seconds from 1970)
        public static var extendedTimestamp: Self { .init(rawValue: 0x5455) }
    }

    struct Zip64ExtendedInformationExtraField {
        let uncompressedSize: Int64
        let compressedSize: Int64
        let offsetOfLocalHeader: Int64
        let diskStart: UInt32
    }

    struct LocalFileHeader {
        var versionNeeded: UInt16
        var flags: FileFlags
        var compressionMethod: FileCompressionMethod
        var fileModification: Date
        var crc32: UInt32
        var compressedSize: Int64
        var uncompressedSize: Int64
        var filename: FilePath
        var extraFields: [ExtraField]
    }

    struct Zip64EndOfCentralDirectory {
        //let versionMadeBy: UInt16
        let versionNeeded: UInt16
        let diskNumber: UInt32
        let diskNumberCentralDirectoryStarts: UInt32
        let diskEntries: Int64
        let totalEntries: Int64
        let centralDirectorySize: Int64
        let offsetOfCentralDirectory: Int64
    }

    struct Zip64EndOfCentralLocator {
        let diskNumberCentralDirectoryStarts: UInt32
        let relativeOffsetEndOfCentralDirectory: Int64
        let totalNumberOfDisks: UInt32
    }

    struct EndOfCentralDirectory {
        var diskNumber: UInt32
        var diskNumberCentralDirectoryStarts: UInt32
        var diskEntries: Int64
        var totalEntries: Int64
        var centralDirectorySize: Int64
        var offsetOfCentralDirectory: Int64
        var comment: String
    }

    static let localFileHeaderSignature: UInt32 = 0x0403_4b50
    static let fileHeaderSignature: UInt32 = 0x0201_4b50
    static let digitalSignatureSignature: UInt32 = 0x0505_4b50
    static let zip64EndOfCentralDirectorySignature: UInt32 = 0x0606_4b50
    static let zip64EndOfCentralLocatorSignature: UInt32 = 0x0706_4b50
    static let endOfCentralDirectorySignature: UInt32 = 0x0605_4b50
}

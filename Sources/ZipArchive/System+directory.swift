import SystemPackage

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(WASILibc)
import WASILibc
#elseif os(Windows)
import ucrt
#elseif canImport(Android)
import Android
#else
#error("Unsupported Platform")
#endif

#if !os(Windows)

@available( /*System 0.0.1: macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0*/iOS 8, *)
private func valueOrErrno<I: FixedWidthInteger>(
    _ i: I
) -> Result<I, Errno> {
    i == -1 ? .failure(Errno.current) : .success(i)
}

@available( /*System 0.0.1: macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0*/iOS 8, *)
private func nothingOrErrno<I: FixedWidthInteger>(
    _ i: I
) -> Result<(), Errno> {
    valueOrErrno(i).map { _ in () }
}

@available( /*System 0.0.1: macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0*/iOS 8, *)
internal func valueOrErrno<I: FixedWidthInteger>(
    retryOnInterrupt: Bool,
    _ f: () -> I
) -> Result<I, Errno> {
    repeat {
        switch valueOrErrno(f()) {
        case .success(let r): return .success(r)
        case .failure(let err):
            guard retryOnInterrupt && err == .interrupted else { return .failure(err) }
            break
        }
    } while true
}

@available( /*System 0.0.1: macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0*/iOS 8, *)
internal func nothingOrErrno<I: FixedWidthInteger>(
    retryOnInterrupt: Bool,
    _ f: () -> I
) -> Result<(), Errno> {
    valueOrErrno(retryOnInterrupt: retryOnInterrupt, f).map { _ in () }
}

extension Errno {
    internal static var current: Errno {
        get { Errno(rawValue: errno) }
    }
}

extension FileDescriptor {
    static func mkdir(
        _ filePath: FilePath,
        permissions: FilePermissions
    ) throws {
        try filePath.withPlatformString { filename in
            try nothingOrErrno(retryOnInterrupt: true) { system_mkdir(filename, permissions.rawValue) }.get()
        }
    }
}

internal func system_mkdir(
    _ path: UnsafePointer<CInterop.PlatformChar>,
    _ mode: CInterop.Mode
) -> CInt {
    mkdir(path, mode)
}

#endif

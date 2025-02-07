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

#if canImport(Darwin)
internal var system_errno: CInt { Darwin.errno }
#elseif os(Windows)
internal var system_errno: CInt {
    var value: CInt = 0
    // TODO(compnerd) handle the error?
    _ = ucrt._get_errno(&value)
    return value
}
#elseif canImport(Glibc)
internal var system_errno: CInt { Glibc.errno }
#elseif canImport(Musl)
internal var system_errno: CInt { Musl.errno }
#elseif canImport(WASILibc)
internal var system_errno: CInt { WASILibc.errno }
#elseif canImport(Android)
internal var system_errno: CInt { Android.errno }
#endif

private func valueOrErrno<I: FixedWidthInteger>(
    _ i: I
) -> Result<I, Errno> {
    i == -1 ? .failure(Errno.current) : .success(i)
}

private func nothingOrErrno<I: FixedWidthInteger>(
    _ i: I
) -> Result<(), Errno> {
    valueOrErrno(i).map { _ in () }
}

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

internal func nothingOrErrno<I: FixedWidthInteger>(
    retryOnInterrupt: Bool,
    _ f: () -> I
) -> Result<(), Errno> {
    valueOrErrno(retryOnInterrupt: retryOnInterrupt, f).map { _ in () }
}

extension Errno {
    internal static var current: Errno {
        get { Errno(rawValue: system_errno) }
    }
}

extension FileDescriptor {
    static func remove(_ filePath: FilePath) throws {
        try filePath.withPlatformString { filename in
            try nothingOrErrno(retryOnInterrupt: true) { system_remove(filename) }.get()
        }
    }
}

func system_remove(
    _ path: UnsafePointer<CInterop.PlatformChar>
) -> CInt {
    remove(path)
}

#if !os(Windows)

internal typealias system_dirent = dirent
internal let SYSTEM_DT_DIR = DT_DIR
#if os(Linux) || os(Android)
internal typealias system_DIRPtr = OpaquePointer
#else
internal typealias system_DIRPtr = UnsafeMutablePointer<DIR>
#endif

internal func system_mkdir(
    _ path: UnsafePointer<CInterop.PlatformChar>,
    _ mode: CInterop.Mode
) -> CInt {
    mkdir(path, mode)
}

internal func system_fdopendir(
    _ fd: CInt
) -> system_DIRPtr? {
    fdopendir(fd)
}

internal func system_opendir(
    _ path: UnsafePointer<CInterop.PlatformChar>
) -> system_DIRPtr? {
    opendir(path)
}

internal func system_readdir(
    _ dir: system_DIRPtr
) -> UnsafeMutablePointer<dirent>? {
    readdir(dir)
}

internal func system_closedir(
    _ dir: system_DIRPtr
) -> CInt {
    closedir(dir)
}

#endif

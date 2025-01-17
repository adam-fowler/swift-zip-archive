@usableFromInline
struct MemoryBuffer<Bytes: RangeReplaceableCollection> where Bytes.Element == UInt8, Bytes.Index == Int {
    @usableFromInline
    var buffer: Bytes.SubSequence
    @usableFromInline
    var position: Bytes.Index

    @usableFromInline
    init() {
        self.buffer = Bytes()[...]
        self.position = self.buffer.startIndex
    }

    @usableFromInline
    init(_ buffer: Bytes) {
        self.buffer = buffer[...]
        self.position = self.buffer.startIndex
    }

    @usableFromInline
    mutating func read(_ count: Int) throws(MemoryBufferError) -> Bytes.SubSequence {
        guard count >= 0, count <= buffer.distance(from: self.position, to: self.buffer.endIndex) else {
            throw .readingPastEndOfBuffer
        }
        let position = self.position
        self.position = buffer.index(self.position, offsetBy: count)
        return self.buffer[position..<self.position]
    }

    @usableFromInline
    mutating func write<WriteBytes: Collection>(bytes: WriteBytes) where WriteBytes.Element == UInt8 {
        if self.position == self.buffer.endIndex {
            self.buffer.append(contentsOf: bytes)
            self.position = self.buffer.endIndex
        } else if bytes.count <= buffer.distance(from: self.position, to: self.buffer.endIndex) {
            let replaceEndIndex = buffer.index(self.position, offsetBy: bytes.count)
            self.buffer.replaceSubrange(self.position..<replaceEndIndex, with: bytes)
            self.position = replaceEndIndex
        } else {
            self.buffer.replaceSubrange(self.position..., with: bytes)
            self.position = self.buffer.endIndex
        }
    }

    @usableFromInline
    mutating func seek(_ baseOffset: Int) throws(MemoryBufferError) {
        guard baseOffset <= self.buffer.count && baseOffset >= 0 else { throw .offsetOutOfRange }
        self.position = buffer.index(self.buffer.startIndex, offsetBy: baseOffset)
    }

    @usableFromInline
    mutating func seekOffset(_ offset: Int) throws(MemoryBufferError) {
        let baseOffset = self.buffer.index(self.position, offsetBy: offset)
        guard (self.buffer.startIndex...self.buffer.endIndex).contains(baseOffset) else { throw .offsetOutOfRange }
        self.position = baseOffset
    }

    @usableFromInline
    mutating func seekEnd(_ offset: Int = 0) throws(MemoryBufferError) {
        let baseOffset = self.buffer.index(self.buffer.endIndex, offsetBy: offset)
        guard (self.buffer.startIndex...self.buffer.endIndex).contains(baseOffset) else { throw .offsetOutOfRange }
        self.position = baseOffset
    }

    @inlinable
    mutating public func truncate(_ size: Int64) throws(MemoryBufferError) {
        guard size <= self.buffer.count else { throw .offsetOutOfRange }
        self.buffer = self.buffer[..<numericCast(size)]
        self.position = self.buffer.endIndex
    }

    @usableFromInline
    var length: Int { self.buffer.count }

    @inlinable
    public mutating func readInteger<T: FixedWidthInteger>(
        as: T.Type = T.self
    ) throws(MemoryBufferError) -> T {
        let buffer = try read(MemoryLayout<T>.size)
        var value: T = 0
        withUnsafeMutableBytes(of: &value) { valuePtr in
            valuePtr.copyBytes(from: buffer)
        }
        return value
    }

    @inlinable
    public mutating func readIntegers<each T: FixedWidthInteger>(_ type: repeat (each T).Type) throws(MemoryBufferError) -> (repeat each T) {
        (repeat try self.readInteger(as: (each T).self))
    }
}

extension MemoryBuffer: CustomStringConvertible {
    @usableFromInline
    var description: String {
        if self.buffer.count > 50 {
            let endIndex = self.buffer.index(self.buffer.startIndex, offsetBy: 50)
            return "[\(self.buffer[..<endIndex].map{String($0)}.joined(separator: ", ")), ...]"
        } else {
            return "[\(self.buffer.map{String($0)}.joined(separator: ", "))]"
        }
    }
}

@usableFromInline
enum MemoryBufferError: Error {
    case readingPastEndOfBuffer
    case offsetOutOfRange
}

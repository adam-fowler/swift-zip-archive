//
// This source file is part of the swift-zip-archive project
// Copyright (c) 2025-2026 the swift-zip-archive project authors
//
// See LICENSE for license information
// SPDX-License-Identifier: Apache-2.0
//

struct ReadableSpan: ~Copyable, ~Escapable {
    let _bytes: RawSpan
    var lowerBound: Int
    let upperBound: Int

    @inlinable
    @_lifetime(copy bytes)
    public init(_ bytes: RawSpan) {
        self._bytes = bytes
        self.lowerBound = 0
        self.upperBound = bytes.byteCount
    }

    public var bytes: RawSpan {
        @inlinable
        @_lifetime(copy self)
        borrowing get {
            unsafe _bytes.extracting(
                unchecked: Range(uncheckedBounds: (lowerBound, upperBound))
            )
        }
    }

    @unsafe
    @inlinable
    #if compiler(<6.3)
    @_lifetime(copy self)
    #endif
    mutating func consumeUnchecked<T: FixedWidthInteger & BitwiseCopyable>(
        as: T.Type
    ) -> T {
        defer { lowerBound += MemoryLayout<T>.stride }
        return unsafe _bytes.unsafeLoadUnaligned(
            fromUncheckedByteOffset: lowerBound,
            as: T.self
        )
    }

    @unsafe
    @inlinable
    @_lifetime(copy self)
    mutating func consumeUnchecked(count: Int) -> RawSpan {
        let upperBound = lowerBound + count
        defer { lowerBound = upperBound }
        return self._bytes.extracting(unchecked: lowerBound..<upperBound)
    }
}

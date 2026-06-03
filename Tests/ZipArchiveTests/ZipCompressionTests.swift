//
// This source file is part of the swift-zip-archive project
// Copyright (c) 2025-2026 the swift-zip-archive project authors
//
// See LICENSE for license information
// SPDX-License-Identifier: Apache-2.0
//

import Testing

@testable import ZipArchive

final class ZipCompressionTests {
    @Test(arguments: [100, 1000, 10000, 100000])
    func testDeflateInflate(size: Int) throws {
        let array = (0..<size).map { _ in UInt8.random(in: 0...255) }
        let compressor = ZlibDeflateCompression()
        let compressed = try compressor.deflate(from: array)
        let uncompressed = try compressor.inflate(from: compressed, uncompressedSize: array.count)
        #expect(array == uncompressed)
    }
}

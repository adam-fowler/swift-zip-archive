//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

import Benchmark
import CZipArchiveZlib
import Foundation
import ZipArchive

let benchmarks: @Sendable () -> Void = {
    Benchmark.defaultConfiguration = .init(
        metrics: ProcessInfo.processInfo.environment["CI"] != nil
            ? [
                .instructions,
                .mallocCountTotal,
            ]
            : [
                .cpuTotal,
                .instructions,
                .mallocCountTotal,
            ],
        warmupIterations: 10
    )

    Benchmark("crc32", configuration: .init(scalingFactor: .kilo)) { benchmark in
        let buffer = (0..<1024).map { _ in UInt8.random(in: 0...255) }
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            buffer.withUnsafeBufferPointer { buffer in
                blackHole(crc32(0, bytes: buffer))
            }
        }
    }

    Benchmark("ZipArchiveReader.init") { benchmark in
        let file = try buildZipFile(numFile: 2, fileSizeRange: 100..<1000)

        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            try blackHole(ZipArchiveReader(buffer: file))
        }
        benchmark.stopMeasurement()
    }

    Benchmark("ZipArchiveReader.readDirectory") { benchmark in
        let file = try buildZipFile(numFile: 32, fileSizeRange: 100..<4000)
        let reader = try ZipArchiveReader(buffer: file)
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            try blackHole(reader.readDirectory())
        }
        benchmark.stopMeasurement()
    }

    func buildZipFile(numFile: Int, fileSizeRange: Range<Int>) throws -> ArraySlice<UInt8> {
        let writer = ZipArchiveWriter()
        for index in 0..<numFile {
            try writer.writeFile(filename: "file\(index)", contents: (0..<fileSizeRange.randomElement()!).map { _ in UInt8.random(in: 0...255) })
        }
        return try writer.finalizeBuffer()
    }
}

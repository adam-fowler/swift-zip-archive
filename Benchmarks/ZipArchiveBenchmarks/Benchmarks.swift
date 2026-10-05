//
// This source file is part of the swift-zip-archive project
// Copyright (c) 2025-2026 the swift-zip-archive project authors
//
// See LICENSE for license information
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

    Benchmark("ZipArchiveReader.readFile") { benchmark in
        let file = try buildZipFile(numFile: 1, fileSizeRange: 100..<101)
        let reader = try ZipArchiveReader(buffer: file)
        let directory = try reader.readDirectory()
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            let file = directory[0]
            try blackHole(reader.readFile(file))
        }
        benchmark.stopMeasurement()
    }

    func buildZipFile(numFile: Int, fileSizeRange: Range<Int>) throws -> ArraySlice<UInt8> {
        let writer = ZipArchiveWriter()
        let step = Double(fileSizeRange.upperBound - fileSizeRange.lowerBound) / Double(numFile)
        var size = Double(fileSizeRange.lowerBound)
        for index in 0..<numFile {
            let fileSize = Int(size)
            try writer.writeFile(filename: "file\(index)", contents: (0..<fileSize).map { _ in UInt8.random(in: 0...255) })
            size += step
        }
        return try writer.finalizeBuffer()
    }
}

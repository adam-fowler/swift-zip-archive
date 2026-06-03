//
// This source file is part of the swift-zip-archive project
// Copyright (c) 2026 the swift-zip-archive project authors
//
// See LICENSE for license information
// SPDX-License-Identifier: Apache-2.0
//

struct CryptKey {
    var key: (UInt32, UInt32, UInt32)

    init(password: String) {
        key = (305_419_896, 591_751_049, 878_082_192)
        updateKey(values: [UInt8](password.utf8))
    }

    mutating func updateKey(values: some Collection<UInt8>) {
        for value in values {
            updateKey(value)
        }
    }

    mutating func updateKey(_ value: UInt8) {
        key.0 = crc32(key.0, byte: value)
        key.1 += (key.0 & 0xff)
        key.1 = (key.1 &* 134_775_813) + 1
        key.2 = crc32(key.2, byte: UInt8(key.1 >> 24))
    }

    func decryptByte() -> UInt8 {
        let temp: UInt16 = UInt16((key.2 | 2) & 0xffff)
        return numericCast(((temp &* (temp ^ 1)) >> 8) & 0xff)
    }

    mutating func decryptBytes<Bytes: MutableCollection>(_ bytes: inout Bytes) where Bytes.Element == UInt8, Bytes.Index == Int {
        for index in bytes.startIndex..<bytes.endIndex {
            let c = bytes[index] ^ decryptByte()
            updateKey(c)
            bytes[index] = c
        }
    }

    mutating func encryptBytes<Bytes: MutableCollection>(_ bytes: inout Bytes) where Bytes.Element == UInt8, Bytes.Index == Int {
        for index in bytes.startIndex..<bytes.endIndex {
            let t = decryptByte()
            updateKey(bytes[index])
            bytes[index] = t ^ bytes[index]
        }
    }
}

//
// This source file is part of the swift-zip-archive project
// Copyright (c) 2025-2026 the swift-zip-archive project authors
//
// See LICENSE for license information
// SPDX-License-Identifier: Apache-2.0
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension Date {
    init(msdosTime: UInt16, msdosDate: UInt16) {
        let second = Int((msdosTime & 0x1f) * 2)
        let minute = Int((msdosTime & 0x7e0) >> 5)
        let hour = Int((msdosTime & 0xf800) >> 11)

        let day = Int((msdosDate & 0x1f))
        let month = Int((msdosDate & 0x1e0) >> 5)
        let year = Int(((msdosDate & 0xfe00) >> 9) + 1980)

        let dateComponents = DateComponents(calendar: .current, year: year, month: month, day: day, hour: hour, minute: minute, second: second)
        self = dateComponents.date ?? .init(timeIntervalSince1970: 0)
    }

    func msdosDate() -> (time: UInt16, date: UInt16) {
        let components = Calendar.current.dateComponents([.day, .month, .year, .hour, .minute, .second], from: self)

        let year = UInt16(components.year! - 1980)
        let month = UInt16(components.month!)
        let day = UInt16(components.day!)

        let hour = UInt16(components.hour!)
        let minutes = UInt16(components.minute!)
        let seconds = UInt16(components.second! / 2)

        let date = (year << 9) | (month << 5) | day
        let time = (hour << 11) | (minutes << 5) | seconds

        return (time, date)
    }
}

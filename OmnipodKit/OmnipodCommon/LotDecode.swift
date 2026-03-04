//  OmnipodKit
//
//  Created by Joe Moran on 2/24/26.
//  Copyright © 2026 LoopKit Authors. All rights reserved.

import Foundation

// Constants
let ProductCode: [UInt32: String] = [
    0x04: "D1", // 'D'ash (gen 4) U100
    0x18: "D2", // 'D'ash (gen 4) U200
    0x36: "D5", // 'D'ash (gen 4) U500

    0x07: "H1", // 'H'orizon (Omnipod 5) U100
    0x1B: "H2", // 'H'orizon (Omnipod 5) U200
    0x39: "H5", // 'H'orizon (Omnipod 5) U500

    0x02: "E1", // 'E' pod (Omnipod 6?) U100
    0x16: "E2", // 'E' pod (Omnipod 6?) U200
    0x34: "E5", // 'E' pod (Omnipod 6?) U500

    0x05: "P1", // 'P're-production? U100
    0x19: "P2", // 'P're-production? U200
    0x37: "P5", // 'P're-production? U500

    0x03: "A0",
    0x09: "R1",
]

let MfgLoc: [Int: String] = [
    0: "C", // China
    1: "U", // USA
    2: "K", // Kunshan (China)
    3: "M", // Malaysia
]

struct LotDecode {
    var lotU32: UInt32
    var lotHex: String
    var prefix: String
    var pcad: Int
    var productCode: String
    var manufacturingCode: Int
    var manufacturingLocation: String
    var dayOfYear: Int
    var dateMMdd: String
    var year: Int
    var v3: Int
    var nibbleHex: String
    var readableText: String
}

/// Returns the decoded lot information for a modern Insulet 32-bit lot #.
/// This function does not work for the older (Eros and before) lot #s.
func lotDecode(lot: UInt32) -> LotDecode {
    let prefix = (lot & 0x80000000) == 0 ? "P" : "E"

    let pcad = Int((lot >> 25) & mask(6))
    let productCode = ProductCode[UInt32(pcad)] ?? "XX"

    let manufacturingCode = Int((lot >> 22) & mask(3))
    let manufacturingLocation = MfgLoc[manufacturingCode] ?? "X"

    let dayNumber = Int((lot >> 7) & mask(15))
    let YY = dayNumber >> 9
    let dayOfYear = dayNumber - (YY << 9)

    let dateMMdd: String
    if dayOfYear > 0 {
        let date = Calendar.current.date(from: DateComponents(year: Int(YY + 2000), month: 1, day: 1))!.addingTimeInterval(TimeInterval((dayOfYear - 1) * (60*60*24)))
        let formatter = DateFormatter()
        formatter.dateFormat = "MMdd"
        dateMMdd = formatter.string(from: date)
    } else {
        dateMMdd = "0000"
    }

    let v3 = Int((lot >> 4) & mask(3))
    let nibbleHex = String(format: "%X", lot & mask(4))

    let readableText = "\(prefix)\(productCode)\(manufacturingLocation)\(dateMMdd)\(YY)\(v3)\(nibbleHex)"

    return LotDecode(
        lotU32: lot,
        lotHex: String(format: "0x%08X", lot),
        prefix: prefix,
        pcad: pcad,
        productCode: productCode,
        manufacturingCode: manufacturingCode,
        manufacturingLocation: manufacturingLocation,
        dayOfYear: dayOfYear,
        dateMMdd: dateMMdd,
        year: YY + 2000,
        v3: v3,
        nibbleHex: nibbleHex,
        readableText: readableText
    )
}

private func mask(_ n: Int) -> UInt32 {
    return (1 << n) - 1
}

//
//  Id.swift
//  OmnipodKit
//
//  From OmniBLE/OmniBLE/Bluetooth/Id.swift
//  Created by Randall Knutson on 8/5/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import Foundation

// JJJ if patched to non-nil, use this fake controller ID for the O5
var fakeO5Pairing: Bool = false                 // fake O5 pairing using DASH pairing
var fakeO5ControllerID: UInt32? = 0x0000c6c8    // if non-nil, use as the fake O5 controller ID (to match O5 app/PDM traces to real O5 pods)

class Id: Equatable {

    static func fromInt(_ v: Int) -> Id {
        return Id(Data(bigEndian: v).subdata(in: 4..<8))
    }

    static func fromUInt32(_ v: UInt32) -> Id {
        return Id(Data(bigEndian: v))
    }

    let address: Data

    init(_ address: Data) {
        guard address.count == 4 else {
            // TODO: Should probably throw an error here.
            //        require(address.size == 4)
            self.address = Data([0x00, 0x00, 0x00, 0x00])
            return
        }
        self.address = address
    }

    func toInt64() -> Int64 {
        return address.toBigEndian(Int64.self)
    }

    func toUInt32() -> UInt32 {
        return address.toBigEndian(UInt32.self)
    }

    // MARK: Comparable

    static func == (lhs: Id, rhs: Id) -> Bool {
        return lhs.address == rhs.address
    }
}

// The Dash PDM uses the PDM's SN << 2 for the bottom 5 nibbles and some
// unknown values for the top 3 nibbles of its fixed 32-bit controller ID.
// OmniBLE also does this, but OmnipodKit now shifts one more bit for 7 podId's.
func createControllerId(topIdByte: UInt8) -> UInt32 {
    /* JJJ */
    if topIdByte == 0x15, let fakeO5ControllerID = fakeO5ControllerID, !fakeO5Pairing {
        print("Using fake O5 controller ID: \(String(format: "%08X", fakeO5ControllerID))")
        return fakeO5ControllerID
    }
    /* JJJ */
    return (UInt32(topIdByte) << 24) | ((arc4random() & 0x001FFFFF) << 3)
}

// Dash & OmniBLE podId's cycle between 3 #'s of controllerId+1, +2, +3, +1, ...
// OmnipodKit podId's now cycle between 7 #'s of controllerId+1, +2, ... +7, +1, ...
func nextPodId(lastPodId: UInt32) -> UInt32 {
    if (lastPodId & 0b111) == 0b111 {
        // start over at controllerId + 1
        return (lastPodId & ~0b111) + 1
    }
    // return the next sequential podId #
    return lastPodId + 1
}

//
//  PayloadSplitter.swift
//  OmnipodKit
//
//  From OmniBLE/OmniBLE/Bluetooth/Packet/PayloadSplitter.swift
//  Created by Randall Knutson on 8/11/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import Foundation
import CryptoSwift

class PayloadSplitter {
    private let payload: Data
    private let layout: BlePacketLayout

    init(payload: Data, layout: BlePacketLayout) {
        self.payload = payload
        self.layout = layout
    }
    
    func splitInPackets() -> Array<BlePacket> {
        if (payload.count <= layout.firstPacketCapacityWithOptionalPlusOnePacket) {
            return splitInOnePacket()
        }
        var ret = Array<BlePacket>()
        let crc32 = payload.crc32()
        let middleFragments = (payload.count - layout.firstPacketCapacityWithMiddlePackets) / layout.middlePacketCapacity
        let rest = UInt8((payload.count - middleFragments * layout.middlePacketCapacity) - layout.firstPacketCapacityWithMiddlePackets)
        ret.append(
            FirstBlePacket(
                fullFragments: middleFragments + 1,
                payload: payload.subdata(in: 0..<layout.firstPacketCapacityWithMiddlePackets)
            )
        )
        if (middleFragments > 0) {
            for i in 1...middleFragments {
                let p = payload.subdata(in: (layout.firstPacketCapacityWithMiddlePackets + (i - 1) * layout.middlePacketCapacity)..<(layout.firstPacketCapacityWithMiddlePackets + i * layout.middlePacketCapacity))
                ret.append(
                    MiddleBlePacket(
                        index: UInt8(i),
                        payload: p
                    )
                )
            }
        }
        let end = min(layout.lastPacketCapacity, Int(rest))
        ret.append(
            LastBlePacket(
                index: UInt8(middleFragments + 1),
                size: rest,
                payload: payload.subdata(in: middleFragments * layout.middlePacketCapacity + layout.firstPacketCapacityWithMiddlePackets..<middleFragments * layout.middlePacketCapacity + layout.firstPacketCapacityWithMiddlePackets + end),
                crc32: crc32
            )
        )
        if (rest > layout.lastPacketCapacity) {
            ret.append(
                LastOptionalPlusOneBlePacket(
                    index: UInt8(middleFragments + 2),
                    payload: payload.subdata(in: middleFragments * layout.middlePacketCapacity + layout.firstPacketCapacityWithMiddlePackets + layout.lastPacketCapacity..<payload.count),
                    size: UInt8(Int(rest) - layout.lastPacketCapacity)
                )
            )
        }
        return ret
    }

    private func splitInOnePacket() -> Array<BlePacket> {
        var ret = Array<BlePacket>()
        let crc32 = payload.crc32()
        let end = min(layout.firstPacketCapacityWithoutMiddlePackets, payload.count)
        ret.append(
            FirstBlePacket(
                fullFragments: 0,
                payload: payload.subdata(in: 0..<end),
                size: UInt8(payload.count),
                crc32: crc32
            )
        )
        if (payload.count > layout.firstPacketCapacityWithoutMiddlePackets) {
            ret.append(
                LastOptionalPlusOneBlePacket(
                    index: 1,
                    payload: payload.subdata(in: end..<payload.count),
                    size: UInt8(payload.count - end)
                )
            )
        }
        return ret
    }
}

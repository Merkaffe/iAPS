//
//  BLEPacket.swift
//  OmnipodKit
//
//  From OmniBLE/OmniBLE/Bluetooth/Packet/BLEPacket.swift
//  Created by Randall Knutson on 8/11/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import Foundation

// JJJ need to review all these former constants in this file for O5
// and find a better way to handle per pod type BLE differences.
var BlePacket_MAX_PAYLOAD_SIZE = 20 // 20 for DASH and 244 for O5
var BlePacket_MAX_FRAGMENTS = 15 // 15 for DASH (15*20=300 bytes), ?? for O5

var BleFirstPacket_HEADER_SIZE_WITHOUT_MIDDLE_PACKETS = 7 // using all fields
var BleFirstPacket_HEADER_SIZE_WITH_MIDDLE_PACKETS = 2 // 2 for DASH, same for O5? // not using crc32 or size

// FirstBlePacket.CAPACITY_WITHOUT_MIDDLE_PACKETS was MAX_SIZE - HEADER_SIZE_WITHOUT_MIDDLE_PACKETS
var FirstBlePacket_CAPACITY_WITHOUT_MIDDLE_PACKETS = 13 // 20-7=13 for DASH, 256-7=249 for O5?

// FirstBlePacket.CAPACITY_WITH_MIDDLE_PACKET was MAX_SIZE - HEADER_SIZE_WITH_MIDDLE_PACKETS
var FirstBlePacket_CAPACITY_WITH_MIDDLE_PACKETS = 18 // 20-2 for DASH, 256-2=254 for O5?

var FirstBlePacket_CAPACITY_WITH_THE_OPTIONAL_PLUS_ONE_PACKET = 18 // 18 for DASH, 256-2=254 for O5?

var MiddleBlePacket_CAPACITY = 19 // 19 (MAX_SIZE-1) for DASH, 255 for O5?

let LastBlePacket_HEADER_SIZE = 6 // 6 for DASH, same for o5?
// was LastBlePacket.CAPACITY = MAX_SIZE - HEADER_SIZE = 20-6 = 14
var LastBlePacket_CAPACITY = 14 // 14 for DASH, 250 for O5?

protocol BlePacket {
    var payload: Data { get }

    func toData() -> Data
}

struct FirstBlePacket: BlePacket {
    let fullFragments: Int
    let payload: Data
    var size: UInt8?
    var crc32: Data?
    var oneExtraPacket: Bool = false

    func toData() -> Data {
        var bb = Data(capacity: BlePacket_MAX_PAYLOAD_SIZE)
        bb.append(UInt8(0)) // index
        bb.append(UInt8(fullFragments)) // # of fragments except FirstBlePacket and LastOptionalPlusOneBlePacket

        if let crc32 = crc32 {
            bb.append(crc32)
        }
        if let size = size {
            bb.append(UInt8(size))
        }
        bb.append(payload)

        return bb;
    }
    
    static func parse(payload: Data) throws -> FirstBlePacket {
        guard payload.count >= BleFirstPacket_HEADER_SIZE_WITH_MIDDLE_PACKETS else {
            throw PodProtocolError.messageIOException("Wrong packet size")
        }

        if (Int(payload[0]) != 0) {
            // most likely we lost the first packet.
            throw PodProtocolError.incorrectPacketException(payload, 0)
        }

        let fullFragments = Int(payload[1])
        guard (fullFragments <= BlePacket_MAX_FRAGMENTS) else {
            throw PodProtocolError.messageIOException(String(format: "Received more than %d fragments", BlePacket_MAX_FRAGMENTS))
        }

        guard payload.count >= BleFirstPacket_HEADER_SIZE_WITHOUT_MIDDLE_PACKETS else {
            throw PodProtocolError.messageIOException("Wrong packet size")
        }

        if (fullFragments == 0) {
            let rest = payload[6]
            let end = min(Int(rest) + BleFirstPacket_HEADER_SIZE_WITHOUT_MIDDLE_PACKETS, payload.count)
            guard payload.count >= end else {
                throw PodProtocolError.messageIOException("Wrong packet size")
            }

            return FirstBlePacket(
                fullFragments: fullFragments,
                payload: payload.subdata(in: BleFirstPacket_HEADER_SIZE_WITHOUT_MIDDLE_PACKETS..<end),
                size:  rest,
                crc32: payload.subdata(in: 2..<6),
                oneExtraPacket:  Int(rest) + BleFirstPacket_HEADER_SIZE_WITHOUT_MIDDLE_PACKETS > end
            )
        } else if (payload.count < BlePacket_MAX_PAYLOAD_SIZE) {
            throw PodProtocolError.incorrectPacketException(payload, 0)
        }
        return FirstBlePacket(
            fullFragments: fullFragments,
            payload: payload.subdata(in: BleFirstPacket_HEADER_SIZE_WITH_MIDDLE_PACKETS..<BlePacket_MAX_PAYLOAD_SIZE)
        )
    }
}

struct MiddleBlePacket: BlePacket {
    let index: UInt8
    let payload: Data
        
    func toData() -> Data {
        return Data([index]) + payload
    }
    
    static func parse(payload: Data) throws -> MiddleBlePacket {
        guard payload.count >= BlePacket_MAX_PAYLOAD_SIZE else { throw PodProtocolError.messageIOException("Wrong packet size") }
        return MiddleBlePacket(
            index: payload[0],
            payload: payload.subdata(in: 1..<BlePacket_MAX_PAYLOAD_SIZE)
        )
    }
}

struct LastBlePacket: BlePacket {
    let index: UInt8
    let size: UInt8
    let payload: Data
    let crc32: Data
    var oneExtraPacket: Bool = false

    func toData() -> Data {
        var bb = Data(capacity: BlePacket_MAX_PAYLOAD_SIZE)
        bb.append(index)
        bb.append(size)
        bb.append(crc32)
        bb.append(payload)
        bb.append(Data(count: BlePacket_MAX_PAYLOAD_SIZE - payload.count - LastBlePacket_HEADER_SIZE))
        return bb
    }
    
    static func parse(payload: Data) throws -> LastBlePacket {
        guard payload.count >= LastBlePacket_HEADER_SIZE else { throw PodProtocolError.messageIOException("Wrong packet size") }

        let rest = payload[1]
        let end = min(Int(rest) + LastBlePacket_HEADER_SIZE, payload.count)

        guard payload.count >= end else { throw PodProtocolError.messageIOException("Wrong packet size") }

        return LastBlePacket(
            index: payload[0],
            size: rest,
            payload: payload.subdata(in: LastBlePacket_HEADER_SIZE..<end),
            crc32: payload.subdata(in: 2..<6),
            oneExtraPacket: Int(rest) + LastBlePacket_HEADER_SIZE > end
        )
    }
}

struct LastOptionalPlusOneBlePacket: BlePacket {
    static let HEADER_SIZE = 2
    let index: UInt8
    let payload: Data
    let size: UInt8

    func toData() -> Data {
        return Data([index, size]) + payload + Data(count: BlePacket_MAX_PAYLOAD_SIZE - payload.count - 2)
    }

    static func parse(payload: Data) throws -> LastOptionalPlusOneBlePacket {
        guard payload.count >= 2 else { throw PodProtocolError.messageIOException("Wrong packet size") }
        let size = payload[1]
        guard payload.count >= HEADER_SIZE + Int(size) else { throw PodProtocolError.messageIOException("Wrong packet size") }

        return LastOptionalPlusOneBlePacket(
            index: payload[0],
            payload: payload.subdata(in: HEADER_SIZE..<HEADER_SIZE + Int(size)),
            size: size
        )
    }
}

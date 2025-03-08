//
//  CancelDeliveryCommand.swift
//  OmnipodKit
//
//  From OmniBLE/OmnipodCommon/MessageBlocks/CancelDeliveryCommand.swift
//  Created by Pete Schwamb on 2/23/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

struct CancelDeliveryCommand: NonceResyncableMessageBlock {
    let blockType: MessageBlockType = .cancelDelivery
    // OFF 1  2 3 4 5  6
    // 1F 05 NNNNNNNN AX

    // Cancel bolus (with confirmation beep)
    // 1f 05 be1b741a 64

    // Cancel temp basal (with confirmation beep)
    // 1f 05 f76d34c4 62

    // Cancel all (before deactivate pod)
    // 1f 05 e1f78752 07

    // Cancel basal & temp basal for a suspend, followed by a configure alerts command (0x19) for alerts 5 & 6
    // 1f 05 50f02312 03 19 10 50f02312 580f 000f 0604 6800 001e 0302

    struct DeliveryType: OptionSet, Equatable {
        let rawValue: UInt8

        static let none          = DeliveryType()
        static let basal         = DeliveryType(rawValue: 1 << 0)
        static let tempBasal     = DeliveryType(rawValue: 1 << 1)
        static let bolus         = DeliveryType(rawValue: 1 << 2)

        static let allButBasal: DeliveryType = [.tempBasal, .bolus]
        static let all: DeliveryType = [.none, .basal, .tempBasal, .bolus]

        init(rawValue: UInt8) {
            self.rawValue = rawValue
        }

        var debugDescription: String {
            switch self {
            case .none:
                return "None"
            case .basal:
                return "Basal"
            case .tempBasal:
                return "TempBasal"
            case .all:
                return "All"
            case .allButBasal:
                return "AllButBasal"
            default:
                return "\(self.rawValue)"
            }
        }
    }

    let deliveryType: DeliveryType

    let beepType: BeepType

    var nonce: UInt32

    var data: Data {
        var data = Data([
            blockType.rawValue,
            5,
            ])
        data.appendBigEndian(nonce)
        data.append((beepType.rawValue << 4) + deliveryType.rawValue)
        return data
    }

    init(encodedData: Data) throws {
        if encodedData.count < 7 {
            throw MessageBlockError.notEnoughData
        }
        self.nonce = encodedData[2...].toBigEndian(UInt32.self)
        self.deliveryType = DeliveryType(rawValue: encodedData[6] & 0xf)
        self.beepType = BeepType(rawValue: encodedData[6] >> 4)!
    }

    init(nonce: UInt32, deliveryType: DeliveryType, beepType: BeepType) {
        self.nonce = nonce
        self.deliveryType = deliveryType
        self.beepType = beepType
    }
}

extension CancelDeliveryCommand: CustomDebugStringConvertible {
    var debugDescription: String {
        return "CancelDeliveryCommand(nonce:\(Data(bigEndian: nonce).hexadecimalString), deliveryType:\(deliveryType.debugDescription), beepType:\(beepType))"
    }
}

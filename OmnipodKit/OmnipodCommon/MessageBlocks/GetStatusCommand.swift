//
//  GetStatusCommand.swift
//  OmnipodKit
//
//  From OmniBLE/OmnipodCommon/MessageBlocks/GetStatusCommand.swift
//  Created by Pete Schwamb on 10/14/17.
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//
import Foundation

struct GetStatusCommand: MessageBlock {
    // OFF 1  2
    // Oe 01 TT

    let blockType: MessageBlockType = .getStatus
    let length: UInt8 = 1
    let podInfoType: PodInfoResponseSubType

    init(podInfoType: PodInfoResponseSubType = .normal) {
        self.podInfoType = podInfoType
    }

    init(encodedData: Data) throws {
        if encodedData.count < 3 {
            throw MessageBlockError.notEnoughData
        }
        guard let podInfoType = PodInfoResponseSubType(rawValue: encodedData[2]) else {
            throw MessageError.unknownValue(value: encodedData[2], typeDescription: "PodInfoResponseSubType")
        }
        self.podInfoType = podInfoType
    }

    var data: Data {
        var data = Data([
            blockType.rawValue,
            length
            ])
        data.append(podInfoType.rawValue)
        return data
    }
}

extension GetStatusCommand: CustomDebugStringConvertible {
    var debugDescription: String {
        return "GetStatusCommand(\(podInfoType))"
    }
}

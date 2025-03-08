//
//  AssignAddressCommand.swift
//  OmnipodKit
//
//  From OmniBLE/OmnipodCommon/MessageBlocks/AssignAddressCommand.swift
//  Created by Pete Schwamb on 2/12/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

struct AssignAddressCommand: MessageBlock {
    let blockType: MessageBlockType = .assignAddress
    let length: Int = 6

    let address: UInt32

    var data: Data {
        var data = Data([
            blockType.rawValue,
            4
        ])
        data.appendBigEndian(self.address)
        return data
    }

    init(encodedData: Data) throws {
        if encodedData.count < length {
            throw MessageBlockError.notEnoughData
        }

        self.address = encodedData[2...].toBigEndian(UInt32.self)
    }

    init(address: UInt32) {
        self.address = address
    }
}

extension AssignAddressCommand: CustomDebugStringConvertible {
    var debugDescription: String {
        return "AssignAddressCommand(address:\(Data(bigEndian: address).hexadecimalString))"
    }
}

//
//  DeactivatePodCommand.swift
//  OmnipodKit
//
//  From OmniBLE/OmnipodCommon/MessageBlocks/DeactivatePodCommand.swift
//  Created by Pete Schwamb on 2/24/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//
import Foundation

struct DeactivatePodCommand: NonceResyncableMessageBlock {
    // OFF 1  2 3 4 5
    // 1C 04 NNNNNNNN

    let blockType: MessageBlockType = .deactivatePod

    var nonce: UInt32

    var data: Data {
        var data = Data([
            blockType.rawValue,
            4,
            ])
        data.appendBigEndian(nonce)
        return data
    }

    init(encodedData: Data) throws {
        if encodedData.count < 6 {
            throw MessageBlockError.notEnoughData
        }
        self.nonce = encodedData[2...].toBigEndian(UInt32.self)
    }

    init(nonce: UInt32) {
        self.nonce = nonce
    }
}

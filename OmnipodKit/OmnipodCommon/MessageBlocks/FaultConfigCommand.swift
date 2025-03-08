//
//  FaultConfigCommand.swift
//  OmnipodKit
//
//  From OmniBLE/OmnipodCommon/MessageBlocks/FaultConfigCommand.swift
//  Created by Pete Schwamb on 12/18/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//
import Foundation

struct FaultConfigCommand: NonceResyncableMessageBlock {
    // OFF 1  2 3 4 5  6  7
    // 08 06 NNNNNNNN JJ KK

    let blockType: MessageBlockType = .faultConfig
    let length: UInt8 = 6
    var nonce: UInt32
    let tab5Sub16: UInt8
    let tab5Sub17: UInt8

    init(nonce: UInt32, tab5Sub16: UInt8, tab5Sub17: UInt8) {
        self.nonce = nonce
        self.tab5Sub16 = tab5Sub16
        self.tab5Sub17 = tab5Sub17
    }

    init(encodedData: Data) throws {
        if encodedData.count < 8 {
            throw MessageBlockError.notEnoughData
        }

        self.nonce = encodedData[2...].toBigEndian(UInt32.self)

        self.tab5Sub16 = encodedData[6]
        self.tab5Sub17 = encodedData[7]
    }

    var data: Data {
        var data = Data([
            blockType.rawValue,
            length])

        data.appendBigEndian(nonce)
        data.append(tab5Sub16)
        data.append(tab5Sub17)
        return data
    }
}

extension FaultConfigCommand: CustomDebugStringConvertible {
    var debugDescription: String {
        return "FaultConfigCommand(nonce:\(Data(bigEndian: nonce).hexadecimalString), tab5Sub16:\(tab5Sub16), tab5Sub17:\(tab5Sub17))"
    }
}

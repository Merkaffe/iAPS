//
//  PodInfoResponse.swift
//  OmnipodKit
//
//  From OmniBLE/OmnipodCommon/MessageBlocks/PodInfoResponse.swift
//  Created by Pete Schwamb on 2/23/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

struct PodInfoResponse : MessageBlock {

    let blockType              : MessageBlockType = .podInfoResponse
    let podInfoResponseSubType : PodInfoResponseSubType
    let podInfo                : PodInfo
    let data                   : Data

    init(encodedData: Data) throws {
        guard let subType = PodInfoResponseSubType(rawValue: encodedData[2]) else {
            throw MessageError.unknownValue(value: encodedData[2], typeDescription: "PodInfoResponseSubType")
        }
        self.podInfoResponseSubType = subType
        let len = encodedData.count
        self.podInfo = try podInfoResponseSubType.podInfoType.init(encodedData: encodedData.subdata(in: 2..<len))
        self.data = encodedData
    }
}

extension PodInfoResponse: CustomDebugStringConvertible {
    var debugDescription: String {
        return "PodInfoResponse(\(blockType), \(podInfoResponseSubType), \(podInfo)"
    }
}

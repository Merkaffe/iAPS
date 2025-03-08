//
//  BeepConfigCommand.swift
//  OmnipodKit
//
//  From OmniBLE/OmnipodCommon/MessageBlocks/BeepConfigCommand.swift
//  Created by Joseph Moran on 5/12/19.
//  Copyright © 2019 Pete Schwamb. All rights reserved.
//

import Foundation

struct BeepConfigCommand: MessageBlock {
    // OFF 1  2 3 4 5
    // 1e 04 AABBCCDD

    let blockType: MessageBlockType = .beepConfig
    let beepType: BeepType
    let basalCompletionBeep: Bool
    let basalIntervalBeep: TimeInterval
    let tempBasalCompletionBeep: Bool
    let tempBasalIntervalBeep: TimeInterval
    let bolusCompletionBeep: Bool
    let bolusIntervalBeep: TimeInterval

    init(beepType: BeepType, basalCompletionBeep: Bool = false, basalIntervalBeep: TimeInterval = 0, tempBasalCompletionBeep: Bool = false, tempBasalIntervalBeep: TimeInterval = 0, bolusCompletionBeep: Bool = false, bolusIntervalBeep: TimeInterval = 0) {
        self.beepType = beepType
        self.basalCompletionBeep = basalCompletionBeep
        self.basalIntervalBeep = basalIntervalBeep
        self.tempBasalCompletionBeep = tempBasalCompletionBeep
        self.tempBasalIntervalBeep = tempBasalIntervalBeep
        self.bolusCompletionBeep = bolusCompletionBeep
        self.bolusIntervalBeep = bolusIntervalBeep
    }

    init(encodedData: Data) throws {
        if encodedData.count < 6 {
            throw MessageBlockError.notEnoughData
        }
        if let beepType = BeepType.init(rawValue: encodedData[2]) {
            self.beepType = beepType
        } else {
            throw MessageBlockError.parseError
        }
        self.basalCompletionBeep = encodedData[3] & (1<<6) != 0
        self.basalIntervalBeep = TimeInterval(minutes: Double(encodedData[3] & 0x3f))
        self.tempBasalCompletionBeep = encodedData[4] & (1<<6) != 0
        self.tempBasalIntervalBeep = TimeInterval(minutes: Double(encodedData[4] & 0x3f))
        self.bolusCompletionBeep = encodedData[5] & (1<<6) != 0
        self.bolusIntervalBeep = TimeInterval(minutes: Double(encodedData[5] & 0x3f))
    }

    var data: Data {
        var data = Data([
            blockType.rawValue,
            4,
            ])
        data.append(beepType.rawValue)
        data.append((basalCompletionBeep ? (1<<6) : 0) + (UInt8(basalIntervalBeep.minutes) & 0x3f))
        data.append((tempBasalCompletionBeep ? (1<<6) : 0) + (UInt8(tempBasalIntervalBeep.minutes) & 0x3f))
        data.append((bolusCompletionBeep ? (1<<6) : 0) + (UInt8(bolusIntervalBeep.minutes) & 0x3f))
        return data
    }
}

extension BeepConfigCommand: CustomDebugStringConvertible {
    var debugDescription: String {
        return "BeepConfigCommand(beepType:\(beepType), basalIntervalBeep:\(basalIntervalBeep), tempBasalCompletionBeep:\(tempBasalCompletionBeep), tempBasalIntervalBeep:\(tempBasalIntervalBeep), bolusCompletionBeep:\(bolusCompletionBeep), bolusIntervalBeep:\(bolusIntervalBeep))"
    }
}

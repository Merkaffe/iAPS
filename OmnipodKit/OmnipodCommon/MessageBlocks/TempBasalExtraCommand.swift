//
//  TempBasalExtraCommand.swift
//  OmnipodKit
//
//  From OmniBLE/OmnipodCommon/MessageBlocks/TempBasalExtraCommand.swift
//  Created by Pete Schwamb on 6/6/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

struct TempBasalExtraCommand : MessageBlock {

    let acknowledgementBeep: Bool
    let completionBeep: Bool
    let programReminderInterval: TimeInterval
    let remainingPulses: Double
    let delayUntilFirstPulse: TimeInterval
    let rateEntries: [RateEntry]

    let blockType: MessageBlockType = .tempBasalExtra

    var data: Data {
        let beepOptions = (UInt8(programReminderInterval.minutes) & 0x3f) + (completionBeep ? (1<<6) : 0) + (acknowledgementBeep ? (1<<7) : 0)
        var data = Data([
            blockType.rawValue,
            UInt8(8 + rateEntries.count * 6),
            beepOptions,
            0
            ])
        data.appendBigEndian(UInt16(round(remainingPulses * 10)))
        data.appendBigEndian(UInt32(delayUntilFirstPulse.hundredthsOfMilliseconds))
        for entry in rateEntries {
            data.append(entry.data)
        }
        return data
    }

    init(encodedData: Data) throws {
        if encodedData.count < 14 {
            throw MessageBlockError.notEnoughData
        }

        let length = encodedData[1]
        let numEntries = (length - 8) / 6

        acknowledgementBeep = encodedData[2] & (1<<7) != 0
        completionBeep = encodedData[2] & (1<<6) != 0
        programReminderInterval = TimeInterval(minutes: Double(encodedData[2] & 0x3f))

        remainingPulses = Double(encodedData[4...].toBigEndian(UInt16.self)) / 10.0
        let timerCounter = encodedData[6...].toBigEndian(UInt32.self)
        delayUntilFirstPulse = TimeInterval(hundredthsOfMilliseconds: Double(timerCounter))

        var entries = [RateEntry]()
        for entryIndex in (0..<numEntries) {
            let offset = 10 + entryIndex * 6
            let totalPulses = Double(encodedData[offset...].toBigEndian(UInt16.self)) / 10.0
            let timerCounter = encodedData[(offset+2)...].toBigEndian(UInt32.self) & ~nearZeroBasalRateFlag
            let delayBetweenPulses = TimeInterval(hundredthsOfMilliseconds: Double(timerCounter))
            entries.append(RateEntry(totalPulses: totalPulses, delayBetweenPulses: delayBetweenPulses))
        }
        rateEntries = entries
    }

    init(rate: Double, duration: TimeInterval, acknowledgementBeep: Bool = false, completionBeep: Bool = false, programReminderInterval: TimeInterval = 0, podType: PodType)
    {
        rateEntries = RateEntry.makeEntries(rate: rate, duration: duration, podType: podType)
        remainingPulses = rateEntries[0].totalPulses
        delayUntilFirstPulse = rateEntries[0].delayBetweenPulses
        self.acknowledgementBeep = acknowledgementBeep
        self.completionBeep = completionBeep
        self.programReminderInterval = programReminderInterval
    }
}

extension TempBasalExtraCommand: CustomDebugStringConvertible {
    var debugDescription: String {
        return "TempBasalExtraCommand(completionBeep:\(completionBeep), programReminderInterval:\(programReminderInterval.timeIntervalStr), remainingPulses:\(remainingPulses), delayUntilFirstPulse:\(delayUntilFirstPulse.timeIntervalStr), rateEntries:\(rateEntries))"
    }
}

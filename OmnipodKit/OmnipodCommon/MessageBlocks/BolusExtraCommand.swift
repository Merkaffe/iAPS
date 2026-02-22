//
//  BolusExtraCommand.swift
//  OmnipodKit
//
//  From OmniBLE/OmnipodCommon/MessageBlocks/BolusExtraCommand.swift
//  Created by Pete Schwamb on 2/24/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

// O5 only additional BolusExtraCommand data
struct BolusInfo {
    let bolusSource: Int8 // typically 1
    let mealUnits: Double // O for prime and cannula insert boluses
    let correctionUnits: Double

    init(bolusSource: Int8 = 1, mealUnits: Double = 0.0, correctionUnits: Double = 0.0) {
        self.bolusSource = bolusSource
        self.mealUnits = mealUnits
        self.correctionUnits = correctionUnits
    }
}

struct BolusExtraCommand: MessageBlock {
    let blockType: MessageBlockType = .bolusExtra

    let acknowledgementBeep: Bool
    let completionBeep: Bool
    let programReminderInterval: TimeInterval
    let units: Double
    let timeBetweenPulses: TimeInterval
    let extendedUnits: Double
    let extendedDuration: TimeInterval
    let bolusInfo: BolusInfo? // O5 only, nil for Eros or Dash

    // 17 LL BO NNNN XXXXXXXX YYYY ZZZZZZZZ (Eros/Dash)
    // 17 0d 7c 1770 00030d40 0000 00000000

    // 17 LL BO NNNN XXXXXXXX YYYY ZZZZZZZZ BB MMMM CCCC (O5)
    // 17 12 7c 0208 000186a0 0000 00000000 01 0000 0000 (O5 prime bolus)
    // 17 12 7c 00c8 00030d40 0000 00000000 01 00c8 0000 (O5 1.0U bolus)


    var data: Data {
        let beepOptions = (UInt8(programReminderInterval.minutes) & 0x3f) + (completionBeep ? (1<<6) : 0) + (acknowledgementBeep ? (1<<7) : 0)

        var data = Data([
            blockType.rawValue,
            bolusInfo != nil ? 0x12 : 0x0d, // O5 has additional 5 bytes of bolus info
            beepOptions
            ])

        data.appendBigEndian(UInt16(round(units * Pod.pulsesPerUnit * 10)))
        data.appendBigEndian(UInt32(timeBetweenPulses.hundredthsOfMilliseconds))

        let pulseCountX10 = UInt16(round(extendedUnits * Pod.pulsesPerUnit * 10))
        data.appendBigEndian(pulseCountX10)

        let timeBetweenExtendedPulses = pulseCountX10 > 0 ? extendedDuration / (Double(pulseCountX10) / 10) : 0
        data.appendBigEndian(UInt32(timeBetweenExtendedPulses.hundredthsOfMilliseconds))

        if let bolusInfo = bolusInfo {
            // O5 specific added bolus info
            data.append(UInt8(bolusInfo.bolusSource))
            let mealUnits = UInt16(round(bolusInfo.mealUnits * Pod.pulsesPerUnit * 10))
            data.appendBigEndian(mealUnits)
            let correctionUnits = UInt16(round(bolusInfo.correctionUnits * Pod.pulsesPerUnit * 10))
            data.appendBigEndian(correctionUnits)
        }

        return data
    }

    init(encodedData: Data) throws {
        if encodedData.count < 15 || (encodedData[1] == 0x12 && encodedData.count < 20) {
            throw MessageBlockError.notEnoughData
        }

        acknowledgementBeep = encodedData[2] & (1<<7) != 0
        completionBeep = encodedData[2] & (1<<6) != 0
        programReminderInterval = TimeInterval(minutes: Double(encodedData[2] & 0x3f))

        units = Double(encodedData[3...].toBigEndian(UInt16.self)) / (Pod.pulsesPerUnit * 10)

        let delayCounts = encodedData[5...].toBigEndian(UInt32.self)
        timeBetweenPulses = TimeInterval(hundredthsOfMilliseconds: Double(delayCounts))

        let pulseCountX10 = encodedData[9...].toBigEndian(UInt16.self)
        extendedUnits = Double(pulseCountX10) / (Pod.pulsesPerUnit * 10)

        let intervalCounts = encodedData[11...].toBigEndian(UInt32.self)
        let timeBetweenExtendedPulses = TimeInterval(hundredthsOfMilliseconds: Double(intervalCounts))
        extendedDuration = timeBetweenExtendedPulses * (Double(pulseCountX10) / 10)

        if encodedData[1] == 0x12 {
            // Extended O5 version with extra bolus info
            let bolusSource = Int8(encodedData[15])
            let mealUnits = Double(encodedData[16...].toBigEndian(UInt16.self)) / (Pod.pulsesPerUnit * 10)
            let correctionUnits = Double(encodedData[18...].toBigEndian(UInt16.self)) / (Pod.pulsesPerUnit * 10)
            bolusInfo = BolusInfo(bolusSource: bolusSource, mealUnits: mealUnits, correctionUnits: correctionUnits)
        } else {
            // Standard Eros or DASH version with no additional bolus info
            bolusInfo = nil
        }
    }

    init(units: Double = 0,
         timeBetweenPulses: TimeInterval = Pod.secondsPerBolusPulse,
         extendedUnits: Double = 0.0,
         extendedDuration: TimeInterval = 0,
         acknowledgementBeep: Bool = false,
         completionBeep: Bool = false,
         programReminderInterval: TimeInterval = 0,
         bolusInfo: BolusInfo? = nil // O5 only, nil for Eros or Dash
    ) {
        self.acknowledgementBeep = acknowledgementBeep
        self.completionBeep = completionBeep
        self.programReminderInterval = programReminderInterval
        self.units = units
        self.timeBetweenPulses = timeBetweenPulses != 0 ? timeBetweenPulses : Pod.secondsPerBolusPulse
        self.extendedUnits = extendedUnits
        self.extendedDuration = extendedDuration
        self.bolusInfo = bolusInfo
    }
}

extension BolusExtraCommand: CustomDebugStringConvertible {
    var debugDescription: String {
        if let bolusInfo = bolusInfo {
            // Extended O5-only format with additional bolus info
            return "BolusExtraCommand(units:\(units), timeBetweenPulses:\(timeBetweenPulses), extendedUnits:\(extendedUnits), extendedDuration:\(extendedDuration), acknowledgementBeep:\(acknowledgementBeep), completionBeep:\(completionBeep), programReminderInterval:\(programReminderInterval.minutes), bolusInfo:\(bolusInfo)"
        } else {
            // Standard Eros or Dash format
            return "BolusExtraCommand(units:\(units), timeBetweenPulses:\(timeBetweenPulses), extendedUnits:\(extendedUnits), extendedDuration:\(extendedDuration), acknowledgementBeep:\(acknowledgementBeep), completionBeep:\(completionBeep), programReminderInterval:\(programReminderInterval.minutes)"
        }
    }
}

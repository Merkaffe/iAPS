//
//  VersionResponse.swift
//  OmnipodKit
//
//  From OmniBLE/OmnipodCommon/MessageBlocks/VersionResponse.swift
//  Created by Pete Schwamb on 2/12/18.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import Foundation

fileprivate let assignAddressVersionLength: UInt8 = 0x15
fileprivate let setupPodVersionLength: UInt8 = 0x1B

struct VersionResponse : MessageBlock {

    struct FirmwareVersion : CustomStringConvertible {
        let major: UInt8
        let minor: UInt8
        let patch: UInt8

        init(encodedData: Data) {
            major = encodedData[0]
            minor = encodedData[1]
            patch = encodedData[2]
        }

        var description: String {
            return "\(major).\(minor).\(patch)"
        }
    }

    let blockType: MessageBlockType = .versionResponse

    let firmwareVersion: FirmwareVersion     // for Eros (PM) 2.x.y, for NXP Dash 3.x.y, for TWI Dash 4.x.y
    let iFirmwareVersion: FirmwareVersion    // for Eros (PI) same as PM, for Dash BLE firmware version #
    let podType: PodType                     // 02 for Eros, 04 for Dash, perhaps 05 for Omnipod 5
    let lot: UInt32
    let tid: UInt32
    let address: UInt32
    let podProgressStatus: PodProgressStatus

    // These values only included in the shorter 0x15 VersionResponse for the AssignAddress command for Eros.
    let gain: UInt8?                         // 2-bit value, max gain is at 0, min gain is at 2
    let rssi: UInt8?                         // 6-bit value, max rssi seen 61

    // These values only included in the longer 0x1B VersionResponse for the SetupPod command.
    let pulseSize: Double?                   // VVVV / 100,000, must be 0x1388 / 100,000 = 0.05U
    let secondsPerBolusPulse: Double?        // BR / 8, nominally 0x10 / 8 = 2 seconds per pulse
    let secondsPerPrimePulse: Double?        // PR / 8, nominally 0x08 / 8 = 1 seconds per priming pulse
    let primeUnits: Double?                  // PP / pulsesPerUnit, nominally 0x34 / 20 = 2.6U
    let cannulaInsertionUnits: Double?       // CP / pulsesPerUnit, nominally 0x0A / 20 = 0.5U
    let serviceDuration: TimeInterval?       // PL hours, nominally 0x50 = 80 hours

    let data: Data

    init(encodedData: Data) throws {
        let responseLength = encodedData[1]
        data = encodedData.subdata(in: 0..<Int(responseLength + 2))

        switch responseLength {
        case assignAddressVersionLength:
            // This is the shorter 0x15 response for the 07 AssignAddress command.
            // 0  1  2      5      8  9  10       14       18 19
            // 01 LL MXMYMZ IXIYIZ ID 0J LLLLLLLL TTTTTTTT GS IIIIIIII
            // 01 15 020700 020700 02 02 0000a377 0003ab37 9f 1f00ee87
            //
            // LL = 0x15 (assignAddressVersionLength)
            // PM MX.MY.MZ = 02.07.02 (for PM 2.7.0)
            // PI IX.IY.IZ = 02.07.02 (for PI 2.7.0)
            // ID = Product Id (02 for Eros, 04 for Dash, and perhaps 05 for Omnnipod 5)
            // 0J = Pod progress state (typically 02 for this particular response)
            // LLLLLLLL = Lot
            // TTTTTTTT = Tid
            // GS = ggssssss (Gain/RSSI for Eros only)
            // IIIIIIII = connection ID address

            firmwareVersion = FirmwareVersion(encodedData: encodedData.subdata(in: 2..<5))
            iFirmwareVersion = FirmwareVersion(encodedData: encodedData.subdata(in: 5..<8))
            podType = PodType(rawValue: encodedData[8])
            guard let progressStatus = PodProgressStatus(rawValue: encodedData[9]) else {
                throw MessageBlockError.parseError
            }
            podProgressStatus = progressStatus
            lot = encodedData[10...].toBigEndian(UInt32.self)
            tid = encodedData[14...].toBigEndian(UInt32.self)
            address = encodedData[19...].toBigEndian(UInt32.self)

            // The gain and RSSI fields are only valid for Eros pods in the shorter 0x15 VersionResponse
            if podType == erosType {
                gain = (encodedData[18] & 0xc0) >> 6
                rssi = encodedData[18] & 0x3f
            } else {
                gain = nil
                rssi = nil
            }

            // These values only included in the longer 0x1B VersionResponse for the 03 SetupPod command.
            pulseSize = nil
            secondsPerBolusPulse = nil
            secondsPerPrimePulse = nil
            primeUnits = nil
            cannulaInsertionUnits = nil
            serviceDuration = nil

        case setupPodVersionLength:
            // This is the longer 0x1B response for the 03 SetupPod command.
            // 0  1  2    4  5  6  7  8  9      12     15 16 17       21       25
            // 01 LL VVVV BR PR PP CP PL MXMYMZ IXIYIZ ID 0J LLLLLLLL TTTTTTTT IIIIIIII
            // 01 1b 1388 10 08 34 0a 50 020700 020700 02 03 0000a62b 00044794 1f00ee87
            //
            // LL = 0x1b (setupPodVersionMessageLength)
            // VVVV = 0x1388, pulse Volume in micro-units of U100 insulin per tenth of pulse (5000/100000 = 0.05U per pulse)
            // BR = 0x10, Basic pulse Rate in # of eighth secs per pulse (16/8 = 2 seconds per pulse)
            // PR = 0x08, Prime pulse Rate in # of eighth secs per pulse for priming boluses (8/8 = 1 second per priming pulse)
            // PP = 0x34 = 52, # of Prime Pulses (52 pulses x 0.05U/pulse = 2.6U)
            // CP = 0x0A = 10, # of Cannula insertion Pulses (10 pulses x 0.05U/pulse = 0.5U)
            // PL = 0x50 = 80, # of hours maximum Pod Life
            // PM = MX.MY.MZ = 02.07.02 (for PM 2.7.0 for Eros)
            // PI = IX.IY.IZ = 02.07.02 (for PI 2.7.0 for Eros)
            // ID = Product Id (02 for Eros, 04 for Dash, and perhaps 05 for Omnnipod 5)
            // 0J = Pod progress state (should be 03 for this particular response)
            // LLLLLLLL = Lot
            // TTTTTTTT = Tid
            // IIIIIIII = connection ID address

            firmwareVersion = FirmwareVersion(encodedData: encodedData.subdata(in: 9..<12))
            iFirmwareVersion = FirmwareVersion(encodedData: encodedData.subdata(in: 12..<15))
            podType = PodType(rawValue: encodedData[15])
            guard let progressStatus = PodProgressStatus(rawValue: encodedData[16]) else {
                throw MessageBlockError.parseError
            }
            podProgressStatus = progressStatus
            lot = encodedData[17...].toBigEndian(UInt32.self)
            tid = encodedData[21...].toBigEndian(UInt32.self)
            address = encodedData[25...].toBigEndian(UInt32.self)

            // These values should be verified elsewhere and appropriately handled.
            pulseSize = Double(encodedData[2...].toBigEndian(UInt16.self)) / 100000
            secondsPerBolusPulse = Double(encodedData[4]) / 8
            secondsPerPrimePulse = Double(encodedData[5]) / 8
            primeUnits = Double(encodedData[6]) / Pod.pulsesPerUnit
            cannulaInsertionUnits = Double(encodedData[7]) / Pod.pulsesPerUnit
            serviceDuration = TimeInterval.hours(Double(encodedData[8]))

            // These values only included in the shorter 0x15 VersionResponse for the AssignAddress command for Eros.
            gain = nil
            rssi = nil

        default:
            throw MessageBlockError.parseError
        }
    }

    var isAssignAddressVersionResponse: Bool {
        return self.data.count == assignAddressVersionLength + 2
    }

    var isSetupPodVersionResponse: Bool {
        return self.data.count == setupPodVersionLength + 2
    }
}

extension VersionResponse: CustomDebugStringConvertible {
    var debugDescription: String {

        // Common fields valid in both types of VersionResponses
        var retVal = "VersionResponse(lot:\(lot), tid:\(tid), address:\(Data(bigEndian: address).hexadecimalString), firmwareVersion:\(firmwareVersion), iFirmwareVersion:\(iFirmwareVersion), podType:\(podType.localizedDescription), podProgressStatus:\(podProgressStatus)"

        // The optional gain and RSSI fields are only valid for Eros pods in the shorter AssignAddress VersionResponse
        if let gain = gain, let rssi = rssi {
            retVal += ", gain:\(gain.description), rssi:\(rssi.description)"
        }

        // Optional fields from the longer SetupPod VersionResponses
        if let pulseSize = pulseSize,
           let secondsPerBolusPulse = secondsPerBolusPulse,
           let secondsPerPrimePulse = secondsPerPrimePulse,
           let primeUnits = primeUnits,
           let cannulaInsertionUnits = cannulaInsertionUnits,
           let serviceDuration = serviceDuration
        {
            retVal += ", pulseSize:\(pulseSize.description), secondsPerBolusPulse:\(secondsPerBolusPulse.description), secondsPerPrimePulse:\(secondsPerPrimePulse.description), primeUnits:\(primeUnits.description), cannulaInsertionUnits:\(cannulaInsertionUnits.description), serviceDuration:\(serviceDuration.timeIntervalStr)"
        }

        return retVal + ")"
    }
}

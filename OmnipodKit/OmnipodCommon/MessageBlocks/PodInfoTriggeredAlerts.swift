//
//  PodInfoTriggeredAlerts.swift
//  OmnipodKit
//
//  From OmniBLE/OmnipodCommon/MessageBlocks/PodInfoTriggeredAlerts.swift
//  Created by Eelke Jager on 16/09/2018.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

// Type 1 Pod Info returns information about the currently unacknowledged triggered alert values
// All triggered alerts values are the pod time when triggered for all current Eros and Dash pods.
// For at least earlier Eros pods, low reservoir triggered alerts might be the # of pulses remaining.
struct PodInfoTriggeredAlerts: PodInfo {
    // CMD 1  2  3 4  5 6  7 8  910 1112 1314 1516 1718 1920
    // DATA   0  1 2  3 4  5 6  7 8  910 1112 1314 1516 1718
    // 02 13 01 XXXX VVVV VVVV VVVV VVVV VVVV VVVV VVVV VVVV

    let podInfoType: PodInfoResponseSubType = .triggeredAlerts
    let unknown_word: UInt16
    var alertActivations: [TimeInterval] = Array(repeating: 0, count: 8)
    let data: Data

    init(encodedData: Data) throws {
        guard encodedData.count >= 11 else {
            throw MessageBlockError.notEnoughData
        }

        // initialize the eight VVVV triggered alert values starting at offset 3
        for i in 0..<8 {
            let j = 3 + (2 * i)
            self.alertActivations[i] = TimeInterval(minutes: Double(encodedData[j...].toBigEndian(UInt16.self)))
        }
        self.unknown_word = encodedData[1...].toBigEndian(UInt16.self)
        self.data = encodedData
    }
}

private func triggeredAlerts(podInfoTriggeredAlerts: PodInfoTriggeredAlerts, sepString: String, printZeroVals: Bool) -> String {
    var result: [String] = []

    // N.B. The starting offset depends on the project name length
    // Optional(OmnipodKit.AlertSlot.slot0AutoOff)
    // 0123456789012345678901234567890
    // 0         1         2         3
    let startOffset = 30
    for index in podInfoTriggeredAlerts.alertActivations.indices {
        // extract the alert slot debug description for a more helpful display
        let description = AlertSlot(rawValue: UInt8(index)).debugDescription
        let start = description.index(description.startIndex, offsetBy: startOffset)
        let end = description.index(description.endIndex, offsetBy: -1)
        let range = start..<end

        let triggeredTimeStr: String
        if printZeroVals || podInfoTriggeredAlerts.alertActivations[index] != 0 {
            triggeredTimeStr = podInfoTriggeredAlerts.alertActivations[index].timeIntervalStr
        } else {
            triggeredTimeStr = ""
        }
        result.append(String(format: "%@: %@", String(description[range]), triggeredTimeStr))
    }

    return result.joined(separator: sepString)
}

func triggeredAlertsString(podInfoTriggeredAlerts: PodInfoTriggeredAlerts) -> String {
    return triggeredAlerts(podInfoTriggeredAlerts: podInfoTriggeredAlerts, sepString: "\n", printZeroVals: false)
}

extension PodInfoTriggeredAlerts: CustomDebugStringConvertible {
    var debugDescription: String {
        return triggeredAlerts(podInfoTriggeredAlerts: self, sepString: ", ", printZeroVals: true)
    }
}

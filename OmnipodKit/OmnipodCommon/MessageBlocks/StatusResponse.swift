//
//  StatusResponse.swift
//  OmnipodKit
//
//  From OmniBLE/OmnipodCommon/MessageBlocks/StatusResponse.swift
//  Created by Pete Schwamb on 10/23/17.
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import Foundation

struct StatusResponse : MessageBlock {
    let blockType: MessageBlockType = .statusResponse
    let length: UInt8 = 10
    let deliveryStatus: DeliveryStatus
    let podProgressStatus: PodProgressStatus
    let timeActive: TimeInterval
    let reservoirLevel: Double
    let insulinDelivered: Double
    let bolusNotDelivered: Double
    let lastProgrammingMessageSeqNum: UInt8 // updated by pod for 03, 08, $11, $19, $1A, $1C, $1E & $1F command messages
    let alerts: AlertSet

    let data: Data

    init(encodedData: Data) throws {
        if encodedData.count < length {
            throw MessageBlockError.notEnoughData
        }

        data = encodedData.prefix(upTo: Int(length))

        guard let deliveryStatus = DeliveryStatus(rawValue: encodedData[1] >> 4) else {
            throw MessageError.unknownValue(value: encodedData[1] >> 4, typeDescription: "DeliveryStatus")
        }
        self.deliveryStatus = deliveryStatus

        guard let podProgressStatus = PodProgressStatus(rawValue: encodedData[1] & 0xf) else {
            throw MessageError.unknownValue(value: encodedData[1] & 0xf, typeDescription: "PodProgressStatus")
        }
        self.podProgressStatus = podProgressStatus

        let minutes = ((Int(encodedData[7]) & 0x7f) << 6) + (Int(encodedData[8]) >> 2)
        self.timeActive = TimeInterval(minutes: Double(minutes))

        let highInsulinBits = Int(encodedData[2] & 0xf) << 9
        let midInsulinBits = Int(encodedData[3]) << 1
        let lowInsulinBits = Int(encodedData[4] >> 7)
        self.insulinDelivered = Double(highInsulinBits | midInsulinBits | lowInsulinBits) / Pod.pulsesPerUnit

        self.lastProgrammingMessageSeqNum = (encodedData[4] >> 3) & 0xf

        self.bolusNotDelivered = Double((Int(encodedData[4] & 0x3) << 8) | Int(encodedData[5])) / Pod.pulsesPerUnit

        self.alerts = AlertSet(rawValue: ((encodedData[6] & 0x7f) << 1) | (encodedData[7] >> 7))

        self.reservoirLevel = Double((Int(encodedData[8] & 0x3) << 8) + Int(encodedData[9])) / Pod.pulsesPerUnit
    }

    init(
        deliveryStatus: DeliveryStatus,
        podProgressStatus: PodProgressStatus,
        timeActive: TimeInterval,
        reservoirLevel: Double,
        insulinDelivered: Double,
        bolusNotDelivered: Double,
        lastProgrammingMessageSeqNum: UInt8,
        alerts: AlertSet)
    {
        self.deliveryStatus = deliveryStatus
        self.podProgressStatus = podProgressStatus
        self.timeActive = timeActive
        self.reservoirLevel = reservoirLevel
        self.insulinDelivered = insulinDelivered
        self.bolusNotDelivered = bolusNotDelivered
        self.lastProgrammingMessageSeqNum = lastProgrammingMessageSeqNum
        self.alerts = alerts
        self.data = Data()
    }

    // convenience function to create a StatusResponse for a DetailedStatus
    init(detailedStatus: DetailedStatus) {
        self.deliveryStatus = detailedStatus.deliveryStatus
        self.podProgressStatus = detailedStatus.podProgressStatus
        self.timeActive = detailedStatus.timeActive
        self.reservoirLevel = detailedStatus.reservoirLevel
        self.insulinDelivered = detailedStatus.totalInsulinDelivered
        self.bolusNotDelivered = detailedStatus.bolusNotDelivered
        self.lastProgrammingMessageSeqNum = detailedStatus.lastProgrammingMessageSeqNum
        self.alerts = detailedStatus.unacknowledgedAlerts
        self.data = Data()
    }
}

extension StatusResponse: CustomDebugStringConvertible {
    var debugDescription: String {
        return "StatusResponse(deliveryStatus:\(deliveryStatus.description), progressStatus:\(podProgressStatus), timeActive:\(timeActive.timeIntervalStr), reservoirLevel:\(reservoirLevel == Pod.reservoirLevelAboveThresholdMagicNumber ? "50+" : reservoirLevel.twoDecimals), insulinDelivered:\(insulinDelivered.twoDecimals), bolusNotDelivered:\(bolusNotDelivered.twoDecimals), lastProgrammingMessageSeqNum:\(lastProgrammingMessageSeqNum), alerts:\(alerts))"
    }
}


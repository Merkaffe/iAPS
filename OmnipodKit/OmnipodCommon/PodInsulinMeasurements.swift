//
//  PodInsulinMeasurements.swift
//  OmnipodKit
//
//  From OmniBLE/OmnipodCommmon/PodInsulinMeasurements.swift
//  Created by Pete Schwamb on 9/5/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

// XXX still needs be declared public with the current Trio implementation
public struct PodInsulinMeasurements: RawRepresentable, Equatable {
    public typealias RawValue = [String: Any]

    let validTime: Date
    let delivered: Double
    // XXX still needs be declared public with the current Trio implementation
    public let reservoirLevel: Double?

    init(insulinDelivered: Double, reservoirLevel: Double?, validTime: Date) {
        self.validTime = validTime
        self.delivered = insulinDelivered
        self.reservoirLevel = reservoirLevel
    }

    // RawRepresentable
    public init?(rawValue: RawValue) {
        guard
            let validTime = rawValue["validTime"] as? Date,
            let delivered = rawValue["delivered"] as? Double
            else {
                return nil
        }
        self.validTime = validTime
        self.delivered = delivered
        self.reservoirLevel = rawValue["reservoirLevel"] as? Double
    }

    public var rawValue: RawValue {
        var rawValue: RawValue = [
            "validTime": validTime,
            "delivered": delivered
            ]

        if let reservoirLevel = reservoirLevel {
            rawValue["reservoirLevel"] = reservoirLevel
        }

        return rawValue
    }
}

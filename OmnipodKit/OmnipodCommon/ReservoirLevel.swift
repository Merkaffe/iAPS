//
//  ReservoirLevel.swift
//  OmnipodKit
//
//  From OmniBLE/OmnipodCommon/ReservoirLevel.swift
//  Created by Pete Schwamb on 5/31/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation

enum ReservoirLevel: RawRepresentable, Equatable {
    typealias RawValue = Double

    case valid(Double)
    case aboveThreshold

    var percentage: Double {
        switch self {
        case .aboveThreshold:
            return 1
        case .valid(let value):
            // Set 50U as the halfway mark, even though pods can hold 200U.
            return min(1, max(0, value / 100))
        }
    }

    init(rawValue: RawValue) {
        if rawValue > Pod.maximumReservoirReading {
            self = .aboveThreshold
        } else {
            self = .valid(rawValue)
        }
    }

    var rawValue: RawValue {
        switch self {
        case .valid(let value):
            return value
        case .aboveThreshold:
            return Pod.reservoirLevelAboveThresholdMagicNumber
        }
    }
}

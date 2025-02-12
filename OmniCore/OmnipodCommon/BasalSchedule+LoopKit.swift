//
//  BasalSchedule+LoopKit.swift
//  OmniCore
//
//  From OmniBLE/OmnipodCommon/PodCommsSession+LoopKit.swift
//  Created by Pete Schwamb on 9/25/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation
import LoopKit

extension BasalSchedule {
    public init(repeatingScheduleValues: [RepeatingScheduleValue<Double>], zeroBasalRate: Double) {
        self.init(entries: repeatingScheduleValues.map { BasalScheduleEntry(rate: $0.value, startTime: $0.startTime, zeroBasalRate: zeroBasalRate) })
    }
}

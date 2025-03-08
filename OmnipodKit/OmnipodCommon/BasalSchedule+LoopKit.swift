//
//  BasalSchedule+LoopKit.swift
//  OmnipodKit
//
//  From OmniBLE/OmnipodCommon/PodCommsSession+LoopKit.swift
//  Created by Pete Schwamb on 9/25/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation
import LoopKit

extension BasalSchedule {
    init(repeatingScheduleValues: [RepeatingScheduleValue<Double>], podType: PodType) {
        self.init(entries: repeatingScheduleValues.map { BasalScheduleEntry(rate: $0.value, startTime: $0.startTime, podType: podType) })
    }
}

//
//  Ids.swift
//  OmnipodKit
//
//  From OmniBLE/OmniBLE/Bluetooth/Ids.swift
//  Created by Randall Knutson on 8/5/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import Foundation

let POD_ID_NOT_ACTIVATED = Data(hexadecimalString: "FFFFFFFE")!

class Ids {

    static func notActivated() -> Id {
        return Id(POD_ID_NOT_ACTIVATED)
    }

    private let controllerId: Id
    private let currentPodId: Id

    var myId: Id {
        return controllerId
    }

    var podId: Id {
        return currentPodId
    }

    var myIdAddr: UInt32 {
        return controllerId.toUInt32()
    }

    var podIdAddr: UInt32 {
        return currentPodId.toUInt32()
    }

    init(myId: UInt32, podId: UInt32) {
        controllerId = Id.fromUInt32(myId)
        currentPodId = Id.fromUInt32(podId)
    }
}

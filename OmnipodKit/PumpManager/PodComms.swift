//
//  PodComms.swift
//  OmnipodKit
//
//  Based on Omni{BLE,Kit}/PumpManager/PodComms.swift
//  Created by Joe Moran on 1/9/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit
import os.log

protocol PodCommsDelegate: OmniConnectionDelegate {
    func podComms(_ podComms: PodComms, didChange podState: PodState?)
    func podCommsDidEstablishSession(_ podComms: PodComms) // non-RL only
}

class PodComms: CustomDebugStringConvertible {

    var myId: UInt32 = 0
    var podId: UInt32 = 0

    weak var delegate: PodCommsDelegate?

    weak var messageLogger: MessageLogger?

    let log = OSLog(category: "PodComms")

    var podStateLock = NSLock()

    var podState: PodState? {
        didSet {
            if podState != oldValue {
                delegate?.podComms(self, didChange: podState)
            }
        }
    }

    init(podState: PodState?, myId: UInt32 = 0, podId: UInt32 = 0) {
        self.podState = podState
        self.delegate = nil
        self.messageLogger = nil
        self.myId = myId
        self.podId = podId
    }

    func updateInsulinType(_ insulinType: InsulinType) {
        podStateLock.lock()
        podState?.insulinType = insulinType
        podStateLock.unlock()
    }

    func forgetPod() {
        podStateLock.lock()
        podState?.resolveAnyPendingCommandWithUncertainty()
        podState?.finalizeAllDoses()
        podStateLock.unlock()
    }

    func prepForNewPod(myId: UInt32 = 0, podId: UInt32 = 0) {
        self.myId = myId
        self.podId = podId

        podStateLock.lock()
        self.podState = nil
        podStateLock.unlock()
    }

    // runSession() result enum
    enum SessionRunResult {
        case success(session: PodCommsSession)
        case failure(PodCommsError)
    }

    // MARK: - CustomDebugStringConvertible

    var debugDescription: String {
        var ret = "## PodComms\n"
        if myId != 0 || podId != 0 {
            ret += "* myId: \(String(format: "%08X", myId))\n* podId: \(String(format: "%08X", podId))\n"
        }
        ret += "* delegate: \(String(describing: delegate != nil))\n"
        return ret
    }
}

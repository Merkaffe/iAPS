//
//  MessageTransport.swift
//  OmnipodKit
//
//  Derived from OmniBLE/OmniBLE/PumpManager/MessageTransport.swift
//  Derived from OmniKit/MessageTransport/MessageTransport.swift
//  Created by Joseph Moran on 2/4/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import Foundation
import os.log

protocol MessageTransportState: Equatable, RawRepresentable {

    var messageNumber: Int { get }

    init()

    init?(rawValue: RawValue)

    // Each MessageTransportState implementation also has an init() taking transport specific arguments
}

protocol MessageTransportDelegate: AnyObject {
    func messageTransport(_ messageTransport: MessageTransport, didUpdate state: any MessageTransportState)
}

protocol MessageTransport {
    var delegate: MessageTransportDelegate? { get set }

    var messageNumber: Int { get }

    func sendMessage(_ message: Message) throws -> Message

    /// Asserts that the caller is currently on the session's queue
    func assertOnSessionQueue()
}

// Unsuccessful equality func as the messageTransportState PodState var breaks its protocol Equatable conformance.
// QQQ Why isn't this func sufficient for the PodState Equatable protocol conformance???
// QQQ Is it possible to rewrite this so that PodState won't need to have its own equality checker func?
// QQQ Would it be better to use separate {ble,eros}MessageTransportState and {ble,eros}MessageTransport
// vars instead of trying to use {M,m}essageTransportState and {M,m}essageTransport protocols and vars.
extension MessageTransportState {
    static func == (lhs: any MessageTransportState, rhs: any MessageTransportState) -> Bool {
        let lhsBleMessageTransportState = lhs as? BleMessageTransportState
        let rhsBleMessageTransportState = rhs as? BleMessageTransportState
        let lhsErosMessageTransportState = lhs as? ErosMessageTransportState
        let rhsErosMessageTransportState = rhs as? ErosMessageTransportState
        guard
            lhsBleMessageTransportState == rhsBleMessageTransportState,
            lhsErosMessageTransportState == rhsErosMessageTransportState
        else {
            return false
        }
        return true
    }
}

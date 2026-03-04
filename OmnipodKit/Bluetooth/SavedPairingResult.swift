//
//  SavedPairingResult.swift
//  OmnipodKit
//
//  Debug helper: stores pairing details from a previous successful pairing
//  so we can skip LTK exchange and reconnect directly to a pod for testing.
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import Foundation

struct SavedPairingResult {
    /// Human-readable label for logging
    let name: String
    /// CoreBluetooth peripheral UUID
    let bleUUID: String?
    /// 16-byte LTK as hex string
    let ltk: String?
    /// Pod address (UInt32)
    let podAddress: UInt32
    /// TWi message sequence number at end of pairing
    let msgSeq: UInt8
    /// EAP-AKA sequence number for next session (1 = first session, 2+ = re-establishment)
    let eapSeq: Int

    // MARK: - Saved sessions

}

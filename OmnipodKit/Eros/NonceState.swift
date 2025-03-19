//
//  NonceState.swift
//  OmnipodKit
//
//  Taken from on OmniKit/PumpManager/PodState.swift
//  Created by Joe Moran on 1/9/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit

// Eros specific 32-bit message nonce
struct NonceState: RawRepresentable, Equatable {
    typealias RawValue = [String: Any]

    var table: [UInt32]
    var idx: UInt8

    init(lot: UInt32 = 0, tid: UInt32 = 0, seed: UInt16 = 0) {
        table = Array(repeating: UInt32(0), count: 2 + 16)
        table[0] = (lot & 0xFFFF) &+ (lot >> 16) &+ 0x55543DC3
        table[1] = (tid & 0xFFFF) &+ (tid >> 16) &+ 0xAAAAE44E

        idx = 0
    
        table[0] += UInt32((seed & 0x00ff))
        table[1] += UInt32((seed & 0xff00) >> 8)
    
        for i in 0..<16 {
            table[2 + i] = generateEntry()
        }
        
        idx = UInt8((table[0] + table[1]) & 0x0F)
    }

    mutating func generateEntry() -> UInt32 {
        table[0] = (table[0] >> 16) &+ ((table[0] & 0xFFFF) &* 0x5D7F)
        table[1] = (table[1] >> 16) &+ ((table[1] & 0xFFFF) &* 0x8CA0)
        return table[1] &+ ((table[0] & 0xFFFF) << 16)
    }

    mutating func advanceToNextNonce() {
        let nonce = currentNonce
        table[Int(2 + idx)] = generateEntry()
        idx = UInt8(nonce & 0x0F)
    }

    var currentNonce: UInt32 {
        return table[Int(2 + idx)]
    }

    // RawRepresentable
    init?(rawValue: RawValue) {
        guard
            let table = rawValue["table"] as? [UInt32],
            let idx = rawValue["idx"] as? UInt8
            else {
                return nil
        }
        self.table = table
        self.idx = idx
    }

    var rawValue: RawValue {
        let rawValue: RawValue = [
            "table": table,
            "idx": idx,
        ]
        return rawValue
    }
}

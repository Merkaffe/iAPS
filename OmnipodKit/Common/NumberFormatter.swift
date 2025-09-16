//
//  NumberFormatter.swift
//  OmnipodKit
//
//  From OmniBLE/Common/NumberFormatter.swift
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import Foundation

extension NumberFormatter {
    func decibleString(from decibles: Int?) -> String? {
        if let decibles = decibles, let formatted = string(from: NSNumber(value: decibles)) {
            return String(format: "%@ dB", formatted)
        } else {
            return nil
        }
    }

    func string(from number: Double) -> String? {
        return string(from: NSNumber(value: number))
    }
}

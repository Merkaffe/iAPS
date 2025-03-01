//
//  Omni.swift
//  OmnipodKit
//
//  Created by Joseph Moran on 1/28/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import Foundation
import OSLog

public class Omni {
    var manager: PeripheralManager
    var advertisement: PodAdvertisement?

    private let log = OSLog(category: "Omni")

    init(peripheralManager: PeripheralManager, advertisement: PodAdvertisement?) {
        self.manager = peripheralManager        
        self.advertisement = advertisement
    }
}

extension Omni: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "Omni - advertisement: \(String(describing: advertisement))"
    }
}

//
//  OmniCorePlugin.swift
//  OmniCore
//
//  Created by Joe Moran on 01/05/25.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKitUI
import OmniCore
import os.log

class OmniCorePlugin: NSObject, PumpManagerUIPlugin {
    private let log = OSLog(__subsystem: "OmniCorePlugin", category: "com.loopkit.omnicore")

    public var pumpManagerType: PumpManagerUI.Type? {
        return OmniPumpManager.self
    }

    public var cgmManagerType: CGMManagerUI.Type? {
        return nil
    }

    override init() {
        super.init()
        log.default("OmniCorePlugin Instantiated")
    }
}

//
//  DeliveryUncertaintyRecoveryViewModel.swift
//  OmnipodKit
//
//  Based on OmniBLE/PumpManagerUI/ViewModels/DeliveryUncertaintyRecoveryViewModel.swift
//  Created by Pete Schwamb on 8/25/20.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit


class DeliveryUncertaintyRecoveryViewModel: PumpManagerStatusObserver {
    
    let appName: String
    let uncertaintyStartedAt: Date
    let possibleRecoveryActions: String
    
    var onDismiss: (() -> Void)?
    var didRecover: (() -> Void)?
    var onDeactivate: (() -> Void)?
    
    private var finished = false
    
    init(appName: String, uncertaintyStartedAt: Date, usesRileyLink: Bool) {
        self.appName = appName
        self.uncertaintyStartedAt = uncertaintyStartedAt
        if usesRileyLink {
            self.possibleRecoveryActions = LocalizedString("You can use manual commands, toggle phone Bluetooth off and on, toggle RileyLink connections, power the RileyLink device off and on, and/or quit and restart the app.", comment: "delivery uncertainty recovery suggestion when using a RileyLink")
        } else {
            self.possibleRecoveryActions = LocalizedString("You can use manual commands, toggle phone Bluetooth off and on, and/or quit and restart the app.", comment: "delivery uncertainly recovery suggestion when not using a RileyLink")
        }
    }

    func pumpManager(_ pumpManager: PumpManager, didUpdate status: PumpManagerStatus, oldStatus: PumpManagerStatus) {
        if !finished {
            if !status.deliveryIsUncertain {
                didRecover?()
            }
        }
    }
    
    func podDeactivationChosen() {
        finished = true
        self.onDeactivate?()
    }
}

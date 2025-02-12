//
//  OmniPumpManagerError.swift
//  OmniCore
//
//  Based on Omni{BLE,Kit}/PumpManager/OmniBLEPumpManager.swift
//  Created by Joe Moran on 12/4/24.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import Foundation

public enum OmniPumpManagerError: Error {
    case noPodPaired
    case podAlreadyPaired
    case insulinTypeNotConfigured
    case notReadyForCannulaInsertion
    case invalidSetting
    case podTypeNotConfigured
    case communication(Error)
    case state(Error)
    //case notImplemented(String) // XXX temp
}

extension OmniPumpManagerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .noPodPaired:
            return LocalizedString("No pod paired", comment: "Error message shown when no pod is paired")
        case .podAlreadyPaired:
            return LocalizedString("Pod already paired", comment: "Error message shown when user cannot pair because pod is already paired")
        case .insulinTypeNotConfigured:
            return LocalizedString("Insulin type not configured", comment: "Error description for insulin type not configured")
        case .notReadyForCannulaInsertion:
            return LocalizedString("Pod is not in a state ready for cannula insertion.", comment: "Error message when cannula insertion fails because the pod is in an unexpected state")
        case .invalidSetting:
            return LocalizedString("Invalid Setting", comment: "Error description for invalid setting")
        case .podTypeNotConfigured:
            return LocalizedString("Pod type not configured.", comment: "Error message when pod type is not configured")
        case .communication(let error):
            if let error = error as? LocalizedError {
                return error.errorDescription
            } else {
                return String(describing: error)
            }
        case .state(let error):
            if let error = error as? LocalizedError {
                return error.errorDescription
            } else {
                return String(describing: error)
            }
        //case .notImplemented(let op): // XXX temp
        //    if op.isEmpty {
        //        return "Operation not implemented"
        //    }
        //    return String(format: "%@ not implemented", op)
        }
    }

    public var failureReason: String? {
        return nil
    }

    public var recoverySuggestion: String? {
        switch self {
        case .noPodPaired:
            return LocalizedString("Please pair a new pod", comment: "Recovery suggestion shown when no pod is paired")
        default:
            return nil
        }
    }
}

//
//  O5RegistrationData.swift
//  OmnipodKit
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import Foundation
import CryptoSwift


struct O5RegistrationData {
    private static var _registry: [UInt32: O5RegistrationData] = [:]
    private static let lock = NSLock()

    static func install(_ value: O5RegistrationData) {
        lock.lock()
        defer { lock.unlock() }
        _registry[value.controllerId] = value
    }

    static func get(_ controllerId: UInt32) -> O5RegistrationData? {
        lock.lock()
        defer { lock.unlock() }
        return _registry[controllerId]
    }

    static func getRandom() -> O5RegistrationData? {
        lock.lock()
        defer { lock.unlock() }
        switch _registry.count {
        case 0:
            return nil
        case 1:
            return _registry.values.first!
        default:
            let randomIndex = Int.random(in: 0..<_registry.count)
            return Array(_registry.values)[randomIndex]
        }
    }

    static var allValues: [O5RegistrationData] {
        lock.lock()
        defer { lock.unlock() }
        return Array(_registry.values)
    }

    static var isEmpty: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _registry.isEmpty
    }

    // MARK: - Identity

    /// Becomes the 4-byte controller ID.
    let controllerId: UInt32

    // MARK: - Secondary Key (main signing key, SPS2.1 + certain pod commands)

    let secondaryKeyScalarHex: String
    let secondaryPublicKeyHex: String

    // MARK: - Certificate Chain

    let intermediateCACertDERBase64: String
    let tlsCertificateDERBase64: String


    // MARK: - Convenience

    var secondaryKeyScalar: Data { Data(hex: secondaryKeyScalarHex) }
    var secondaryPublicKeyRaw: Data { Data(hex: secondaryPublicKeyHex) }

    var tlsCertificateDER: Data? { Data(base64Encoded: tlsCertificateDERBase64) }
    var intermediateCACertDER: Data? { Data(base64Encoded: intermediateCACertDERBase64) }

    var controllerIdData: Data {
        var value = controllerId.bigEndian
        return Data(bytes: &value, count: 4)
    }
}

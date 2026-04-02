//
//  O5RegistrationData.swift
//  OmnipodKit
//
//  Extracted O5 registration data — keys, certificates, and PDM identity.
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
        _registry[value.pdmid] = value
    }

    static func get(_ pdmid: UInt32) -> O5RegistrationData? {
        lock.lock()
        defer { lock.unlock() }
        return _registry[pdmid]
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

    /// PDM ID from the TLS certificate SAN — becomes the 4-byte controller ID.
    let pdmid: UInt32

    // MARK: - Secondary Key (main signing key, SPS2.1 + pod commands)

    /// Secondary EC P-256 private key scalar (32 bytes hex).
    let secondaryKeyScalarHex: String

    /// Secondary key public key (64 bytes hex, x || y, no 04 prefix).
    let secondaryPublicKeyHex: String

    // MARK: - Certificate Chain (downloaded via register/download)

    /// Intermediate CA certificate (issued by Root CA certificate, DER base64).
    /// Sent as encrypted payload during SPS2.1
    let intermediateCACertDERBase64: String

    /// TLS Certificate (issued by Intermediate CA certificate, DER base64).
    /// Its public key matches the secondary signing key.
    /// Sent as encrypted payload during SPS2
    let tlsCertificateDERBase64: String


    // MARK: - Convenience

    var secondaryKeyScalar: Data { Data(hex: secondaryKeyScalarHex) }
    var secondaryPublicKeyRaw: Data { Data(hex: secondaryPublicKeyHex) }

    var tlsCertificateDER: Data? { Data(base64Encoded: tlsCertificateDERBase64) }
    var intermediateCACertDER: Data? { Data(base64Encoded: intermediateCACertDERBase64) }

    var controllerID: Data {
        var value = pdmid.bigEndian
        return Data(bytes: &value, count: 4)
    }
}

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

    /// PDM ID extension from the TLS certificate SAN.
    let pdmidExtension: UInt32

    /// Command capabilities from the TLS certificate SAN (base64-encoded).
    let commandsBase64: String

    // MARK: - Secondary Key (main signing key, SPS2.1 + pod commands)

    /// Secondary EC P-256 private key scalar (32 bytes hex).
    let secondaryKeyScalarHex: String

    /// Secondary key public key (64 bytes hex, x || y, no 04 prefix).
    let secondaryPublicKeyHex: String

    // MARK: - Primary Key (certificate identity, sent to pod during SPS2.1)

    /// Primary EC P-256 private key scalar (32 bytes hex).
    let primaryKeyScalarHex: String?

    /// Primary key public key (64 bytes hex, x || y, no 04 prefix).
    let primaryPublicKeyHex: String?

    /// Primary key self-signed X.509 certificate (DER, base64). Sent to pod during SPS2.1.
    let primaryCertificateDERBase64: String?

    // MARK: - Certificate Chain (downloaded via register/download)

    /// Root CA certificate (self-signed, DER base64).
    let rootCACertDERBase64: String

    /// Intermediate CA certificate (issued by Root CA certificate, DER base64).
    let intermediateCACertDERBase64: String

    /// TLS Certificate (issued by Intermediate CA certificate, DER base64).
    /// Its public key matches the secondary signing key.
    let tlsCertificateDERBase64: String

    // MARK: - Certificate Chain Public Keys (raw, 64 bytes hex, x || y)

    let rootCAPublicKeyHex: String
    let intermediateCAPublicKeyHex: String

    // MARK: - Secondary Attestation Chain

    let secondaryAttestationChainDERBase64: [String]

    // MARK: - Registration Payload (from register/complete)

    /// Binary payload written to pod during setPodUid. Contains secondary public key + commands.
    let registrationPayloadBase64: String?

    // MARK: - Convenience

    var secondaryKeyScalar: Data { Data(hex: secondaryKeyScalarHex) }
    var secondaryPublicKeyRaw: Data { Data(hex: secondaryPublicKeyHex) }

    var tlsCertificateDER: Data? { Data(base64Encoded: tlsCertificateDERBase64) }
    var intermediateCACertDER: Data? { Data(base64Encoded: intermediateCACertDERBase64) }

    /// Registration payload from register/complete (written to pod during setPodUid).
    var registrationPayload: Data? { registrationPayloadBase64.flatMap { Data(base64Encoded: $0) } }

    var controllerID: Data {
        var value = pdmid.bigEndian
        return Data(bytes: &value, count: 4)
    }
}

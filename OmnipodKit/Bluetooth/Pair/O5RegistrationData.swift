//
//  O5RegistrationData.swift
//  OmnipodKit
//
//  Extracted O5 registration data — keys, certificates, and PDM identity.
//  Swap the `active` instance to use a different registration set.
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import Foundation
import CryptoSwift

/// All material from a single O5 device registration.
/// Create additional instances for different registrations and assign to `O5RegistrationData.active`.
struct O5RegistrationData {

    // MARK: - PDM Identity (from TLS Certificate SAN)

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

    /// Primary EC P-256 private key scalar (32 bytes hex). May be nil if not extracted.
    let primaryKeyScalarHex: String?

    /// Primary key public key (64 bytes hex, x || y, no 04 prefix). May be nil.
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

    // MARK: - Secondary Attestation Chain (Android Keystore, DER base64)

    /// cert[0] — Leaf (device key), cert[1] — intermediate,
    /// cert[2] — HW intermediate (P-384), cert[3] — Google HW root (RSA-4096)
    let secondaryAttestationChainDERBase64: [String]

    // MARK: - Registration Payload (from register/complete)

    /// Binary payload written to pod during setPodUid. Contains secondary public key + commands.
    let registrationPayloadBase64: String?

    // MARK: - Convenience

    var secondaryKeyScalar: Data { Data(hex: secondaryKeyScalarHex) }
    var secondaryPublicKeyRaw: Data { Data(hex: secondaryPublicKeyHex) }
    var primaryKeyScalar: Data? { primaryKeyScalarHex.map { Data(hex: $0) } }
    var primaryPublicKeyRaw: Data? { primaryPublicKeyHex.map { Data(hex: $0) } }
    var primaryCertificateDER: Data? { primaryCertificateDERBase64.flatMap { Data(base64Encoded: $0) } }
    var rootCAPublicKeyRaw: Data { Data(hex: rootCAPublicKeyHex) }
    var intermediateCAPublicKeyRaw: Data { Data(hex: intermediateCAPublicKeyHex) }
    var tlsCertificateDER: Data? { Data(base64Encoded: tlsCertificateDERBase64) }
    var rootCACertDER: Data? { Data(base64Encoded: rootCACertDERBase64) }
    var intermediateCACertDER: Data? { Data(base64Encoded: intermediateCACertDERBase64) }

    /// Registration payload from register/complete (written to pod during setPodUid).
    var registrationPayload: Data? { registrationPayloadBase64.flatMap { Data(base64Encoded: $0) } }

    var controllerID: Data {
        var value = pdmid.bigEndian
        return Data(bytes: &value, count: 4)
    }
}

// MARK: - Active Registration

extension O5RegistrationData {

    /// The currently active registration data set.
    /// Change this to use a different registration.
    static var active: O5RegistrationData = .ts_***REMOVED***
}

// MARK: - Registration (pdmid ***REMOVED***, Feb 2026)
//
// TLS certificate issued 2026-02-14 by Intermediate CA certificate.
//

extension O5RegistrationData {

    static let ts_***REMOVED*** = O5RegistrationData(

        // PDM Identity
        pdmid: ***REMOVED***,
        pdmidExtension: ***REMOVED***,
        commandsBase64: "***REMOVED***",

        // Secondary Key
        secondaryKeyScalarHex:
            "***REMOVED***",
        secondaryPublicKeyHex:
            "***REMOVED***" +
            "***REMOVED***",

        // Primary Key
        primaryKeyScalarHex:
            "***REMOVED***",
        primaryPublicKeyHex:
            "***REMOVED***" +
            "***REMOVED***",
        primaryCertificateDERBase64:
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***",

        // Certificate Chain (KEYS/*.pem)
        rootCACertDERBase64:
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***",
        intermediateCACertDERBase64:
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***",
        tlsCertificateDERBase64:
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***",

        // Chain Public Keys (raw, hex, x || y, no 04 prefix)
        rootCAPublicKeyHex:
            "***REMOVED***" +
            "***REMOVED***",
        intermediateCAPublicKeyHex:
            "***REMOVED***" +
            "***REMOVED***",
        // Secondary Attestation Chain
        secondaryAttestationChainDERBase64: [
            // cert_0 — leaf (contains secondary public key 5b04057e...)
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***",
            // cert_1 — intermediate
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***",
            // cert_2 — HW intermediate (EC P-384)
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***",
            // cert_3 — Google HW Attestation Root (RSA-4096)
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***",
        ],

        // Registration Payload from register/complete for pdmid ***REMOVED***.
        // Structure (163 bytes): length(4) + flags(4) + id(3) + sep(1) + type(1) + keysize=65(1)
        //   + controller_id(4) + secondary_pubkey(64) + commands(11) + encrypted_data(65)
        // Verified: controller_id = ***REMOVED*** (***REMOVED***), secondary key = e3c48e61...
        registrationPayloadBase64:
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***"
    )
}

// MARK: - Registration (pdmid ***REMOVED***, Feb 2026 — SUCCESSFUL PAIRING)
//
// TLS certificate issued 2026-02-15 by Intermediate CA certificate.
//

extension O5RegistrationData {

    static let ts_***REMOVED*** = O5RegistrationData(

        // PDM Identity (from TLS certificate SAN)
        pdmid: ***REMOVED***,
        pdmidExtension: ***REMOVED***,
        commandsBase64: "***REMOVED***",

        // Secondary Key
        secondaryKeyScalarHex:
            "***REMOVED***",
        secondaryPublicKeyHex:
            "***REMOVED***" +
            "***REMOVED***",

        // Primary Key
        primaryKeyScalarHex:
            "***REMOVED***",
        primaryPublicKeyHex:
            "***REMOVED***" +
            "***REMOVED***",
        primaryCertificateDERBase64:
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***",

        // Certificate Chain (same CAs as all registrations)
        rootCACertDERBase64:
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***",
        intermediateCACertDERBase64:
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***",
        tlsCertificateDERBase64:
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***",

        // Chain Public Keys (same across all registrations)
        rootCAPublicKeyHex:
            "***REMOVED***" +
            "***REMOVED***",
        intermediateCAPublicKeyHex:
            "***REMOVED***" +
            "***REMOVED***",

        // Secondary Attestation Chain
        secondaryAttestationChainDERBase64: [
            // cert_0 — leaf (contains secondary public key 5b04057e...)
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***",
            // cert_1 — intermediate
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "Pz***REMOVED***",
            // cert_2 — HW intermediate (EC P-384, same across registrations)
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***",
            // cert_3 — Google HW Attestation Root (RSA-4096, same across registrations)
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***",
        ],

        // Registration Payload from register/complete for pdmid ***REMOVED***.
        // Verified: controller_id = ***REMOVED***, secondary key = 5b04057e...
        registrationPayloadBase64:
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***" +
            "***REMOVED***"
    )
}

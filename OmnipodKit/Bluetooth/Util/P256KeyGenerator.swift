//
//  P256KeyGenerator.swift
//  OmnipodKit
//
//  From OmniBLE/OmniBLE/Bluetooth/Util/P256KeyGenerator.swift
//  Created by Brian Wieder on 7/4/25.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//
import CryptoKit
import Foundation

struct P256KeyGenerator: PrivateKeyGenerator {
    func generatePrivateKey() -> Data {
        let key = P256.KeyAgreement.PrivateKey()
        return key.rawRepresentation
    }
    func publicFromPrivate(_ privateKey: Data) throws -> Data{
        let key = try P256.KeyAgreement.PrivateKey(rawRepresentation: privateKey)
        return key.publicKey.rawRepresentation
    }
    func computeSharedSecret(_ privateKey: Data, _ publicKey: Data) throws -> Data {
        let priv = try P256.KeyAgreement.PrivateKey(rawRepresentation: privateKey)
        let pub = try P256.KeyAgreement.PublicKey(rawRepresentation: publicKey)
        let secret = try priv.sharedSecretFromKeyAgreement(with: pub)
        return secret.withUnsafeBytes({ return Data($0)})
    }
}

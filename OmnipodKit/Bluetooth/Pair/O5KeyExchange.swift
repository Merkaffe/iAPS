//
//  O5KeyExchange.swift
//  OmnipodKit
//
//  From OmniBLE/OmniBLE/Bluetooth/Pair/KeyExchange.swift
//  Created by Joe Moran on 3/25/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import Foundation
import CryptoSwift

class O5KeyExchange {
    static let CMAC_SIZE = 16

    static let PUBLIC_KEY_SIZE = 64
    static let NONCE_SIZE = 16

    private let INTERMEDIARY_KEY_MAGIC_STRING = "TWIt".data(using: .utf8)
    private let PDM_CONF_MAGIC_PREFIX = "KC_2_U".data(using: .utf8)
    private let POD_CONF_MAGIC_PREFIX = "KC_2_V".data(using: .utf8)

    let pdmNonce: Data
    let pdmPrivate: Data
    let pdmPublic: Data
    var podPublic: Data
    var podNonce: Data
    var podConf: Data
    var pdmConf: Data
    var ltk: Data
    var sharedSecret: Data?

    private let keyGenerator: PrivateKeyGenerator
    let randomByteGenerator: RandomByteGenerator

    init(_ keyGenerator: PrivateKeyGenerator, _ randomByteGenerator: RandomByteGenerator) throws {
        self.keyGenerator = keyGenerator
        self.randomByteGenerator = randomByteGenerator

        pdmNonce = randomByteGenerator.nextBytes(length: KeyExchange.NONCE_SIZE)
        pdmPrivate = keyGenerator.generatePrivateKey()
        pdmPublic = try keyGenerator.publicFromPrivate(pdmPrivate)

        podPublic = Data(capacity: KeyExchange.PUBLIC_KEY_SIZE)
        podNonce = Data(capacity: KeyExchange.NONCE_SIZE)

        podConf = Data(capacity: KeyExchange.CMAC_SIZE)
        pdmConf = Data(capacity: KeyExchange.CMAC_SIZE)

        ltk = Data(capacity: KeyExchange.CMAC_SIZE)
    }

    func o5updatePodPublicData(_ payload: Data) throws {
        if (payload.count != O5KeyExchange.PUBLIC_KEY_SIZE + O5KeyExchange.NONCE_SIZE) {
            throw PodProtocolError.messageIOException("Invalid payload size")
        }
        podPublic = payload.subdata(in: 0..<O5KeyExchange.PUBLIC_KEY_SIZE)
        podNonce = payload.subdata(in: O5KeyExchange.PUBLIC_KEY_SIZE..<O5KeyExchange.PUBLIC_KEY_SIZE + O5KeyExchange.NONCE_SIZE)
        try o5generateKeys()
    }

    func o5validatePodConf(_ payload: Data) throws {
        if (podConf != payload) {
            throw PodProtocolError.messageIOException("Invalid podConf value received")
        }
    }

    private func o5generateKeys() throws {
        sharedSecret = try keyGenerator.computeSharedSecret(pdmPrivate, podPublic)

        let firstKey = podPublic.subdata(in: podPublic.count - 4..<podPublic.count) +
            pdmPublic.subdata(in: pdmPublic.count - 4..<pdmPublic.count) +
            podNonce.subdata(in: podNonce.count - 4..<podNonce.count) +
            pdmNonce.subdata(in: pdmNonce.count - 4..<pdmNonce.count)

        guard let sharedSecret = self.sharedSecret else {
            throw PodProtocolError.pairingException("Shared Secret is nil, even though we just created it above, this should never happen")
        }
        let intermediateKey = try o5aesCmac(firstKey, sharedSecret)

        let ltkData = Data([0x02]) +
            INTERMEDIARY_KEY_MAGIC_STRING! +
            podNonce +
            pdmNonce +
            Data([0x00, 0x01])

        ltk = try o5aesCmac(intermediateKey, ltkData)

        let confData = Data([0x01]) +
            INTERMEDIARY_KEY_MAGIC_STRING! +
            podNonce +
            pdmNonce +
            Data([0x00, 0x01])
        let confKey = try o5aesCmac(intermediateKey, confData)

        let pdmConfData = PDM_CONF_MAGIC_PREFIX! +
            pdmNonce +
            podNonce
        pdmConf = try o5aesCmac(confKey, pdmConfData)

        let podConfData = POD_CONF_MAGIC_PREFIX! +
            podNonce +
            pdmNonce
        podConf = try o5aesCmac(confKey, podConfData)
    }

    private func o5aesCmac(_ key: Data, _ data: Data) throws -> Data {
        let mac = try CMAC(key: key.bytes)
        return try Data(mac.authenticate(data.bytes))
    }
}

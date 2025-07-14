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

enum Direction {
    case write
    case read
}

class O5KeyExchange {
    static let CMAC_SIZE = 16

    static let PUBLIC_KEY_SIZE = 64
    static let NONCE_SIZE = 16

    private let INTERMEDIARY_KEY_MAGIC_STRING = "TWIt".data(using: .utf8)
    private let PDM_CONF_MAGIC_PREFIX = "KC_2_U".data(using: .utf8)
    private let POD_CONF_MAGIC_PREFIX = "KC_2_V".data(using: .utf8)

    var pdmNonce: Data
    let pdmPrivate: Data
    let pdmPublic: Data
    var podPublic: Data
    var podNonce: Data
    var conf: Data
    var ltk: Data

    private let keyGenerator: PrivateKeyGenerator
    let randomByteGenerator: RandomByteGenerator

    init(_ keyGenerator: PrivateKeyGenerator, _ randomByteGenerator: RandomByteGenerator) throws {
        self.keyGenerator = keyGenerator
        self.randomByteGenerator = randomByteGenerator

        pdmNonce = randomByteGenerator.nextBytes(length: O5KeyExchange.NONCE_SIZE)
        pdmPrivate = keyGenerator.generatePrivateKey()
        pdmPublic = try keyGenerator.publicFromPrivate(pdmPrivate)

        podPublic = Data(capacity: O5KeyExchange.PUBLIC_KEY_SIZE)
        podNonce = Data(capacity: O5KeyExchange.NONCE_SIZE)

        conf = Data(capacity: O5KeyExchange.CMAC_SIZE)

        ltk = Data(capacity: O5KeyExchange.CMAC_SIZE)
    }

    func o5updatePodPublicData(_ payload: Data) throws {
        if (payload.count != O5KeyExchange.PUBLIC_KEY_SIZE + O5KeyExchange.NONCE_SIZE) {
            throw PodProtocolError.messageIOException("Invalid payload size")
        }
        podPublic = payload.subdata(in: 0..<O5KeyExchange.PUBLIC_KEY_SIZE)
        podNonce = payload.subdata(in: O5KeyExchange.PUBLIC_KEY_SIZE..<O5KeyExchange.PUBLIC_KEY_SIZE + O5KeyExchange.NONCE_SIZE)
        try o5generateKeys()
    }

    private func o5generateKeys() throws {
        let sharedSecret = try keyGenerator.computeSharedSecret(pdmPrivate, podPublic)
        var data = Data()
        data.append(withUnsafeBytes(of: UInt64(O5LTKExchanger.FIRMWARE_ID.count).bigEndian, {Data($0)}))
        data.append(O5LTKExchanger.FIRMWARE_ID)
        let controllerID = Data([0x00, 0x00, 0x00, 0x00])
        data.append(withUnsafeBytes(of: UInt64(controllerID.count).bigEndian, {Data($0)}))
        data.append(controllerID)
        data.append(withUnsafeBytes(of: UInt64(self.pdmPublic.count).bigEndian, {Data($0)}))
        data.append(self.pdmPublic)
        data.append(withUnsafeBytes(of: UInt64(self.podPublic.count).bigEndian, {Data($0)}))
        data.append(self.podPublic)
        data.append(withUnsafeBytes(of: UInt64(sharedSecret.count).bigEndian, {Data($0)}))
        data.append(sharedSecret)
        let derivedKey = data.sha256()
        self.conf = derivedKey.subdata(in: 0..<16)
        self.ltk = derivedKey.subdata(in: 16..<derivedKey.count)
    }
    
    public func getSPSNonce(direction: Direction) -> Data {
        var nonce = Data()
        switch direction {
        case .write:
            nonce.append(contentsOf: [0x01])
            nonce.append(pdmNonce.subdata(in: 0..<6))
            nonce.append(podNonce.subdata(in: 0..<6))
            break
        case .read:
            nonce.append(contentsOf: [0x02])
            nonce.append(podNonce.subdata(in: 0..<6))
            nonce.append(pdmNonce.subdata(in: 0..<6))
            break
        }
        return nonce
    }
    
    public func incrementNonce(direction: Direction) {
        switch direction {
        case .write:
            self.pdmNonce = Data(pdmNonce.to(UInt64.self) + 1)
            break
        case .read:
            self.podNonce = Data(podNonce.to(UInt64.self) + 1)
            break
        }
    }

    private func o5aesCmac(_ key: Data, _ data: Data) throws -> Data {
        let mac = try CMAC(key: key.bytes)
        return try Data(mac.authenticate(data.bytes))
    }
}

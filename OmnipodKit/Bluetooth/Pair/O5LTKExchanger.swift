//
//  O5LTKExchanger.swift
//  OmnipodKit
//
//  From OmniBLE/OmniBLE/Bluetooth/Pair/LTKExchanger.swift
//  Created by Joe Moran on 3/25/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//
import Foundation
import CryptoSwift
import CryptoKit
import os.log

class O5LTKExchanger {
    // DEADFACE is replaced by 32-bit PDM ID, for DIY it is myId
    // (serial # << 2) (e.g., for Joe PDM SN #000012722=0x31B2<<2 = 0x0000C6C8
    static let SET_UNIQUE_ID_HEX_COMMAND: Data = Data(hex: "060104DEADFACE")
    static let FIRMWARE_ID: Data = Data(hex: "9b0ab96a76f4")

    static private let SP1 = "SP1="
    static private let SP2 = ",SP2="
    static private let SPS0 = "SPS0="
    static private let SPS1  = "SPS1="
    static private let SPS2 = "SPS2="
    static private let SPS2_1 = "SPS2.1="
    static private let SP0GP0 = "SP0,GP0"
    static private let P0 = "P0="
    static private let UNKNOWN_P0_PAYLOAD = Data([0xa5])

    private let manager: PeripheralManager
    private let ids: Ids
    private let podAddress = Ids.notActivated()
    private let keyExchange = try! O5KeyExchange(P256KeyGenerator(), OmniRandomByteGenerator())
    private var seq: UInt8 = 1

    private let log = OSLog(category: "O5LTKExchanger")

    init(manager: PeripheralManager, ids: Ids) {
        self.manager = manager
        self.ids = ids
    }

    func o5negotiateLTK() throws -> PairResult {

        log.debug("Sending sp1sp2")
        let sp1sp2 = PairMessage(
            sequenceNumber: seq,
            source: ids.myId,
            destination: podAddress,
            keys: [O5LTKExchanger.SP1, O5LTKExchanger.SP2],
            payloads: [ids.podId.address, o5sp2(podId: ids.podId)] // 4-byte and 11-byte payloads
        )
        try o5throwOnSendError(sp1sp2.message, O5LTKExchanger.SP1 + O5LTKExchanger.SP2)

        seq += 1
        log.debug("Sending sps0")
        let sps0 = PairMessage(
            sequenceNumber: seq,
            source: ids.myId,
            destination: podAddress,
            keys: [O5LTKExchanger.SPS0],
            payloads: [o5sps0()] // fixed 5-byte payload
        )
        try o5throwOnSendError(sps0.message, O5LTKExchanger.SPS0)

        log.debug("Reading sps0")
        guard let podSps0 = try manager.readMessagePacket(doRTS: false) else {
            throw PodProtocolError.pairingException("Could not read SPS0")
        }
        try validateO5sps0(podSps0)

        // send and receive 80-byte SPS1

        log.debug("Sending sps1")
        seq += 1
        let sps1 = PairMessage(
            sequenceNumber: seq,
            source: ids.myId,
            destination: podAddress,
            keys: [O5LTKExchanger.SPS1],
            payloads: [keyExchange.pdmPublic + keyExchange.pdmNonce]
        )
        try o5throwOnSendError(sps1.message, O5LTKExchanger.SPS1)

        guard let podSps1 = try manager.readMessagePacket(doRTS: false) else {
            throw PodProtocolError.pairingException("Could not read SPS1")
        }
        try o5validatePodSps1(podSps1)

        // send 642 byte SPS2.1 and receive 641 byte SPS2.1
        log.debug("Sending sps2.1")
        seq += 1
        let sps2_1 = try PairMessage(
            sequenceNumber: seq, source: ids.myId, destination: podAddress, keys: [O5LTKExchanger.SPS2_1], payloads: [
                o5sps2_1()
            ]
        )
        try o5throwOnSendError(sps2_1.message, O5LTKExchanger.SPS2_1)
        guard let podSPS2_1 = try manager.readMessagePacket(doRTS: false) else {
            throw PodProtocolError.pairingException("Could not read SPS2.1")
        }
        try o5validatePodSps2_1(podSPS2_1)
        throw PodProtocolError.pairingException("Not implemented yet")

        // send 948 byte SPS2 and receive 871 byte SPS2

        // send 0 byte SP0GP0
        seq += 1
        // send SP0GP0
        let sp0gp0 = PairMessage(
            sequenceNumber: seq,
            source: ids.myId,
            destination: podAddress,
            keys: [O5LTKExchanger.SP0GP0],
            payloads: [Data()]
        )
        let result = manager.sendMessagePacket(sp0gp0.message, doRTS: false)
        guard case .sentWithAcknowledgment = result else {
            throw PodProtocolError.pairingException("Error sending SP0GP0: \(result)")
        }

        // read and validate 1 byte P0
        guard let p0 = try manager.readMessagePacket(doRTS: false) else {
            throw PodProtocolError.pairingException("Could not read P0")
        }
        try o5validateP0(p0)

        guard keyExchange.ltk.count == 16 else {
            throw PodProtocolError.invalidLTKKey("Invalid Key, got \(String(data: keyExchange.ltk, encoding: .utf8) ?? "")")
        }

        return PairResult(
            ltk: keyExchange.ltk,
            address: ids.podId.toUInt32(),
            msgSeq: seq
        )
    }

    private func o5throwOnSendError(_ msg: MessagePacket, _ msgType: String) throws {
        let result = manager.sendMessagePacket(msg, doRTS: false)
        guard case .sentWithAcknowledgment = result else {
            throw PodProtocolError.pairingException("Send failure: \(result)")
        }
    }

    private func o5validatePodSps1(_ msg: MessagePacket) throws {
        log.debug("Received SPS1 from pod: %@", msg.payload.hexadecimalString)

        let payload = try StringLengthPrefixEncoding.parseKeys([O5LTKExchanger.SPS1], msg.payload)[0]
        log.debug("SPS1 payload from pod: %@", payload.hexadecimalString)
        
        try keyExchange.o5updatePodPublicData(payload)
    }
    
    private func o5validatePodSps2_1(_ msg: MessagePacket) throws {
        log.debug("Received SPS2.1 from pod: %{PRIVATE}@", msg.payload.hexadecimalString)
        let payload = try StringLengthPrefixEncoding.parseKeys([O5LTKExchanger.SPS2_1], msg.payload)[0]
        log.debug("PDM Private: %{PRIVATE}@", keyExchange.pdmPrivate.hexadecimalString)
        log.debug("PDM Public: %{PRIVATE}@", keyExchange.pdmPublic.hexadecimalString)
        log.debug("PDM Nonce: %{PRIVATE}@", keyExchange.pdmNonce.hexadecimalString)
        log.debug("Pod Public: %{PRIVATE}@", keyExchange.podPublic.hexadecimalString)
        log.debug("Pod Nonce: %{PRIVATE}@", keyExchange.podNonce.hexadecimalString)
        let nonce = keyExchange.getSPSNonce(direction: .read)
        let key = keyExchange.conf
        log.info("Key for SPS2.1: %{PRIVATE}@", key.toHexString())
        let ccm = CCM(iv: nonce.bytes, tagLength: 8, messageLength: payload.count - 8)
        let aes = try AES(key: key.bytes, blockMode: ccm, padding: .noPadding)
        let decryptedPayload = try aes.decrypt(payload.bytes)
        log.info("Decrypted SPS2.1 payload from pod: %{PRIVATE}@", decryptedPayload.toHexString())
        keyExchange.incrementNonce(direction: .read)
    }
    
    
    private func o5sps2_1() throws -> Data {
        let rawCert = Data(hex: "/*DECRYPTED CERT FROM PDM */")
        let nonce = keyExchange.getSPSNonce(direction: .write)
        let key =  keyExchange.conf
        log.info("Encrypting with key %{PRIVATE}@ and nonce %{PRIVATE}@", key.bytes.toHexString(), nonce.bytes.toHexString())
        let ccm = CCM(iv: nonce.bytes, tagLength: 8, messageLength: rawCert.count)
        let aes = try AES(key: key.bytes, blockMode: ccm, padding: .noPadding)
        let payload = try aes.encrypt(rawCert.bytes)
        keyExchange.incrementNonce(direction: .write)
        return Data(payload)
    }

    // The 11-byte O5 SP2 payload is an encoded type 0 get pod status command for the requested id including the calculated CRC-16
    // SP2=[00 0b][[00 0c 3a 35][00][03][0e 01 00][02 45]
    private func o5sp2(podId: Id) -> Data {
        let address = podId.toUInt32()
        let sequenceNum = 0 // when does this 4-bit Omnipod sequence # need to be something else?
        let message = Message(address: address, messageBlocks: [GetStatusCommand()], sequenceNum: sequenceNum)
        let encoded = message.encoded()
        print("Encoded SP2 get status command for address 0x\(String(address, radix: 16)) and seq # \(seq): 0x\(encoded.hexadecimalString)")
        log.debug("Encoded SP2 get status command for address 0x%x and seq # %u: %@", address, seq, encoded.hexadecimalString)
        return encoded
    }

    // 5-byte fixed SPS00: 0000099129
    // The first byte has been 0x00 each time
    // The second is 0x01 for the PDM and 0x00 for the Pod
    // The third is a number that specifies the encryption algorithm
    // Bytes 4 and 5 are CRC-16/XMODEM checksum
    private func o5sps0() -> Data {
        let fixedO5SPS0 = "000109a218" // XXX define values and calculate the CRC-16
        log.debug("Using fixed SPS0 value of %@", fixedO5SPS0)
        return Data(hex: fixedO5SPS0)
    }

    // Validate the returned fixed 5-byte SPS0: 000109a218
    // The first byte has been 0x00 each time
    // The second is 0x01 for the PDM and 0x00 for the Pod
    // The third is a number that specifies the encryption algorithm
    // Bytes 4 and 5 are CRC-16/XMODEM checksum
    private func validateO5sps0(_ msg: MessagePacket) throws {
        log.debug("Received SPS0 from pod: %@", msg.payload.hexadecimalString)

        let payload = try StringLengthPrefixEncoding.parseKeys([O5LTKExchanger.SPS0], msg.payload)[0]
        let fixedO5SPS0Return = "0000099129"  // XXX define values and calculate the CRC-16
        if payload != Data(hex: fixedO5SPS0Return) {
            throw PodProtocolError.pairingException("Received unexpected SPS0 payload: \(payload)")
        }
    }

    private func o5validateP0(_ msg: MessagePacket) throws {
        log.debug("Received P0 from pod: %@", msg.payload.hexadecimalString)

        let payload = try StringLengthPrefixEncoding.parseKeys([O5LTKExchanger.P0], msg.payload)[0]
        log.debug("P0 payload from pod: %@", payload.hexadecimalString)
        if payload != O5LTKExchanger.UNKNOWN_P0_PAYLOAD {
            throw PodProtocolError.pairingException("Reveived unexpected P0 payload: \(payload)")
        }
    }
}

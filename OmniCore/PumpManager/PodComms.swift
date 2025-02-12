//
//  PodComms.swift
//  OmniCore
//
//  Based on Omni{BLE,Kit}/PumpManager/PodComms.swift
//  Created by Joe Moran on 1/9/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import Foundation
import RileyLinkBLEKit
import CoreBluetooth
import LoopKit
import os.log

fileprivate var diagnosePairingRssi = false

/* ZZZ Eros version
protocol PodCommsDelegate: AnyObject {
    func podComms(_ podComms: PodComms, didChange podState: PodState?)
}
ZZZ */

// ZZZ Dash version
protocol PodCommsDelegate: OmniConnectionDelegate {
    func podComms(_ podComms: PodComms, didChange podState: PodState?)
    func podCommsDidEstablishSession(_ podComms: PodComms)
}

class PodComms: CustomDebugStringConvertible {

    var manager: PeripheralManager? {
        didSet {
            manager?.delegate = self
        }
    }

    weak var delegate: PodCommsDelegate?

    weak var messageLogger: MessageLogger?

    public let log = OSLog(category: "PodComms")

    private var podStateLock = NSLock()

    private var podState: PodState? {
        didSet {
            if podState != oldValue {
                delegate?.podComms(self, didChange: podState)
            }
        }
    }

    private var isPaired: Bool {
        get {
            return self.podState?.ltk != nil && self.podState!.ltk != nil && (self.podState!.ltk?.count ?? 0) > 0
        }
    }

    private var needsSessionEstablishment: Bool = false

    private let bluetoothManager = BluetoothManager()

    private var myId: UInt32 = 0 // non-Eros
    private var podId: UInt32 = 0 // non-Eros

    // OmniBLE version
    init(podState: PodState?, myId: UInt32 = 0, podId: UInt32 = 0) {
        self.podState = podState
        self.delegate = nil
        self.messageLogger = nil
        self.myId = myId
        self.podId = podId
        bluetoothManager.connectionDelegate = self
        if let podState = podState, let bleIdentifier = podState.bleIdentifier {
            bluetoothManager.connectToDevice(uuidString: bleIdentifier)
        }
    }

    private let configuredDevices: Locked<Set<UUID>> = Locked(Set())
    
    // OmniKit version
    private var startingPacketNumber = 0

    init(podState: PodState?) {
        self.podState = podState
        self.delegate = nil
        self.messageLogger = nil
    }

    func updateInsulinType(_ insulinType: InsulinType) {
        podStateLock.lock()
        podState?.insulinType = insulinType
        podStateLock.unlock()
    }

    func forgetPod() {
        if let manager = manager {
            self.log.default("Removing %{public}@ from auto-connect ids", manager.peripheral)
            bluetoothManager.disconnectFromDevice(uuidString: manager.peripheral.identifier.uuidString)
        }
        podStateLock.lock()
        podState?.resolveAnyPendingCommandWithUncertainty()
        podState?.finalizeAllDoses()
        podStateLock.unlock()
    }

    // OmniKit only
    func mockPodStateChanges(_ changes: (_ podState: inout PodState) -> Void) -> Void {
        podStateLock.lock()
        changes(&self.podState!)
        podStateLock.unlock()
    }

    func prepForNewPod(myId: UInt32 = 0, podId: UInt32 = 0) {
        self.myId = myId
        self.podId = podId

        podStateLock.lock()
        self.podState = nil
        podStateLock.unlock()
    }

    func connectToNewPod(_ completion: @escaping (Result<Omni, Error>) -> Void) {
        let discoveryStartTime = Date()

        bluetoothManager.discoverPods { error in
            if let error = error {
                completion(.failure(error))
            } else {
                Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
                    let devices = self.bluetoothManager.getConnectedDevices()

                    if devices.count > 1 {
                        self.log.default("Multiple pods found while scanning")
                        self.bluetoothManager.endPodDiscovery()
                        completion(.failure(PodCommsError.tooManyPodsFound))
                        timer.invalidate()
                    }

                    let elapsed = Date().timeIntervalSince(discoveryStartTime)

                    // If we've found a pod by 2 seconds, let's go.
                    if elapsed > TimeInterval(seconds: 2) && devices.count > 0 {
                        self.log.default("Found pod!")
                        let targetPod = devices.first!
                        self.bluetoothManager.connectToDevice(uuidString: targetPod.manager.peripheral.identifier.uuidString)
                        self.manager = targetPod.manager
                        targetPod.manager.delegate = self
                        self.bluetoothManager.endPodDiscovery()
                        completion(.success(devices.first!))
                        timer.invalidate()
                    }

                    if elapsed > TimeInterval(seconds: 10) {
                        self.log.default("No pods found while scanning")
                        self.bluetoothManager.endPodDiscovery()
                        completion(.failure(PodCommsError.noPodsFound))
                        timer.invalidate()
                    }
                }
            }
        }
    }

    // Handles all the common work to send and verify the version response for the two pairing pod commands, AssignAddress and SetupPod.
    private func sendPairMessage(transport: PodMessageTransport, message: Message) throws -> VersionResponse {

        // We should already be holding podStateLock during calls to this function, so try() should fail
        assert(!podStateLock.try(), "\(#function) should be invoked while holding podStateLock")

        defer {
            if self.podState != nil {
                log.debug("sendPairMessage saving current message transport state %@", String(reflecting: transport))
                self.podState!.messageTransportState = MessageTransportState(ck: transport.ck, noncePrefix: transport.noncePrefix, msgSeq: transport.msgSeq, nonceSeq: transport.nonceSeq, messageNumber: transport.messageNumber)
            }
        }

        log.debug("sendPairMessage: attempting to use PodMessageTransport %@ to send message %@", String(reflecting: transport), String(reflecting: message))
        let podMessageResponse = try transport.sendMessage(message)

        if let fault = podMessageResponse.fault {
            log.error("sendPairMessage pod fault: %{public}@", String(describing: fault))
            if let podState = self.podState, podState.fault == nil {
                self.podState!.fault = fault
            }
            throw PodCommsError.podFault(fault: fault)
        }

        guard let versionResponse = podMessageResponse.messageBlocks[0] as? VersionResponse else {
            log.error("sendPairMessage unexpected response: %{public}@", String(describing: podMessageResponse))
            let responseType = podMessageResponse.messageBlocks[0].blockType
            throw PodCommsError.unexpectedResponse(response: responseType)
        }

        log.debug("sendPairMessage: returning versionResponse %@", String(describing: versionResponse))
        return versionResponse
    }

    private func pairPod(insulinType: InsulinType) throws {
        // We should already be holding podStateLock during calls to this function, so try() should fail
        assert(!podStateLock.try(), "\(#function) should be invoked while holding podStateLock")

        guard let manager = manager else { throw PodCommsError.podNotConnected }
        let ids = Ids(myId: self.myId, podId: self.podId)

        let ltkExchanger = LTKExchanger(manager: manager, ids: ids)
        let response = try ltkExchanger.negotiateLTK()
        let ltk = response.ltk

        guard podId == response.address else {
            log.debug("podId 0x%x doesn't match response value!: %{public}@", podId, String(describing: response))
            throw PodCommsError.invalidAddress(address: response.address, expectedAddress: self.podId)
        }

        log.info("Establish an Eap Session")
        guard let messageTransportState = try establishSession(ltk: ltk, eapSeq: 1, msgSeq: Int(response.msgSeq)) else {
            log.debug("pairPod: failed to create messageTransportState!")
            throw PodCommsError.noPodPaired
        }
 
        log.info("LTK and encrypted transport now ready, messageTransportState: %@", String(reflecting: messageTransportState))

        // If we get here, we have the LTK all set up and we should be able use encrypted pod messages
        let transport = PodMessageTransport(manager: manager, myId: self.myId, podId: self.podId, state: messageTransportState)
        transport.messageLogger = messageLogger

        // For Dash this command is vestigal and doesn't actually assign the address (podId)
        // any more as this is done earlier when the LTK is setup. But this Omnipod comamnd is still
        // needed albiet using 0xffffffff for the address while the Eros sets the 0x1f0xxxxx ID.
        let assignAddress = AssignAddressCommand(address: 0xffffffff)
        let message = Message(address: 0xffffffff, messageBlocks: [assignAddress], sequenceNum: transport.messageNumber)

        let versionResponse = try sendPairMessage(transport: transport, message: message)

        // Now create the real PodState using the current transport state and the versionResponse info
        log.debug("pairPod: creating PodState for versionResponse %{public}@ and transport %{public}@", String(describing: versionResponse), String(describing: transport.state))
        self.podState = PodState(
            address: self.podId,
            firmwareVersion: String(describing: versionResponse.firmwareVersion),
            iFirmwareVersion: String(describing: versionResponse.iFirmwareVersion),
            lotNo: versionResponse.lot,
            lotSeq: versionResponse.tid,
            insulinType: insulinType,
            podType: versionResponse.podType,
            messageTransportState: transport.state,
            ltk: ltk,
            bleIdentifier: manager.peripheral.identifier.uuidString
        )

        // podState setupProgress state should be addressAssigned

        // Now that we have podState, check for an activation timeout condition that can be noted in setupProgress
        guard versionResponse.podProgressStatus != .activationTimeExceeded else {
            // The 2 hour window for the initial pairing has expired
            self.podState?.setupProgress = .activationTimeout
            throw PodCommsError.activationTimeExceeded
        }

        log.debug("pairPod: self.PodState messageTransportState now: %@", String(reflecting: self.podState?.messageTransportState))
    }

    private func establishSession(ltk: Data, eapSeq: Int, msgSeq: Int = 1)  throws -> MessageTransportState? {
        // We should already be holding podStateLock during calls to this function, so try() should fail
        assert(!podStateLock.try(), "\(#function) should be invoked while holding podStateLock")

        guard let manager = manager else { throw PodCommsError.noPodPaired }
        let eapAkaExchanger = try SessionEstablisher(manager: manager, ltk: ltk, eapSqn: eapSeq, myId: self.myId, podId: self.podId, msgSeq: msgSeq)

        let result = try eapAkaExchanger.negotiateSessionKeys()

        switch result {
        case .SessionNegotiationResynchronization(let keys):
            log.debug("Received EAP SQN resynchronization: %@", keys.synchronizedEapSqn.data.hexadecimalString)
            if self.podState != nil {
                let eapSeq = keys.synchronizedEapSqn.toInt()
                log.debug("Updating EAP SQN to: %d", eapSeq)
                self.podState!.messageTransportState.eapSeq = eapSeq
            }
            return nil
        case .SessionKeys(let keys):
            log.debug("Session Established")
            // log.debug("CK: %@", keys.ck.hexadecimalString)
            log.info("msgSequenceNumber: %@", String(keys.msgSequenceNumber))
            // log.info("NoncePrefix: %@", keys.nonce.prefix.hexadecimalString)

            let omnipodMessageNumber = self.podState?.messageTransportState.messageNumber ?? 0
            let messageTransportState = MessageTransportState(
                ck: keys.ck,
                noncePrefix: keys.nonce.prefix,
                eapSeq: eapSeq,
                msgSeq: keys.msgSequenceNumber,
                messageNumber: omnipodMessageNumber
            )

            if self.podState != nil {
                log.debug("Setting podState transport state to %{public}@", String(describing: messageTransportState))
                self.podState!.messageTransportState = messageTransportState
            } else {
                log.debug("Used keys %@ to create messageTransportState: %@", String(reflecting: keys), String(reflecting: messageTransportState))
            }
            return messageTransportState
        }
    }

    private func establishNewSession() throws {
        // We should already be holding podStateLock during calls to this function, so try() should fail
        assert(!podStateLock.try(), "\(#function) should be invoked while holding podStateLock")

        guard self.podState != nil, self.podState!.ltk != nil else {
            throw PodCommsError.noPodPaired
        }

        let mts = try establishSession(ltk: self.podState!.ltk!, eapSeq: self.podState!.incrementEapSeq())
        if mts == nil {
            let mts = try establishSession(ltk: self.podState!.ltk!, eapSeq: self.podState!.incrementEapSeq())
            if mts == nil {
                throw PodCommsError.diagnosticMessage(str: "Received resynchronization SQN for the second time")
            }
        }
    }

    private func setupPod(timeZone: TimeZone) throws {
        guard let manager = manager else { throw PodCommsError.podNotConnected }

        // We should already be holding podStateLock during calls to this function, so try() should fail
        assert(!podStateLock.try(), "\(#function) should be invoked while holding podStateLock")

        let transport = PodMessageTransport(manager: manager, myId: self.myId, podId: self.podId, state: podState!.messageTransportState)
        transport.messageLogger = messageLogger

        let dateComponents = SetupPodCommand.dateComponents(date: Date(), timeZone: timeZone)
        let setupPod = SetupPodCommand(address: podState!.address, dateComponents: dateComponents, lot: UInt32(podState!.lotNo), tid: podState!.lotSeq)

        let message = Message(address: 0xffffffff, messageBlocks: [setupPod], sequenceNum: transport.messageNumber)

        log.debug("setupPod: calling sendPairMessage %@ for message %@", String(reflecting: transport), String(describing: message))
        let versionResponse = try sendPairMessage(transport: transport, message: message)

        // Verify that the fundemental pod constants returned match the expected constant values in the Pod struct.
        // To actually be able to handle different fundemental values in Loop things would need to be reworked to save
        // these values in some persistent PodState and then make sure that everything properly works using these values.
        var errorStrings: [String] = []
        if let pulseSize = versionResponse.pulseSize, pulseSize != Pod.pulseSize  {
            errorStrings.append(String(format: "Pod reported pulse size of %.3fU different than expected %.3fU", pulseSize, Pod.pulseSize))
        }
        if let secondsPerBolusPulse = versionResponse.secondsPerBolusPulse, secondsPerBolusPulse != Pod.secondsPerBolusPulse  {
            errorStrings.append(String(format: "Pod reported seconds per pulse rate of %.1f different than expected %.1f", secondsPerBolusPulse, Pod.secondsPerBolusPulse))
        }
        if let secondsPerPrimePulse = versionResponse.secondsPerPrimePulse, secondsPerPrimePulse != Pod.secondsPerPrimePulse  {
            errorStrings.append(String(format: "Pod reported seconds per prime pulse rate of %.1f different than expected %.1f", secondsPerPrimePulse, Pod.secondsPerPrimePulse))
        }
        if let primeUnits = versionResponse.primeUnits, primeUnits != Pod.primeUnits {
            errorStrings.append(String(format: "Pod reported prime bolus of %.2fU different than expected %.2fU", primeUnits, Pod.primeUnits))
        }
        if let cannulaInsertionUnits = versionResponse.cannulaInsertionUnits, Pod.cannulaInsertionUnits != cannulaInsertionUnits {
            errorStrings.append(String(format: "Pod reported cannula insertion bolus of %.2fU different than expected %.2fU", cannulaInsertionUnits, Pod.cannulaInsertionUnits))
        }
        if let serviceDuration = versionResponse.serviceDuration {
            if serviceDuration < Pod.serviceDuration {
                errorStrings.append(String(format: "Pod reported service duration of %.0f hours shorter than expected %.0f", serviceDuration.hours, Pod.serviceDuration.hours))
            } else if serviceDuration > Pod.serviceDuration {
                log.info("Pod reported service duration of %.0f hours limited to expected %.0f", serviceDuration.hours, Pod.serviceDuration.hours)
            }
        }

        let errMess = errorStrings.joined(separator: ".\n")
        if errMess.isEmpty == false {
            log.error("%@", errMess)
            self.podState?.setupProgress = .podIncompatible
            throw PodCommsError.podIncompatible(str: errMess)
        }

        if versionResponse.podProgressStatus == .pairingCompleted && self.podState?.setupProgress.isPaired == false {
            log.info("Version Response %{public}@ indicates pod pairing is now complete", String(describing: versionResponse))
            self.podState?.setupProgress = .podPaired
        }
    }

    func pairAndSetupPod(
        timeZone: TimeZone,
        insulinType: InsulinType,
        messageLogger: MessageLogger?,
        _ block: @escaping (_ result: SessionRunResult) -> Void
    ) {
        guard let manager = manager else {
            // no available Dash pump to communicate with
            block(.failure(PodCommsError.noResponse))
            return
        }

        let myId = self.myId
        let podId = self.podId
        log.info("Attempting to pair using myId %X and podId %X", myId, podId)

        manager.runSession(withName: "Pair and setup pod") { [weak self] in
            do {
                guard let self = self else { fatalError() }

                // Synchronize access to podState
                self.podStateLock.lock()
                defer {
                    self.podStateLock.unlock()
                }

                try manager.sendHello(myId: myId)
                try manager.enableNotifications() // Seemingly this cannot be done before the hello command, or the pod disconnects

                if (!self.isPaired) {
                    try self.pairPod(insulinType: insulinType)
                } else {
                    try self.establishNewSession()
                }

                guard self.podState != nil else {
                    block(.failure(PodCommsError.noPodPaired))
                    return
                }

                if self.podState!.setupProgress.isPaired == false {
                    try self.setupPod(timeZone: timeZone)
                }

                guard self.podState!.setupProgress.isPaired else {
                    self.log.error("Unexpected podStatus setupProgress value of %{public}@", String(describing: self.podState!.setupProgress))
                    throw PodCommsError.invalidData
                }

                // Run a session now for any post-pairing commands
                let transport = PodMessageTransport(manager: manager, myId: myId, podId: podId, state: self.podState!.messageTransportState)
                transport.messageLogger = self.messageLogger
                let podSession = PodCommsSession(podState: self.podState!, transport: transport, delegate: self)

                block(.success(session: podSession))
            } catch let error as PodCommsError {
                block(.failure(error))
            } catch {
                block(.failure(PodCommsError.commsError(error: error)))
            }
        }
    }

    enum SessionRunResult {
        case success(session: PodCommsSession)
        case failure(PodCommsError)
    }

    func runSession(withName name: String, using deviceSelector: @escaping (_ completion: @escaping (_ device: RileyLinkDevice?) -> Void) -> Void, _ block: @escaping (_ result: SessionRunResult) -> Void) {
        if podState?.podType.usesRileyLink == false {
            return runSession(withName: name, block) // OmniBLE version
        }
        // OmniKit version
    }

    // Use to serialize a set of Pod Commands for a given session
    func runSession(withName name: String, _ block: @escaping (_ result: SessionRunResult) -> Void) {

        guard let manager = manager, manager.peripheral.state == .connected else {
            block(.failure(PodCommsError.podNotConnected))
            return
        }

        manager.runSession(withName: name) { () in

            // Synchronize access to podState
            self.podStateLock.lock()
            defer {
                self.podStateLock.unlock()
            }

            guard self.podState != nil else {
                block(.failure(PodCommsError.noPodPaired))
                return
            }

            let transport = PodMessageTransport(manager: manager, myId: self.myId, podId: self.podId, state: self.podState!.messageTransportState)
            transport.messageLogger = self.messageLogger
            let podSession = PodCommsSession(podState: self.podState!, transport: transport, delegate: self)
            block(.success(session: podSession))
        }
    }

    // MARK: - CustomDebugStringConvertible

    var debugDescription: String {
        return [
            "## PodComms",
            "* myId: \(String(format: "%08X", myId))",
            "* podId: \(String(format: "%08X", podId))",
            "* configuredDevices: \(configuredDevices.value.map { $0.uuidString })",
            "* delegate: \(String(describing: delegate != nil))",
            ""
        ].joined(separator: "\n")
    }

    
    // MARK: - RileyLink specific PodComms routines

    func assignAddressAndSetupPod(
        address: UInt32,
        using deviceSelector: @escaping (_ completion: @escaping (_ device: RileyLinkDevice?) -> Void) -> Void,
        timeZone: TimeZone,
        insulinType: InsulinType,
        messageLogger: MessageLogger?,
        _ block: @escaping (_ result: SessionRunResult) -> Void)
    {
    }
}


// MARK: - OmniConnectionDelegate

extension PodComms: OmniConnectionDelegate {
    func omnipodPeripheralWasRestored(manager: PeripheralManager) {
        if let podState = podState, manager.peripheral.identifier.uuidString == podState.bleIdentifier {
            self.manager = manager
            self.delegate?.omnipodPeripheralWasRestored(manager: manager)
        }
    }

    func omnipodPeripheralDidConnect(manager: PeripheralManager) {
        if let podState = podState, manager.peripheral.identifier.uuidString == podState.bleIdentifier {
            needsSessionEstablishment = true
            self.manager = manager
            self.delegate?.omnipodPeripheralDidConnect(manager: manager)
        }
    }

    func omnipodPeripheralDidDisconnect(peripheral: CBPeripheral, error: Error?) {
        if let podState = podState, peripheral.identifier.uuidString == podState.bleIdentifier {
            self.delegate?.omnipodPeripheralDidDisconnect(peripheral: peripheral, error: error)
            log.debug("omnipodPeripheralDidDisconnect... will auto-reconnect")
        }
    }

    func omnipodPeripheralDidFailToConnect(peripheral: CBPeripheral, error: Error?) {
        if let podState = podState, peripheral.identifier.uuidString == podState.bleIdentifier {
            self.delegate?.omnipodPeripheralDidFailToConnect(peripheral: peripheral, error: error)
            log.debug("omnipodPeripheralDidDisconnect... will auto-reconnect")
        }
    }

}

// MARK: - PeripheralManagerDelegate

extension PodComms: PeripheralManagerDelegate {

    func completeConfiguration(for manager: PeripheralManager) throws {
        log.default("PodComms completeConfiguration: isPaired=%{public}@ needsSessionEstablishment=%{public}@", String(describing: self.isPaired), String(describing: needsSessionEstablishment))

        if self.isPaired && needsSessionEstablishment {
            let myId = self.myId

            self.podStateLock.lock()
            defer {
                self.podStateLock.unlock()

            }

            do {
                try manager.sendHello(myId: myId)
                try manager.enableNotifications() // Seemingly this cannot be done before the hello command, or the pod disconnects
                try self.establishNewSession()
                self.delegate?.podCommsDidEstablishSession(self)
            } catch {
                self.log.error("Pod session sync error: %{public}@", String(describing: error))
            }

        } else {
            log.default("Session already established.")
        }
    }
}

extension PodComms: PodCommsSessionDelegate {
    // We hold podStateLock for the duration of the PodCommsSession
    func podCommsSession(_ podCommsSession: PodCommsSession, didChange state: PodState) {
        
        // We should already be holding podStateLock during calls to this function, so try() should fail
        assert(!podStateLock.try(), "\(#function) should be invoked while holding podStateLock")

        podCommsSession.assertOnSessionQueue()
        self.podState = state
    }
}

// ZZZ OmniKit extras...

private extension CommandSession {

    func configureRadio() throws {
        
        //        SYNC1     |0xDF00|0x54|Sync Word, High Byte
        //        SYNC0     |0xDF01|0xC3|Sync Word, Low Byte
        //        PKTLEN    |0xDF02|0x32|Packet Length
        //        PKTCTRL1  |0xDF03|0x24|Packet Automation Control
        //        PKTCTRL0  |0xDF04|0x00|Packet Automation Control
        //        FSCTRL1   |0xDF07|0x06|Frequency Synthesizer Control
        //        FREQ2     |0xDF09|0x12|Frequency Control Word, High Byte
        //        FREQ1     |0xDF0A|0x14|Frequency Control Word, Middle Byte
        //        FREQ0     |0xDF0B|0x5F|Frequency Control Word, Low Byte
        //        MDMCFG4   |0xDF0C|0xCA|Modem configuration
        //        MDMCFG3   |0xDF0D|0xBC|Modem Configuration
        //        MDMCFG2   |0xDF0E|0x0A|Modem Configuration
        //        MDMCFG1   |0xDF0F|0x13|Modem Configuration
        //        MDMCFG0   |0xDF10|0x11|Modem Configuration
        //        MCSM0     |0xDF14|0x18|Main Radio Control State Machine Configuration
        //        FOCCFG    |0xDF15|0x17|Frequency Offset Compensation Configuration
        //        AGCCTRL1  |0xDF18|0x70|AGC Control
        //        FSCAL3    |0xDF1C|0xE9|Frequency Synthesizer Calibration
        //        FSCAL2    |0xDF1D|0x2A|Frequency Synthesizer Calibration
        //        FSCAL1    |0xDF1E|0x00|Frequency Synthesizer Calibration
        //        FSCAL0    |0xDF1F|0x1F|Frequency Synthesizer Calibration
        //        TEST1     |0xDF24|0x31|Various Test Settings
        //        TEST0     |0xDF25|0x09|Various Test Settings
        //        PA_TABLE0 |0xDF2E|0x60|PA Power Setting 0
        //        VERSION   |0xDF37|0x04|Chip ID[7:0]

        try setSoftwareEncoding(.manchester)
        try setPreamble(0x6665)
        try setBaseFrequency(Measurement(value: 433.91, unit: .megahertz))
        try updateRegister(.pktctrl1, value: 0x20)
        try updateRegister(.pktctrl0, value: 0x00)
        try updateRegister(.fsctrl1, value: 0x06)
        try updateRegister(.mdmcfg4, value: 0xCA)
        try updateRegister(.mdmcfg3, value: 0xBC)  // 0xBB for next lower bitrate
        try updateRegister(.mdmcfg2, value: 0x06)
        try updateRegister(.mdmcfg1, value: 0x70)
        try updateRegister(.mdmcfg0, value: 0x11)
        try updateRegister(.deviatn, value: 0x44)
        try updateRegister(.mcsm0, value: 0x18)
        try updateRegister(.foccfg, value: 0x17)
        try updateRegister(.fscal3, value: 0xE9)
        try updateRegister(.fscal2, value: 0x2A)
        try updateRegister(.fscal1, value: 0x00)
        try updateRegister(.fscal0, value: 0x1F)
        
        try updateRegister(.test1, value: 0x31)
        try updateRegister(.test0, value: 0x09)
        try updateRegister(.paTable0, value: 0x84)
        try updateRegister(.sync1, value: 0xA5)
        try updateRegister(.sync0, value: 0x5A)
    }

    // This is just a testing function for spoofing PDM packets, or other times when you need to generate a custom packet
    private func sendPacket() throws {
        let packetNumber = 19
        let messageNumber = 0x24 >> 2
        let address: UInt32 = 0x1f0b3554

        let cmd = GetStatusCommand(podInfoType: .normal)

        let message = Message(address: address, messageBlocks: [cmd], sequenceNum: messageNumber)

        var dataRemaining = message.encoded()

        /* ZZZ needs Packet()
        let sendPacket = Packet(address: address, packetType: .pdm, sequenceNum: packetNumber, data: dataRemaining)
        dataRemaining = dataRemaining.subdata(in: sendPacket.data.count..<dataRemaining.count)

        let _ = try sendAndListen(sendPacket.encoded(), repeatCount: 0, timeout: .milliseconds(333), retryCount: 0, preambleExtension: .milliseconds(127))
        ZZZ */

        throw PodCommsError.emptyResponse
    }
}

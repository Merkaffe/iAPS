//
//  PodComms.swift
//  OmnipodKit
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

protocol PodCommsDelegate: OmniConnectionDelegate {
    func podComms(_ podComms: PodComms, didChange podState: PodState?)
    func podCommsDidEstablishSession(_ podComms: PodComms) // non-RL only
}

class PodComms: CustomDebugStringConvertible {

    // RL only var's
    private let configuredDevices: Locked<Set<UUID>> = Locked(Set())
    private var startingPacketNumber = 0
    // end RL-only var's

    // non-RL only var's
    var manager: PeripheralManager? {
        didSet {
            manager?.delegate = self
        }
    }

    private var isPaired: Bool {
        get {
            return self.podState?.ltk != nil && self.podState!.ltk != nil && (self.podState!.ltk?.count ?? 0) > 0
        }
    }

    private var needsSessionEstablishment: Bool = false

    private let bluetoothManager = BluetoothManager()

    private var myId: UInt32 = 0
    private var podId: UInt32 = 0
    // end non-RL only var's

    weak var delegate: PodCommsDelegate?

    weak var messageLogger: MessageLogger?

    let log = OSLog(category: "PodComms")

    private var podStateLock = NSLock()

    private var podState: PodState? {
        didSet {
            if podState != oldValue {
                delegate?.podComms(self, didChange: podState)
            }
        }
    }

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

    // Eros only - used to set podState.setupProgress to .priming when doing a mock prime
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

    // BLE pods only
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
    // BLE pods only
    private func bleSendPairMessage(blePodMessageTransport: BlePodMessageTransport, message: Message) throws -> VersionResponse {

        // We should already be holding podStateLock during calls to this function, so try() should fail
        assert(!podStateLock.try(), "\(#function) should be invoked while holding podStateLock")

        defer {
            if self.podState != nil {
                log.debug("bleSendPairMessage saving current message transport state %@", String(reflecting: blePodMessageTransport))
                self.podState!.bleMessageTransportState = BleMessageTransportState(ck: blePodMessageTransport.ck, noncePrefix: blePodMessageTransport.noncePrefix, msgSeq: blePodMessageTransport.msgSeq, nonceSeq: blePodMessageTransport.nonceSeq, messageNumber: blePodMessageTransport.messageNumber)
            }
        }

        log.debug("bleSendPairMessage: attempting to use PodMessageTransport %@ to send message %@", String(reflecting: blePodMessageTransport), String(reflecting: message))
        let podMessageResponse = try blePodMessageTransport.sendMessage(message)

        if let fault = podMessageResponse.fault {
            log.error("bleSendPairMessage pod fault: %{public}@", String(describing: fault))
            if let podState = self.podState, podState.fault == nil {
                self.podState!.fault = fault
            }
            throw PodCommsError.podFault(fault: fault)
        }

        guard let versionResponse = podMessageResponse.messageBlocks[0] as? VersionResponse else {
            log.error("bleSendPairMessage unexpected response: %{public}@", String(describing: podMessageResponse))
            let responseType = podMessageResponse.messageBlocks[0].blockType
            throw PodCommsError.unexpectedResponse(response: responseType)
        }

        log.debug("bleSendPairMessage: returning versionResponse %@", String(describing: versionResponse))
        return versionResponse
    }

    // BLE pods only
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
        guard let bleMessageTransportState = try establishSession(ltk: ltk, eapSeq: 1, msgSeq: Int(response.msgSeq)) else {
            log.debug("pairPod: failed to create messageTransportState!")
            throw PodCommsError.noPodPaired
        }
 
        log.info("LTK and encrypted transport now ready, messageTransportState: %@", String(reflecting: bleMessageTransportState))

        // If we get here, we have the LTK all set up and we should be able use encrypted pod messages
        let blePodMessageTransport = BlePodMessageTransport(manager: manager, myId: self.myId, podId: self.podId, state: bleMessageTransportState)
        blePodMessageTransport.messageLogger = messageLogger

        // For Dash this command is vestigal and doesn't actually assign the address (podId)
        // any more as this is done earlier when the LTK is setup. But this Omnipod comamnd is still
        // needed albiet using 0xffffffff for the address while the Eros sets the 0x1f0xxxxx ID.
        let assignAddress = AssignAddressCommand(address: 0xffffffff)
        let message = Message(address: 0xffffffff, messageBlocks: [assignAddress], sequenceNum: blePodMessageTransport.messageNumber)

        let versionResponse = try bleSendPairMessage(blePodMessageTransport: blePodMessageTransport, message: message)

        // Now create the real PodState using the current transport state and the versionResponse info
        log.debug("pairPod: creating PodState for versionResponse %{public}@ and transport %{public}@", String(describing: versionResponse), String(describing: blePodMessageTransport.state))
        self.podState = PodState(
            address: self.podId,
            firmwareVersion: String(describing: versionResponse.firmwareVersion),
            iFirmwareVersion: String(describing: versionResponse.iFirmwareVersion),
            lotNo: versionResponse.lot,
            lotSeq: versionResponse.tid,
            insulinType: insulinType,
            podType: versionResponse.podType,
            bleMessageTransportState: blePodMessageTransport.state,
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

        log.debug("pairPod: self.PodState bleMessageTransportState now: %@", String(reflecting: self.podState?.bleMessageTransportState))
    }

    // BLE pods only
    private func establishSession(ltk: Data, eapSeq: Int, msgSeq: Int = 1) throws -> BleMessageTransportState? {
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
                self.podState!.bleMessageTransportState.eapSeq = eapSeq
            }
            return nil
        case .SessionKeys(let keys):
            log.debug("Session Established")
            // log.debug("CK: %@", keys.ck.hexadecimalString)
            log.info("msgSequenceNumber: %@", String(keys.msgSequenceNumber))
            // log.info("NoncePrefix: %@", keys.nonce.prefix.hexadecimalString)

            let omnipodMessageNumber = self.podState?.bleMessageTransportState.messageNumber ?? 0
            let bleMessageTransportState = BleMessageTransportState(
                ck: keys.ck,
                noncePrefix: keys.nonce.prefix,
                eapSeq: eapSeq,
                msgSeq: keys.msgSequenceNumber,
                messageNumber: omnipodMessageNumber
            )

            if self.podState != nil {
                log.debug("Setting podState transport state to %{public}@", String(describing: bleMessageTransportState))
                self.podState!.bleMessageTransportState = bleMessageTransportState
            } else {
                log.debug("Used keys %@ to create bleMessageTransportState: %@", String(reflecting: keys), String(reflecting: bleMessageTransportState))
            }
            return bleMessageTransportState
        }
    }

    // BLE pods only
    private func establishNewSession() throws {
        // We should already be holding podStateLock during calls to this function, so try() should fail
        assert(!podStateLock.try(), "\(#function) should be invoked while holding podStateLock")

        guard self.podState != nil, let ltk = self.podState!.ltk else {
            throw PodCommsError.noPodPaired
        }

        let mts = try establishSession(ltk: ltk, eapSeq: self.podState!.incrementEapSeq())
        if mts == nil {
            let mts = try establishSession(ltk: ltk, eapSeq: self.podState!.incrementEapSeq())
            if mts == nil {
                throw PodCommsError.diagnosticMessage(str: "Received resynchronization SQN for the second time")
            }
        }
    }

    // BLE pods only
    private func setupPod(timeZone: TimeZone) throws {
        guard let manager = manager else { throw PodCommsError.podNotConnected }

        // We should already be holding podStateLock during calls to this function, so try() should fail
        assert(!podStateLock.try(), "\(#function) should be invoked while holding podStateLock")

        let blePodMessageTransport = BlePodMessageTransport(manager: manager, myId: self.myId, podId: self.podId, state: podState!.bleMessageTransportState)
        blePodMessageTransport.messageLogger = messageLogger

        let dateComponents = SetupPodCommand.dateComponents(date: Date(), timeZone: timeZone)
        let setupPod = SetupPodCommand(address: podState!.address, dateComponents: dateComponents, lot: UInt32(podState!.lotNo), tid: podState!.lotSeq)

        let message = Message(address: 0xffffffff, messageBlocks: [setupPod], sequenceNum: blePodMessageTransport.messageNumber)

        log.debug("setupPod: calling bleSendPairMessage %@ for message %@", String(reflecting: blePodMessageTransport), String(describing: message))
        let versionResponse = try bleSendPairMessage(blePodMessageTransport: blePodMessageTransport, message: message)

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

    // BLE pods only
    func pairAndSetupPod(
        timeZone: TimeZone,
        insulinType: InsulinType,
        messageLogger: MessageLogger?,
        _ block: @escaping (_ result: SessionRunResult) -> Void
    ) {
        guard let manager = manager else {
            // no available BLE pump to communicate with
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
                let blePodMessageTransport = BlePodMessageTransport(manager: manager, myId: myId, podId: podId, state: self.podState!.bleMessageTransportState)
                blePodMessageTransport.messageLogger = self.messageLogger
                let podSession = PodCommsSession(podState: self.podState!, transport: blePodMessageTransport, delegate: self)

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

    // Used to serialize a set of Pod Commands for a given session - vectors to correct version
    func runSession(withName name: String, using deviceSelector: @escaping (_ completion: @escaping (_ device: RileyLinkDevice?) -> Void) -> Void, _ block: @escaping (_ result: SessionRunResult) -> Void)
    {
        if podState?.podType.usesRileyLink == true {
            return erosRunSession(withName: name, using: deviceSelector, block) // OmniKit version
        } else {
            return bleRunSession(withName: name, block) // OmniBLE version
        }
    }


    // OmniBLE version - Used to serialize a set of Pod Commands for a given session
    func bleRunSession(withName name: String, _ block: @escaping (_ result: SessionRunResult) -> Void) {

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

            let blePodMessageTransport = BlePodMessageTransport(manager: manager, myId: self.myId, podId: self.podId, state: self.podState!.bleMessageTransportState)
            blePodMessageTransport.messageLogger = self.messageLogger
            let podSession = PodCommsSession(podState: self.podState!, transport: blePodMessageTransport, delegate: self)
            block(.success(session: podSession))
        }
    }

    // MARK: - CustomDebugStringConvertible

    var debugDescription: String {
        var ret = "## PodComms\n"
        if myId != 0 || podId != 0 {
            ret += "* myId: \(String(format: "%08X", myId))\n* podId: \(String(format: "%08X", podId))\n"
        }
        ret += "* configuredDevices: \(configuredDevices.value.map { $0.uuidString })\n* delegate: \(String(describing: delegate != nil))\n"
        return ret
    }

    
    // MARK: - Eros & RileyLink specific PodComms routines

    /// Handles all the common work to send and verify the version response for the two pairing commands, AssignAddress and SetupPod.
    ///  Has side effects of creating pod state, assigning startingPacketNumber, and updating pod state.
    ///
    /// - parameter address: Address being assigned to the pod
    /// - parameter transport: PodMessageTransport used to send messages
    /// - parameter message: Message to send; must be an AssignAddress or SetupPod
    ///
    /// - returns: The VersionResponse from the pod
    ///
    /// - Throws:
    ///     - PodCommsError.noResponseRL
    ///     - PodCommsError.podAckedInsteadOfReturningResponse
    ///     - PodCommsError.unexpectedPacketType
    ///     - PodCommsError.emptyResponse
    ///     - PodCommsError.unexpectedResponse
    ///     - PodCommsError.podChange
    ///     - PodCommsError.activationTimeExceeded
    ///     - PodCommsError.rssiTooLow
    ///     - PodCommsError.rssiTooHigh
    ///     - PodCommsError.podFault
    ///     - PodCommsError.diagnosticMessage
    ///     - PodCommsError.podIncompatible
    ///     - MessageError.invalidCrc
    ///     - MessageError.invalidSequence
    ///     - MessageError.invalidAddress
    ///     - RileyLinkDeviceError
    private func erosSendPairMessage(address: UInt32, erosPodMessageTransport: ErosPodMessageTransport, message: Message, insulinType: InsulinType) throws -> VersionResponse {

        // We should already be holding podStateLock during calls to this function, so try() should fail
        assert(!podStateLock.try(), "\(#function) should be invoked while holding podStateLock")

        defer {
            log.debug("erosSendPairMessage saving current transport packet #%d", erosPodMessageTransport.packetNumber)
            if self.podState != nil {
                self.podState!.erosMessageTransportState = ErosMessageTransportState(packetNumber: erosPodMessageTransport.packetNumber, messageNumber: erosPodMessageTransport.messageNumber)
            } else {
                self.startingPacketNumber = erosPodMessageTransport.packetNumber
            }
        }

        var didRetry = false

        var rssiRetries = 2
        while true {
            let response: Message
            do {
                response = try erosPodMessageTransport.sendMessage(message)
            } catch let error {
                if let podCommsError = error as? PodCommsError {
                    switch podCommsError {
                    // These errors can happen some times when the responses are not seen for a long
                    // enough time. Automatically retrying using the already incremented packet # can
                    // clear this condition without requiring any user interaction for a pairing failure.
                    case .podAckedInsteadOfReturningResponse, .noResponse, .noResponseRL:
                        if didRetry == false {
                            didRetry = true
                            log.debug("erosSendPairMessage to retry using updated packet #%d", erosPodMessageTransport.packetNumber)
                            continue // the transport packet # is already advanced for the retry
                        }
                    default:
                        break
                    }
                }
                throw error
            }

            if let fault = response.fault {
                log.error("Pod Fault: %{public}@", String(describing: fault))
                if let podState = self.podState, podState.fault == nil {
                    self.podState!.fault = fault
                }
                throw PodCommsError.podFault(fault: fault)
            }

            guard let config = response.messageBlocks[0] as? VersionResponse else {
                log.error("erosSendPairMessage unexpected response: %{public}@", String(describing: response))
                let responseType = response.messageBlocks[0].blockType
                throw PodCommsError.unexpectedResponse(response: responseType)
            }

            guard config.address == address else {
                log.error("erosSendPairMessage unexpected address return of %{public}@ instead of expected %{public}@",
                  String(format: "08X", config.address), String(format: "%08X", address))
                throw PodCommsError.invalidAddress(address: config.address, expectedAddress: address)
            }

            // If we previously had podState, verify that we are still dealing with the same pod
            if let podState = self.podState, (podState.lotNo != config.lot || podState.lotSeq != config.tid) {
                // Have a new pod, could be a pod change w/o deactivation (or we're picking up some other pairing pod!)
                log.error("Received pod response for [lot %u tid %u], expected [lot %u tid %u]", config.lot, config.tid, podState.lotNo, podState.lotSeq)
                throw PodCommsError.podChange
            }

            // Check the pod RSSI
            let maxRssiAllowed = 59         // maximum RSSI limit allowed
            let minRssiAllowed = 30         // minimum RSSI limit allowed
            if let rssi = config.rssi, let gain = config.gain {
                let rssiStr = String(format: "RSSI: %u.\nReceiver Low Gain: %u", rssi, gain)
                log.default("%@", rssiStr)
                if diagnosePairingRssi {
                    throw PodCommsError.diagnosticMessage(str: rssiStr)
                }

                rssiRetries -= 1
                if rssi < minRssiAllowed {
                    log.default("RSSI value %d is less than minimum allowed value of %d, %d retries left", rssi, minRssiAllowed, rssiRetries)
                    if rssiRetries > 0 {
                        continue
                    }
                    throw PodCommsError.rssiTooLow
                }
                if rssi > maxRssiAllowed {
                    log.default("RSSI value %d is more than maximum allowed value of %d, %d retries left", rssi, maxRssiAllowed, rssiRetries)
                    if rssiRetries > 0 {
                        continue
                    }
                    throw PodCommsError.rssiTooHigh
                }
            }

            if self.podState == nil {
                log.default("Creating PodState for address %{public}@ [lot %u tid %u], packet #%d, message #%d", String(format: "%04X", config.address), config.lot, config.tid, erosPodMessageTransport.packetNumber, erosPodMessageTransport.messageNumber)
                self.podState = PodState(
                    address: config.address,
                    firmwareVersion: String(describing: config.firmwareVersion),
                    iFirmwareVersion: String(describing: config.iFirmwareVersion),
                    lotNo: config.lot,
                    lotSeq: config.tid,
                    insulinType: insulinType,
                    podType: erosType,
                    erosMessageTransportState: erosPodMessageTransport.state
                )
                // podState setupProgress state should be addressAssigned
            }

            // Now that we have podState, check for an activation timeout condition that can be noted in setupProgress
            guard config.podProgressStatus != .activationTimeExceeded else {
                // The 2 hour window for the initial pairing has expired
                self.podState?.setupProgress = .activationTimeout
                throw PodCommsError.activationTimeExceeded
            }

            // It's unlikely that Insulet will release an updated Eros pod using any different fundemental values,
            // so just verify that the fundemental pod constants returned match the expected constant values in the Pod struct.
            // To actually be able to handle different fundemental values in Loop things would need to be reworked to save
            // these values in some persistent PodState and then make sure that everything properly works using these values.
            var errorStrings: [String] = []
            if let pulseSize = config.pulseSize, pulseSize != Pod.pulseSize  {
                errorStrings.append(String(format: "Pod reported pulse size of %.3fU different than expected %.3fU", pulseSize, Pod.pulseSize))
            }
            if let secondsPerBolusPulse = config.secondsPerBolusPulse, secondsPerBolusPulse != Pod.secondsPerBolusPulse  {
                errorStrings.append(String(format: "Pod reported seconds per pulse rate of %.1f different than expected %.1f", secondsPerBolusPulse, Pod.secondsPerBolusPulse))
            }
            if let secondsPerPrimePulse = config.secondsPerPrimePulse, secondsPerPrimePulse != Pod.secondsPerPrimePulse  {
                errorStrings.append(String(format: "Pod reported seconds per prime pulse rate of %.1f different than expected %.1f", secondsPerPrimePulse, Pod.secondsPerPrimePulse))
            }
            if let primeUnits = config.primeUnits, primeUnits != Pod.primeUnits {
                errorStrings.append(String(format: "Pod reported prime bolus of %.2fU different than expected %.2fU", primeUnits, Pod.primeUnits))
            }
            if let cannulaInsertionUnits = config.cannulaInsertionUnits, Pod.cannulaInsertionUnits != cannulaInsertionUnits {
                errorStrings.append(String(format: "Pod reported cannula insertion bolus of %.2fU different than expected %.2fU", cannulaInsertionUnits, Pod.cannulaInsertionUnits))
            }
            if let serviceDuration = config.serviceDuration {
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

            if config.podProgressStatus == .pairingCompleted && self.podState?.setupProgress.isPaired == false {
                log.info("Version Response %{public}@ indicates pairing is now complete", String(describing: config))
                self.podState?.setupProgress = .podPaired
            }

            return config
        }
    }

    // Eros only
    private func assignAddress(address: UInt32, commandSession: CommandSession, insulinType: InsulinType) throws {
        // We should already be holding podStateLock during calls to this function, so try() should fail
        assert(!podStateLock.try(), "\(#function) should be invoked while holding podStateLock")

        commandSession.assertOnSessionQueue()

        let packetNumber, messageNumber: Int
        if let podState = self.podState {
            packetNumber = podState.erosMessageTransportState.packetNumber
            messageNumber = podState.erosMessageTransportState.messageNumber
        } else {
            packetNumber = self.startingPacketNumber
            messageNumber = 0
        }

        log.debug("Attempting pairing with address %{public}@ using packet #%d", String(format: "%04X", address), packetNumber)
        let messageTransportState = ErosMessageTransportState(packetNumber: packetNumber, messageNumber: messageNumber)
        let erosPodMessageTransport = ErosPodMessageTransport(session: commandSession, address: 0xffffffff, ackAddress: address, state: messageTransportState)
        erosPodMessageTransport.messageLogger = messageLogger

        // Create the Assign Address command message
        let assignAddress = AssignAddressCommand(address: address)
        let message = Message(address: 0xffffffff, messageBlocks: [assignAddress], sequenceNum: erosPodMessageTransport.messageNumber)

        _ = try erosSendPairMessage(address: address, erosPodMessageTransport: erosPodMessageTransport, message: message, insulinType: insulinType)
    }

    // Eros only
    private func setupPod(podState: PodState, timeZone: TimeZone, commandSession: CommandSession, insulinType: InsulinType) throws {
        // We should already be holding podStateLock during calls to this function, so try() should fail
        assert(!podStateLock.try(), "\(#function) should be invoked while holding podStateLock")

        commandSession.assertOnSessionQueue()

        let erosTransport = ErosPodMessageTransport(session: commandSession, address: 0xffffffff, ackAddress: podState.address, state: podState.erosMessageTransportState)
        erosTransport.messageLogger = messageLogger

        let dateComponents = SetupPodCommand.dateComponents(date: Date(), timeZone: timeZone)
        let setupPod = SetupPodCommand(address: podState.address, dateComponents: dateComponents, lot: podState.lotNo, tid: podState.lotSeq)

        let message = Message(address: 0xffffffff, messageBlocks: [setupPod], sequenceNum: erosTransport.messageNumber)

        let versionResponse: VersionResponse
        do {
            versionResponse = try erosSendPairMessage(address: podState.address, erosPodMessageTransport: erosTransport, message: message, insulinType: insulinType)
        } catch let error {
            if case PodCommsError.podAckedInsteadOfReturningResponse = error {
                log.default("SetupPod acked instead of returning response.")
                if self.podState?.setupProgress.isPaired == false {
                    log.default("Moving pod to paired state.")
                    self.podState?.setupProgress = .podPaired
                }
                return
            }
            log.error("SetupPod returns error %{public}@", String(describing: error))
            throw error
        }

        guard versionResponse.isSetupPodVersionResponse else {
            log.error("SetupPod unexpected VersionResponse type: %{public}@", String(describing: versionResponse))
            throw PodCommsError.invalidData
        }
    }

    // Eros only
    func assignAddressAndSetupPod(
        address: UInt32,
        using deviceSelector: @escaping (_ completion: @escaping (_ device: RileyLinkDevice?) -> Void) -> Void,
        timeZone: TimeZone,
        messageLogger: MessageLogger?,
        insulinType: InsulinType,
        _ block: @escaping (_ result: SessionRunResult) -> Void)
    {
        deviceSelector { (device) in
            guard let device = device else {
                block(.failure(PodCommsError.noRileyLinkAvailable))
                return
            }

            device.runSession(withName: "Pair Pod") { (commandSession) in
                // Synchronize access to podState
                self.podStateLock.lock()
                defer {
                    self.podStateLock.unlock()
                }

                do {

                    self.configureDevice(device, with: commandSession)

                    if self.podState == nil {
                        try self.assignAddress(address: address, commandSession: commandSession, insulinType: insulinType)
                    }

                    guard self.podState != nil else {
                        block(.failure(PodCommsError.noPodPaired))
                        return
                    }

                    if self.podState!.setupProgress.isPaired == false {
                        try self.setupPod(podState: self.podState!, timeZone: timeZone, commandSession: commandSession, insulinType: insulinType)
                    }

                    guard self.podState!.setupProgress.isPaired else {
                        self.log.error("Unexpected podStatus setupProgress value of %{public}@", String(describing: self.podState!.setupProgress))
                        throw PodCommsError.invalidData
                    }
                    self.startingPacketNumber = 0

                    // Run a session now for any post-pairing commands
                    let erosPodMessageTransport = ErosPodMessageTransport(session: commandSession, address: self.podState!.address, state: self.podState!.erosMessageTransportState)
                    erosPodMessageTransport.messageLogger = self.messageLogger
                    let podSession = PodCommsSession(podState: self.podState!, transport: erosPodMessageTransport, delegate: self)

                    block(.success(session: podSession))
                } catch let error as PodCommsError {
                    block(.failure(error))
                } catch {
                    block(.failure(PodCommsError.commsError(error: error)))
                }
            }
        }
    }

    // Eros only - Used to serialize a set of Pod Commands for a given session
    func erosRunSession(withName name: String, using deviceSelector: @escaping (_ completion: @escaping (_ device: RileyLinkDevice?) -> Void) -> Void, _ block: @escaping (_ result: SessionRunResult) -> Void)
    {
        deviceSelector { (device) in
            guard let device = device else {
                block(.failure(PodCommsError.noRileyLinkAvailable))
                return
            }

            device.runSession(withName: name) { (commandSession) in

                // Synchronize access to podState
                self.podStateLock.lock()
                defer {
                    self.podStateLock.unlock()
                }

                guard self.podState != nil else {
                    block(.failure(PodCommsError.noPodPaired))
                    return
                }

                self.configureDevice(device, with: commandSession)
                let erosPodMessageTransport = ErosPodMessageTransport(session: commandSession, address: self.podState!.address, state: self.podState!.erosMessageTransportState)
                erosPodMessageTransport.messageLogger = self.messageLogger
                let podSession = PodCommsSession(podState: self.podState!, transport: erosPodMessageTransport, delegate: self)
                block(.success(session: podSession))
            }
        }
    }

    // Eros only - Must be called from within the RileyLinkDevice sessionQueue
    private func configureDevice(_ device: RileyLinkDevice, with session: CommandSession) {
        session.assertOnSessionQueue()

        guard !self.configuredDevices.value.contains(device.peripheralIdentifier) else {
            return
        }

        do {
            log.debug("configureRadio (omnipod)")
            _ = try session.configureRadio()
        } catch let error {
            log.error("configure Radio failed with error: %{public}@", String(describing: error))
            // Ignore the error and let the block run anyway
            return
        }

        NotificationCenter.default.post(name: .DeviceRadioConfigDidChange, object: device)
        NotificationCenter.default.addObserver(self, selector: #selector(deviceRadioConfigDidChange(_:)), name: .DeviceRadioConfigDidChange, object: device)
        NotificationCenter.default.addObserver(self, selector: #selector(deviceRadioConfigDidChange(_:)), name: .DeviceConnectionStateDidChange, object: device)

        log.debug("added device %{public}@ to configuredDevices", device.name ?? "unknown")
        _ = configuredDevices.mutate { (value) in
            value.insert(device.peripheralIdentifier)
        }
    }

    // Eros only
    @objc private func deviceRadioConfigDidChange(_ note: Notification) {
        guard let device = note.object as? RileyLinkDevice else {
            return
        }
        log.debug("removing device %{public}@ from configuredDevices", device.name ?? "unknown")

        NotificationCenter.default.removeObserver(self, name: .DeviceRadioConfigDidChange, object: device)
        NotificationCenter.default.removeObserver(self, name: .DeviceConnectionStateDidChange, object: device)

        _ = configuredDevices.mutate { (value) in
            value.remove(device.peripheralIdentifier)
        }
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

// RileyLink specific code

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

        let sendPacket = Packet(address: address, packetType: .pdm, sequenceNum: packetNumber, data: dataRemaining)
        dataRemaining = dataRemaining.subdata(in: sendPacket.data.count..<dataRemaining.count)

        let _ = try sendAndListen(sendPacket.encoded(), repeatCount: 0, timeout: .milliseconds(333), retryCount: 0, preambleExtension: .milliseconds(127))

        throw PodCommsError.emptyResponse
    }
}

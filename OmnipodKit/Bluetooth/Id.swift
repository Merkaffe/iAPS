//
//  Id.swift
//  OmnipodKit
//
//  From OmniBLE/OmniBLE/Bluetooth/Id.swift
//  Created by Randall Knutson on 8/5/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import Foundation

// For O5, the controller ID comes from the TLS certificate's pdmid via O5CertificateStore.
// For DASH, the controller ID is randomly generated with the pod type's topIdByte.

class Id: Equatable {

    static func fromInt(_ v: Int) -> Id {
        return Id(Data(bigEndian: v).subdata(in: 4..<8))
    }

    static func fromUInt32(_ v: UInt32) -> Id {
        return Id(Data(bigEndian: v))
    }

    let address: Data

    init(_ address: Data) {
        guard address.count == 4 else {
            // TODO: Should probably throw an error here.
            //        require(address.size == 4)
            self.address = Data([0x00, 0x00, 0x00, 0x00])
            return
        }
        self.address = address
    }

    func toInt64() -> Int64 {
        return address.toBigEndian(Int64.self)
    }

    func toUInt32() -> UInt32 {
        return address.toBigEndian(UInt32.self)
    }

    // MARK: Comparable

    static func == (lhs: Id, rhs: Id) -> Bool {
        return lhs.address == rhs.address
    }
}

/// The Dash PDM uses the PDM's SN shifted left 2 for the bottom 5 nibbles with some
/// unknown values for the top 3 nibbles of its fixed 32-bit controller ID.
/// The Dash & OmniBLE podId's cycle between 3 #'s of controllerId+1, +2, +3, +1, ...
/// OmniBLE faked this by using a random 22-bit number shifted left 2 for the controllerID
/// and using a unique nibble top byte value of 0x17 (similar to Eros using a fixed 0x1F here).
///
/// The O5 PDM also uses the original PDM's SN shifted left 2 for the basis of its controllerId,
/// however this value is stored in the certificate and apparently checked by the pod so it can't
/// be used as a base for a set of rotating podIds that will be semi-unique across for all users.

/// Create the initial controllerId and podId as needed for the given pod type.
/// The controllerId and set of 3 podId's are kept until the pump manager is deleted.
func initializeIds(podType: PodType) -> (controllerId: UInt32, podId: UInt32) {
    let createdControllerId = createControllerId(podType: podType)
    if podType.isO5 {
        /// For the O5, the controllerID must match the certificate's pdmid
        let controllerId = O5CertificateStore.pdmid

        // Far from ideal with a limited # of controllerId's...
        return (controllerId: controllerId, podId: controllerId + 1)

        /// The podIds will rotate between createdControllerId +1, ... +3, +1,...
        /// XXX This scheme isn't working yet as pod gets unhappy after receiving SPS2
        //return (controllerId: controllerId, podId: createdControllerId + 1)
    }

    /// DASH: use a random controllerID with the correct top byte and the bottom 2-bits clear
    /// while the podId will cycle between controllerId+1,+2,+3,+1, ...
    return (controllerId: createdControllerId, podId: createdControllerId + 1)
}

/// The podId's cycle between 3 #'s of +1,+2,+3,+1, ...
/// For far, this seems to be required for O5 pods, but not for DASH pods
func nextPodId(lastPodId: UInt32) -> UInt32 {
    let bitMask: UInt32 = 0b11
    if (lastPodId & bitMask) == bitMask {
        // start over at the base + 1
        return (lastPodId & ~bitMask) + 1
    }
    // return the next sequential podId #
    return lastPodId + 1
}

/// Creates a base controllerId to be used directly (DASH) or as a fake
/// controllerId base to be used as the base for the rotating podId's (O5).
/// The top byte will be set for the given pod type, the bottom 2 bits will be
/// clear for use with the cycling 3 podIds, while the other 22 bits are random.
private func createControllerId(podType: PodType) -> UInt32 {
    return (UInt32(podType.topIdByte) << 24) | ((arc4random() & 0x003FFFFF) << 2)
}

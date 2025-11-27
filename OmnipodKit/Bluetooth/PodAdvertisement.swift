//
//  PodAdvertisement.swift
//  OmnipodKit
//
//  From OmniBLE/OmniBLE/PumpManager/PodAdvertisement.swift
//  Created by Pete Schwamb on 1/13/22.
//  Copyright © 2022 LoopKit Authors. All rights reserved.
//

import Foundation
import CoreBluetooth

extension String {
    func subString(location: Int, length: Int? = nil) -> String {
      let start = min(max(0, location), self.count)
      let limitedLength = min(self.count - start, length ?? Int.max)
      let from = index(startIndex, offsetBy: start)
      let to = index(startIndex, offsetBy: start + limitedLength)
      return String(self[from..<to])
    }
}

struct PodAdvertisement {
    let MAIN_SERVICE_UUID = "4024"
    let UNKNOWN_THIRD_SERVICE_UUID = "000A"

    var sequenceNo: UInt32
    var lotNo: UInt64
    var podId: UInt32
    var podType: PodType

    var serviceUUIDs: [CBUUID]

    var pairable: Bool {
        if podType == dashType {
            return serviceUUIDs.count >= 5 && serviceUUIDs[3].uuidString.uppercased() == "FFFF" && serviceUUIDs[4].uuidString.uppercased() == "FFFE"
        }

        if podType != omnipod5Type {
            return false
        }

        guard serviceUUIDs.count >= 1 else {
            return false
        }

        let advertisementString = serviceUUIDs[0].uuidString
        // "CE1F923D-C539-48EA-7300-0Afffffffe00"
        //  012345678901234567890123456789012345

        guard strlen(advertisementString) == 36 else {
            return false
        }

        // The podId still has to be 0xFFFFFFFE to be pairable
        let podIdString = advertisementString.subString(location: 26, length : 8).uppercased()
        guard podIdString.uppercased() == "FFFFFFFE" else {
            return false
        }

        // verify anything else in the advertisement?

        return true
    }

    init?(_ advertisementData: [String: Any], podType: PodType) {
        guard let serviceUUIDs = advertisementData["kCBAdvDataServiceUUIDs"] as? [CBUUID] else {
            return nil
        }

        self.serviceUUIDs = serviceUUIDs
        self.podType = podType

        switch podType {
        case dashType:
            guard serviceUUIDs.count == 9 else {
                return nil
            }

            guard serviceUUIDs[0].uuidString == MAIN_SERVICE_UUID else {
                return nil
            }

            // TODO understand what is serviceUUIDs[1]. 0x2470.
            guard serviceUUIDs[2].uuidString == UNKNOWN_THIRD_SERVICE_UUID else {
                return nil
            }

            guard let decodedPodId = UInt32(serviceUUIDs[3].uuidString + serviceUUIDs[4].uuidString, radix: 16) else {
                return nil
            }
            podId = decodedPodId

            let lotNoString: String = serviceUUIDs[5].uuidString + serviceUUIDs[6].uuidString + serviceUUIDs[7].uuidString
            guard let decodedLotNo = UInt64(lotNoString[lotNoString.startIndex..<lotNoString.index(lotNoString.startIndex, offsetBy: 10)], radix: 16) else {
                return nil
            }
            lotNo = decodedLotNo

            let lotSeqString: String = serviceUUIDs[7].uuidString + serviceUUIDs[8].uuidString
            guard let decodedSeqNo = UInt32(lotSeqString[lotSeqString.index(lotSeqString.startIndex, offsetBy: 2)..<lotSeqString.endIndex], radix: 16) else {
                return nil
            }
            sequenceNo = decodedSeqNo

        case omnipod5Type:
            // "AP "+strings.ToUpper(hex.EncodeToString(podIdArray))+" 0A95B6110002761B" after id set

            // serviceUUIDs.count[0] is "CE1F923D-C539-48EA-7300-0AFFFFFFFE00"
            guard serviceUUIDs.count == 1 else {
                return nil
            }

            let idString = serviceUUIDs[0].uuidString
            guard strlen(idString) == 36 else {
                print("Unexpected length of UUID string: \(idString): \(strlen(idString))")
                return nil
            }

            // idString is "CE1F923D-C539-48EA-7300-0AFFFFFFFE00"
            //              012345678901234567890123456789012345
            //                        1         2         3
            let podIdStr = idString.subString(location: 26, length: 8)
            guard let decodedPodId = UInt32(podIdStr, radix: 16) else {
                print("Could not decode podId from \(idString)")
                return nil
            }
            podId = decodedPodId

            lotNo = 0 // JJJ
            sequenceNo = 0 // JJJ

            /* JJJ need to figure this out...
            // 32 bit lot or 64 bit lot #???
            let lotNoString: String = idString.subString(location: X1, length: Y1)
            guard let decodedLotNo = UInt64(lotNoString[lotNoString.startIndex..<lotNoString.index(lotNoString.startIndex, offsetBy: Z1)], radix: 16) else {
                return nil
            }
            lotNo = decodedLotNo

            let lotSeqString: String = idString.subString(location: X2, length: Y2)
            guard let decodedSeqNo = UInt32(lotSeqString[lotSeqString.index(lotSeqString.startIndex, offsetBy: Z2)..<lotSeqString.endIndex], radix: 16) else {
                return nil
            }
            sequenceNo = decodedSeqNo
            JJJ */

        default:
            return nil
        }
    }
}

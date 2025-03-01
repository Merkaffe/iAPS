//
//  IdentifiableClass.swift
//  OmnipodKit
//
//  From OmniBLE/Commmon/IdentifiableClass.swift
//  Created by Nathan Racklyeft on 2/9/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation

protocol IdentifiableClass: AnyObject {
    static var className: String { get }
}


extension IdentifiableClass {
    static var className: String {
        return NSStringFromClass(self).components(separatedBy: ".").last!
    }
}

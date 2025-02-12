//
//  NibLoadable.swift
//  OmniCore
//
//  From OmniBLE/Common/NibLoadable.swift
//  Created by Nate Racklyeft on 7/2/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit

protocol NibLoadable: IdentifiableClass {
    static func nib() -> UINib
}

extension NibLoadable {
    static func nib() -> UINib {
        let x = UINib(nibName: className, bundle: Bundle(for: self))
        return x
    }
}

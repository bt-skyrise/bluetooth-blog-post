//
//  Const.swift
//  GATT
//
//  Created by Konrad Roj on 24.11.2017.
//  Copyright © 2017 Skyrise.tech. All rights reserved.
//

import Foundation
import CoreBluetooth

struct GattUUID {
    static let service = CBUUID(string:"00010000-89BD-43C8-9231-40F6E305F96D")
    static let arg1 = CBUUID(string:"00010001-89BD-43C8-9231-40F6E305F96D")
    static let arg2 = CBUUID(string:"00010002-89BD-43C8-9231-40F6E305F96D")
    static let result = CBUUID(string:"00010010-89BD-43C8-9231-40F6E305F96D")
    
    static let name = "Calculator"
}

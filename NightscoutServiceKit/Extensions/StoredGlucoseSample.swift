//
//  StoredGlucoseSample.swift
//  NightscoutServiceKit
//
//  Created by Darin Krauss on 10/13/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import LoopKit
import NightscoutUploadKit

extension StoredGlucoseSample {

    var nightscoutEntry: NightscoutEntry {
        return NightscoutEntry(
            glucose: Int(quantity.doubleValue(for: .milligramsPerDeciliter)),
            timestamp: startDate,
            device: "loop://\(UIDevice.current.name)",
            glucoseType: .Sensor
        )
    }

}

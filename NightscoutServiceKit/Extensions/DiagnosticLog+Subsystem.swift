//
//  DiagnosticLog+Subsystem.swift
//  NightscoutServiceKit
//
//  Created by Darin Krauss on 9/18/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import LoopKit


extension DiagnosticLog {

    convenience init(category: String) {
        self.init(subsystem: "com.loopkit.NightscoutService", category: category)
    }

}

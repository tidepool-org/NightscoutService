//
//  PersistedPumpEvent.swift
//  NightscoutServiceKit
//
//  Created by Pete Schwamb on 9/23/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit

import NightscoutKit

extension PersistedPumpEvent {

    func treatment(source: String) -> NightscoutTreatment? {
        switch type {
        case .replaceComponent(let componentType):
            switch componentType {
            case .infusionSet, .pump:
                let note = title
                return NightscoutTreatment(timestamp: date, enteredBy: source, notes: note, eventType: .siteChange)
            default:
                return nil
            }
        default:
            return nil
        }
    }
}

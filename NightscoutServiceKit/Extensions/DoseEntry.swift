//
//  DoseEntry.swift
//  NightscoutServiceKit
//
//  Created by Darin Krauss on 6/20/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import LoopKit
import NightscoutUploadKit

extension DoseEntry {

    func treatment(enteredBy source: String) -> NightscoutTreatment? {
        switch type {
        case .basal:
            return nil
        case .bolus:
            let duration = endDate.timeIntervalSince(startDate)

            return BolusNightscoutTreatment(
                timestamp: startDate,
                enteredBy: source,
                bolusType: duration > 0 ? .Square : .Normal,
                amount: deliveredUnits ?? programmedUnits,
                programmed: programmedUnits,  // Persisted pump events are always completed
                unabsorbed: 0,  // The pump's reported IOB isn't relevant, nor stored
                duration: duration,
                carbs: 0,
                ratio: 0,
                id: syncIdentifier
            )
        case .resume:
            return PumpResumeTreatment(timestamp: startDate, enteredBy: source)
        case .suspend:
            return PumpSuspendTreatment(timestamp: startDate, enteredBy: source)
        case .tempBasal:
            return TempBasalNightscoutTreatment(
                timestamp: startDate,
                enteredBy: source,
                temp: .Absolute,  // DoseEntry only supports .absolute types
                rate: unitsPerHour,
                absolute: unitsPerHour,
                duration: endDate.timeIntervalSince(startDate),
                amount: deliveredUnits,
                id: syncIdentifier
            )
        }
    }

}

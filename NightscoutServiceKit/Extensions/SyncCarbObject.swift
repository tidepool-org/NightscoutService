//
//  StoredCarbEntry.swift
//  NightscoutServiceKit
//
//  Created by Darin Krauss on 6/20/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit
import NightscoutUploadKit
import HealthKit

extension SyncCarbObject {

    var mealBolusNightscoutTreatment: MealBolusNightscoutTreatment? {
        guard let nightscoutIdentifier = nightscoutIdentifier else {
            return nil
        }

        return MealBolusNightscoutTreatment(timestamp: startDate,
            enteredBy: "loop://\(UIDevice.current.name)",
            id: nightscoutIdentifier,
            carbs: lround(grams),
            absorptionTime: absorptionTime,
            foodType: foodType)
    }

}

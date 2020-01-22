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

extension StoredCarbEntry {

    var mealBolusNightscoutTreatment: MealBolusNightscoutTreatment {
        return MealBolusNightscoutTreatment(timestamp: startDate,
            enteredBy: "loop://\(UIDevice.current.name)",
            id: nightscoutIdentifier,
            carbs: lround(quantity.doubleValue(for: HKUnit.gram())),
            absorptionTime: absorptionTime,
            foodType: foodType)
    }

}

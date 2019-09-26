//
//  MealBolusNightscoutTreatment.swift
//  NightscoutServiceKit
//
//  Created by Darin Krauss on 6/20/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit
import NightscoutUploadKit
import HealthKit

extension MealBolusNightscoutTreatment {

    convenience init(carbEntry: StoredCarbEntry) {
        let carbGrams = carbEntry.quantity.doubleValue(for: HKUnit.gram())
        self.init(timestamp: carbEntry.startDate, enteredBy: "loop://\(UIDevice.current.name)", id: carbEntry.externalID, carbs: lround(carbGrams), absorptionTime: carbEntry.absorptionTime, foodType: carbEntry.foodType)
    }
    
}

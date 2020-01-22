//
//  StoredSettings.swift
//  NightscoutServiceKit
//
//  Created by Darin Krauss on 10/17/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import HealthKit
import LoopKit
import NightscoutUploadKit

extension StoredSettings {

    var loopSettings: NightscoutUploadKit.LoopSettings? {
        guard let glucoseUnit = glucoseUnit else {
            return nil
        }

        var nightscoutPreMealTargetRange: ClosedRange<Double>?
        if let preMealTargetRange = preMealTargetRange {
            nightscoutPreMealTargetRange = ClosedRange(uncheckedBounds: (
                lower: preMealTargetRange.minValue,
                upper: preMealTargetRange.maxValue))
        }

        return NightscoutUploadKit.LoopSettings(
            dosingEnabled: dosingEnabled,
            overridePresets: overridePresets.map { $0.nsScheduleOverride(for: glucoseUnit) },
            scheduleOverride: scheduleOverride?.nsScheduleOverride(for: glucoseUnit),
            minimumBGGuard: suspendThreshold?.quantity.doubleValue(for: glucoseUnit),
            preMealTargetRange: nightscoutPreMealTargetRange,
            maximumBasalRatePerHour: maximumBasalRatePerHour,
            maximumBolus: maximumBolus,
            deviceToken: deviceToken,
            bundleIdentifier: bundleIdentifier)
    }

    var profile: ProfileSet.Profile? {
        guard let basalRateSchedule = basalRateSchedule,
            let insulinModel = insulinModel,
            let carbRatioSchedule = carbRatioSchedule,
            let insulinSensitivitySchedule = insulinSensitivitySchedule,
            let glucoseTargetRangeSchedule = glucoseTargetRangeSchedule else
        {
            return nil
        }

        let targetLowItems = glucoseTargetRangeSchedule.items.map { item -> ProfileSet.ScheduleItem in
            return ProfileSet.ScheduleItem(offset: item.startTime, value: item.value.minValue)
        }

        let targetHighItems = glucoseTargetRangeSchedule.items.map { item -> ProfileSet.ScheduleItem in
            return ProfileSet.ScheduleItem(offset: item.startTime, value: item.value.maxValue)
        }

        return ProfileSet.Profile(
            timezone: basalRateSchedule.timeZone,
            dia: insulinModel.effectDuration,
            sensitivity: insulinSensitivitySchedule.items.scheduleItems(),
            carbratio: carbRatioSchedule.items.scheduleItems(),
            basal: basalRateSchedule.items.scheduleItems(),
            targetLow: targetLowItems,
            targetHigh: targetHighItems,
            units: glucoseTargetRangeSchedule.unit.shortLocalizedUnitString())
    }

    var profileSet: ProfileSet? {
        guard let glucoseUnit = glucoseUnit, let profile = profile, let loopSettings = loopSettings else {
            return nil
        }

        return ProfileSet(
            startDate: date,
            units: glucoseUnit.shortLocalizedUnitString(),
            enteredBy: "Loop",
            defaultProfile: "Default",
            store: ["Default": profile],
            settings: loopSettings)
    }

}

fileprivate extension Array where Element == RepeatingScheduleValue<Double> {

    func scheduleItems() -> [ProfileSet.ScheduleItem] {
        return map { item -> ProfileSet.ScheduleItem in
            return ProfileSet.ScheduleItem(offset: item.startTime, value: item.value)
        }
    }

}

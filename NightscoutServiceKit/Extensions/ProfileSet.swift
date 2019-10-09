//
//  ProfileSet.swift
//  NightscoutServiceKit
//
//  Created by Darin Krauss on 10/17/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import HealthKit
import LoopKit
import NightscoutUploadKit

extension ProfileSet {

    convenience init?(storedSettings: StoredSettings) {
        guard
            let basalRateSchedule = storedSettings.basalRateSchedule,
            let insulinModel = storedSettings.insulinModel,
            let carbRatioSchedule = storedSettings.carbRatioSchedule,
            let insulinSensitivitySchedule = storedSettings.insulinSensitivitySchedule,
            let preferredUnit = storedSettings.glucoseUnit,
            let correctionSchedule = storedSettings.glucoseTargetRangeSchedule else
        {
            return nil
        }

        let targetLowItems = correctionSchedule.items.map { item -> ProfileSet.ScheduleItem in
            return ProfileSet.ScheduleItem(offset: item.startTime, value: item.value.minValue)
        }

        let targetHighItems = correctionSchedule.items.map { item -> ProfileSet.ScheduleItem in
            return ProfileSet.ScheduleItem(offset: item.startTime, value: item.value.maxValue)
        }

        let nsScheduledOverride = storedSettings.scheduleOverride?.nsScheduleOverride(for: preferredUnit)

        let nsPreMealTargetRange: ClosedRange<Double>?
        if let preMealTargetRange = storedSettings.preMealTargetRange {
            nsPreMealTargetRange = ClosedRange(uncheckedBounds: (
                lower: preMealTargetRange.minValue,
                upper: preMealTargetRange.maxValue))
        } else {
            nsPreMealTargetRange = nil
        }

        let nsLoopSettings = NightscoutUploadKit.LoopSettings(
            dosingEnabled: storedSettings.dosingEnabled,
            overridePresets: storedSettings.overridePresets.map { $0.nsScheduleOverride(for: preferredUnit) },
            scheduleOverride: nsScheduledOverride,
            minimumBGGuard: storedSettings.suspendThreshold?.quantity.doubleValue(for: preferredUnit),
            preMealTargetRange: nsPreMealTargetRange,
            maximumBasalRatePerHour: storedSettings.maximumBasalRatePerHour,
            maximumBolus: storedSettings.maximumBolus,
            deviceToken: storedSettings.deviceToken,
            bundleIdentifier: storedSettings.bundleIdentifier)

        let profile = ProfileSet.Profile(
            timezone: basalRateSchedule.timeZone,
            dia: insulinModel.effectDuration,
            sensitivity: insulinSensitivitySchedule.items.scheduleItems(),
            carbratio: carbRatioSchedule.items.scheduleItems(),
            basal: basalRateSchedule.items.scheduleItems(),
            targetLow: targetLowItems,
            targetHigh: targetHighItems,
            units: correctionSchedule.unit.shortLocalizedUnitString())

        let store: [String: ProfileSet.Profile] = [
            "Default": profile
        ]

        self.init(
            startDate: storedSettings.date,
            units: preferredUnit.shortLocalizedUnitString(),
            enteredBy: "Loop",
            defaultProfile: "Default",
            store: store,
            settings: nsLoopSettings)
    }

}

fileprivate extension Array where Element == RepeatingScheduleValue<Double> {

    func scheduleItems() -> [ProfileSet.ScheduleItem] {
        return map { item -> ProfileSet.ScheduleItem in
            return ProfileSet.ScheduleItem(offset: item.startTime, value: item.value)
        }
    }

}

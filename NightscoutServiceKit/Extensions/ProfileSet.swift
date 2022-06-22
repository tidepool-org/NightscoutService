//
//  ProfileSet.swift
//  NightscoutServiceKit
//
//  Created by Pete Schwamb on 2/21/22.
//  Copyright © 2022 LoopKit Authors. All rights reserved.
//

import Foundation
import NightscoutUploadKit
import LoopKit
import HealthKit

extension ProfileSet {
    var therapySettings: TherapySettings? {
        guard let profile = store["Default"] else {
            // no default profile stored
            return nil
        }

        guard let glucoseSafetyLimit = settings.minimumBGGuard else {
            return nil
        }

        let glucoseUnit: HKUnit
        if units == "mmol/L" {
            glucoseUnit = .millimolesPerLiter
        } else {
            glucoseUnit = .milligramsPerDeciliter
        }

        let targetItems: [RepeatingScheduleValue<DoubleRange>] = zip(profile.targetLow, profile.targetHigh).map { (low,high) in
            return RepeatingScheduleValue(startTime: low.offset, value: DoubleRange(minValue: low.value, maxValue: high.value))
        }

        let targetRangeSchedule = GlucoseRangeSchedule(unit: .milligramsPerDeciliter, dailyItems: targetItems, timeZone: profile.timeZone)

        let correctionRangeOverrides: CorrectionRangeOverrides?
        if let range = settings.preMealTargetRange {
            correctionRangeOverrides = CorrectionRangeOverrides(
                preMeal: GlucoseRange(minValue: range.lowerBound, maxValue: range.upperBound, unit: glucoseUnit),
                workout: nil // No longer used
            )
        } else {
            correctionRangeOverrides = nil
        }

        let basalSchedule = BasalRateSchedule(
            dailyItems: profile.basal.map { RepeatingScheduleValue(startTime: $0.offset, value: $0.value) },
            timeZone: profile.timeZone)

        let sensitivitySchedule = InsulinSensitivitySchedule(
            unit: glucoseUnit,
            dailyItems: profile.sensitivity.map { RepeatingScheduleValue(startTime: $0.offset, value: $0.value) },
            timeZone: profile.timeZone)

        let carbSchedule = CarbRatioSchedule(
            unit: .gram(),
            dailyItems: profile.carbratio.map { RepeatingScheduleValue(startTime: $0.offset, value: $0.value) },
            timeZone: profile.timeZone)


        return TherapySettings(
            glucoseTargetRangeSchedule: targetRangeSchedule,
            correctionRangeOverrides: correctionRangeOverrides,
            overridePresets: settings.overridePresets.compactMap { $0.loopOverride(for: glucoseUnit) },
            maximumBasalRatePerHour: settings.maximumBasalRatePerHour,
            maximumBolus: settings.maximumBolus,
            suspendThreshold: GlucoseThreshold(unit: glucoseUnit, value: glucoseSafetyLimit),
            insulinSensitivitySchedule: sensitivitySchedule,
            carbRatioSchedule: carbSchedule,
            basalRateSchedule: basalSchedule,
            defaultRapidActingModel: nil) // Not stored in NS yet
    }
}


extension NightscoutUploadKit.TemporaryScheduleOverride  {

    func loopOverride(for unit: HKUnit) -> LoopKit.TemporaryScheduleOverridePreset? {
        guard let name = name,
            let symbol = symbol
        else {
            return nil
        }

        let target: DoubleRange?
        if let lowerBound = targetRange?.lowerBound,
           let upperBound = targetRange?.upperBound
        {
            target = DoubleRange(minValue: lowerBound, maxValue: upperBound)
        } else {
            target = nil
        }

        let temporaryOverrideSettings = TemporaryScheduleOverrideSettings(
            unit: unit,
            targetRange: target,
            insulinNeedsScaleFactor: insulinNeedsScaleFactor)

        let loopDuration: LoopKit.TemporaryScheduleOverride.Duration

        if duration == 0 {
            loopDuration = .indefinite
        } else {
            loopDuration = .finite(duration)
        }

        return TemporaryScheduleOverridePreset(
            symbol: symbol,
            name: name,
            settings: temporaryOverrideSettings,
            duration: loopDuration)
    }
}

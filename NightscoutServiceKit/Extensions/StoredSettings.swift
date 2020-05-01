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
        guard let bloodGlucoseUnit = bloodGlucoseUnit else {
            return nil
        }

        var nightscoutPreMealTargetRange: ClosedRange<Double>?
        if let preMealTargetRange = preMealTargetRange {
            nightscoutPreMealTargetRange = ClosedRange(uncheckedBounds: (
                lower: preMealTargetRange.minValue,
                upper: preMealTargetRange.maxValue))
        }

        var deviceTokenData: Data?
        if let deviceToken = deviceToken {
            deviceTokenData = Data(hexadecimalString: deviceToken)
        }

        return NightscoutUploadKit.LoopSettings(
            dosingEnabled: dosingEnabled,
            overridePresets: overridePresets?.map { $0.nsScheduleOverride(for: bloodGlucoseUnit) } ?? [],
            scheduleOverride: scheduleOverride?.nsScheduleOverride(for: bloodGlucoseUnit),
            minimumBGGuard: suspendThreshold?.quantity.doubleValue(for: bloodGlucoseUnit),
            preMealTargetRange: nightscoutPreMealTargetRange,
            maximumBasalRatePerHour: maximumBasalRatePerHour,
            maximumBolus: maximumBolus,
            deviceToken: deviceTokenData,
            bundleIdentifier: Bundle.main.bundleIdentifier)
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
            dia: insulinModel.actionDuration,
            sensitivity: insulinSensitivitySchedule.items.scheduleItems(),
            carbratio: carbRatioSchedule.items.scheduleItems(),
            basal: basalRateSchedule.items.scheduleItems(),
            targetLow: targetLowItems,
            targetHigh: targetHighItems,
            units: glucoseTargetRangeSchedule.unit.shortLocalizedUnitString())
    }

    var profileSet: ProfileSet? {
        guard let bloodGlucoseUnit = bloodGlucoseUnit, let profile = profile, let loopSettings = loopSettings else {
            return nil
        }

        return ProfileSet(
            startDate: date,
            units: bloodGlucoseUnit.shortLocalizedUnitString(),
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

// String conversion methods, adapted from https://stackoverflow.com/questions/40276322/hex-binary-string-conversion-in-swift/40278391#40278391
fileprivate extension Data {
    init?(hexadecimalString: String) {
        self.init(capacity: hexadecimalString.utf16.count / 2)

        // Convert 0 ... 9, a ... f, A ...F to their decimal value,
        // return nil for all other input characters
        func decodeNibble(u: UInt16) -> UInt8? {
            switch u {
            case 0x30 ... 0x39:  // '0'-'9'
                return UInt8(u - 0x30)
            case 0x41 ... 0x46:  // 'A'-'F'
                return UInt8(u - 0x41 + 10)  // 10 since 'A' is 10, not 0
            case 0x61 ... 0x66:  // 'a'-'f'
                return UInt8(u - 0x61 + 10)  // 10 since 'a' is 10, not 0
            default:
                return nil
            }
        }

        var even = true
        var byte: UInt8 = 0
        for c in hexadecimalString.utf16 {
            guard let val = decodeNibble(u: c) else { return nil }
            if even {
                byte = val << 4
            } else {
                byte += val
                self.append(byte)
            }
            even = !even
        }
        guard even else { return nil }
    }
}

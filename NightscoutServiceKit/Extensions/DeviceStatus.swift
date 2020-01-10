//
//  DeviceStatus.swift
//  NightscoutServiceKit
//
//  Created by Darin Krauss on 10/17/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit
import LoopKit
import NightscoutUploadKit

extension DeviceStatus {

    init(storedDosingDecision: StoredDosingDecision) {
        var iob: IOBStatus?
        if let insulinOnBoard = storedDosingDecision.insulinOnBoard {
            iob = IOBStatus(timestamp: insulinOnBoard.startDate, iob: insulinOnBoard.value)
        }

        var cob: COBStatus?
        if let carbsOnBoard = storedDosingDecision.carbsOnBoard {
            cob = COBStatus(cob: carbsOnBoard.quantity.doubleValue(for: HKUnit.gram()), timestamp: carbsOnBoard.startDate)
        }

        var predicted: PredictedBG?
        if let predictedGlucose = storedDosingDecision.predictedGlucose, let startDate = predictedGlucose.first?.startDate {
            let values = predictedGlucose.map { $0.quantity }
            predicted = PredictedBG(startDate: startDate, values: values)
        }

        var recommended: RecommendedTempBasal?
        if let tempBasalRecommendationDate = storedDosingDecision.tempBasalRecommendationDate {
            recommended = RecommendedTempBasal(timestamp: tempBasalRecommendationDate.date, rate: tempBasalRecommendationDate.recommendation.unitsPerHour, duration: tempBasalRecommendationDate.recommendation.duration)
        }

        var loopEnacted: LoopEnacted?
        if case .some(.tempBasal(let tempBasal)) = storedDosingDecision.pumpManagerStatus?.basalDeliveryState /*, lastTempBasalUploaded?.startDate != tempBasal.startDate  TODO: How to address this? */ {
            let duration = tempBasal.endDate.timeIntervalSince(tempBasal.startDate)
            loopEnacted = LoopEnacted(rate: tempBasal.unitsPerHour, duration: duration, timestamp: tempBasal.startDate, received:
                true)
//            lastTempBasalUploaded = tempBasal // TODO: How to address this?
        }

        let loopName = Bundle.main.bundleDisplayName
        let loopVersion = Bundle.main.shortVersionString

        //this is the only pill that has the option to modify the text
        //to do that pass a different name value instead of loopName
        let loopStatus = LoopStatus(name: loopName, version: loopVersion, timestamp: storedDosingDecision.date, iob: iob, cob: cob, predicted: predicted, recommendedTempBasal: recommended, recommendedBolus: storedDosingDecision.recommendedBolus, enacted: loopEnacted, failureReason: storedDosingDecision.error)

        let pumpStatus: PumpStatus?

        if let pumpManagerStatus = storedDosingDecision.pumpManagerStatus {

            let battery: BatteryStatus?

            if let chargeRemaining = pumpManagerStatus.pumpBatteryChargeRemaining {
                battery = BatteryStatus(percent: Int(round(chargeRemaining * 100)), voltage: nil, status: nil)
            } else {
                battery = nil
            }

            let bolusing: Bool
            if case .inProgress = pumpManagerStatus.bolusState {
                bolusing = true
            } else {
                bolusing = false
            }

            let currentReservoirUnits: Double?
            if let lastReservoirValue = storedDosingDecision.lastReservoirValue, lastReservoirValue.startDate > Date().addingTimeInterval(.minutes(-15)) {
                currentReservoirUnits = lastReservoirValue.unitVolume
            } else {
                currentReservoirUnits = nil
            }

            pumpStatus = PumpStatus(
                clock: storedDosingDecision.date,
                pumpID: pumpManagerStatus.device.localIdentifier ?? "Unknown",
                manufacturer: pumpManagerStatus.device.manufacturer,
                model: pumpManagerStatus.device.model,
                iob: nil,
                battery: battery,
                suspended: pumpManagerStatus.basalDeliveryState.isSuspended,
                bolusing: bolusing,
                reservoir: currentReservoirUnits,
                secondsFromGMT: pumpManagerStatus.timeZone.secondsFromGMT())
        } else {
            pumpStatus = nil
        }

        let overrideStatus: NightscoutUploadKit.OverrideStatus?
        let unit: HKUnit = storedDosingDecision.glucoseTargetRangeSchedule?.unit ?? HKUnit.milligramsPerDeciliter
        if let override = storedDosingDecision.scheduleOverride, override.isActive(),
            let range = storedDosingDecision.glucoseTargetRangeScheduleApplyingOverrideIfActive?.value(at: storedDosingDecision.date) {
            let lowerTarget = HKQuantity(unit: unit, doubleValue: range.minValue)
            let upperTarget = HKQuantity(unit: unit, doubleValue: range.maxValue)
            let correctionRange = CorrectionRange(minValue: lowerTarget, maxValue: upperTarget)
            let endDate = override.endDate
            let duration: TimeInterval?
            if override.duration == .indefinite {
                duration = nil
            } else {
                duration = round(endDate.timeIntervalSince(storedDosingDecision.date))
            }
            overrideStatus = NightscoutUploadKit.OverrideStatus(name: override.context.name, timestamp: storedDosingDecision.date, active: true, currentCorrectionRange: correctionRange, duration: duration, multiplier: override.settings.insulinNeedsScaleFactor)
        } else {
            overrideStatus = NightscoutUploadKit.OverrideStatus(timestamp: storedDosingDecision.date, active: false)
        }

        let uploaderDevice = UIDevice.current

        let battery = uploaderDevice.isBatteryMonitoringEnabled ? Int(uploaderDevice.batteryLevel * 100) : 0

        let uploaderStatus = UploaderStatus(name: uploaderDevice.name, timestamp: storedDosingDecision.date, battery: battery)

        self.init(
            device: "loop://\(uploaderDevice.name)",
            timestamp: storedDosingDecision.date,
            pumpStatus: pumpStatus,
            uploaderStatus: uploaderStatus,
            loopStatus: loopStatus,
            overrideStatus: overrideStatus)
    }

}

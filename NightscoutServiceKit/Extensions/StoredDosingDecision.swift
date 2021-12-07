//
//  StoredDosingDecision.swift
//  NightscoutServiceKit
//
//  Created by Darin Krauss on 10/17/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit
import LoopKit
import NightscoutUploadKit

extension StoredDosingDecision {
    
    var loopStatusIOB: IOBStatus? {
        guard let insulinOnBoard = insulinOnBoard else {
            return nil
        }
        return IOBStatus(timestamp: insulinOnBoard.startDate, iob: insulinOnBoard.value)
    }
    
    var loopStatusCOB: COBStatus? {
        guard let carbsOnBoard = carbsOnBoard else {
            return nil
        }
        return COBStatus(cob: carbsOnBoard.quantity.doubleValue(for: HKUnit.gram()), timestamp: carbsOnBoard.startDate)
    }
    
    var loopStatusPredicted: PredictedBG? {
        guard let predictedGlucose = predictedGlucose, let startDate = predictedGlucose.first?.startDate else {
            return nil
        }
        return PredictedBG(startDate: startDate, values: predictedGlucose.map { $0.quantity })
    }
    
    var loopStatusAutomaticDoseRecommendation: NightscoutUploadKit.AutomaticDoseRecommendation? {
        guard let automaticDoseRecommendation = automaticDoseRecommendation else {
            return nil
        }
        
        let nightscoutTempBasalAdjustment: TempBasalAdjustment?
        
        if let basalAdjustment = automaticDoseRecommendation.basalAdjustment {
            nightscoutTempBasalAdjustment = TempBasalAdjustment(rate: basalAdjustment.unitsPerHour, duration: basalAdjustment.duration)
        } else {
            nightscoutTempBasalAdjustment = nil
        }
        
        return NightscoutUploadKit.AutomaticDoseRecommendation(
            timestamp: date,
            tempBasalAdjustment: nightscoutTempBasalAdjustment,
            bolusVolume: automaticDoseRecommendation.bolusUnits ?? 0)
    }

    var loopStatusRecommendedBolus: Double? {
        guard let manualBolusRecommendation = manualBolusRecommendation else {
            return nil
        }
        return manualBolusRecommendation.recommendation.amount
    }
    
    var loopStatusEnacted: LoopEnacted? {
        guard case .some(.tempBasal(let tempBasal)) = pumpManagerStatus?.basalDeliveryState else {
            return nil
        }
        let duration = tempBasal.endDate.timeIntervalSince(tempBasal.startDate)
        return LoopEnacted(rate: tempBasal.unitsPerHour, duration: duration, timestamp: tempBasal.startDate, received: true)
    }

    var loopStatusFailureReason: String? {
        return errors.first?.description
    }
    
    var loopStatus: LoopStatus {
        return LoopStatus(name: Bundle.main.bundleDisplayName,
                          version: Bundle.main.fullVersionString,
                          timestamp: date,
                          iob: loopStatusIOB,
                          cob: loopStatusCOB,
                          predicted: loopStatusPredicted,
                          automaticDoseRecommendation: loopStatusAutomaticDoseRecommendation,
                          recommendedBolus: loopStatusRecommendedBolus,
                          enacted: loopStatusEnacted,
                          failureReason: loopStatusFailureReason)
    }
    
    var pumpStatusBattery: BatteryStatus? {
        guard let pumpBatteryChargeRemaining = pumpManagerStatus?.pumpBatteryChargeRemaining else {
            return nil
        }
        return BatteryStatus(percent: Int(round(pumpBatteryChargeRemaining * 100)), voltage: nil, status: nil)
    }
    
    var pumpStatusBolusing: Bool {
        guard let pumpManagerStatus = pumpManagerStatus, case .inProgress = pumpManagerStatus.bolusState else {
            return false
        }
        return true
    }
    
    var pumpStatusReservoir: Double? {
        guard let lastReservoirValue = lastReservoirValue, lastReservoirValue.startDate > Date().addingTimeInterval(.minutes(-15)) else {
            return nil
        }
        return lastReservoirValue.unitVolume
    }
    
    var pumpStatus: PumpStatus? {
        guard let pumpManagerStatus = pumpManagerStatus else {
            return nil
        }
        return PumpStatus(
            clock: date,
            pumpID: pumpManagerStatus.device.localIdentifier ?? "Unknown",
            manufacturer: pumpManagerStatus.device.manufacturer,
            model: pumpManagerStatus.device.model,
            iob: nil,
            battery: pumpStatusBattery,
            suspended: pumpManagerStatus.basalDeliveryState?.isSuspended,
            bolusing: pumpStatusBolusing,
            reservoir: pumpStatusReservoir,
            secondsFromGMT: pumpManagerStatus.timeZone.secondsFromGMT())
    }
    
    var overrideStatus: NightscoutUploadKit.OverrideStatus {
        guard let scheduleOverride = scheduleOverride, scheduleOverride.isActive(),
            let glucoseTargetRange = glucoseTargetRangeSchedule?.value(at: date) else
        {
            return NightscoutUploadKit.OverrideStatus(timestamp: date, active: false)
        }
        
        let unit = glucoseTargetRangeSchedule?.unit ?? HKUnit.milligramsPerDeciliter
        let lowerTarget = HKQuantity(unit: unit, doubleValue: glucoseTargetRange.minValue)
        let upperTarget = HKQuantity(unit: unit, doubleValue: glucoseTargetRange.maxValue)
        let currentCorrectionRange = CorrectionRange(minValue: lowerTarget, maxValue: upperTarget)
        let duration = scheduleOverride.duration != .indefinite ? round(scheduleOverride.actualEndDate.timeIntervalSince(date)): nil
        
        return NightscoutUploadKit.OverrideStatus(name: scheduleOverride.context.name,
                                                  timestamp: date,
                                                  active: true,
                                                  currentCorrectionRange: currentCorrectionRange,
                                                  duration: duration,
                                                  multiplier: scheduleOverride.settings.insulinNeedsScaleFactor)
    }
    
    var uploaderStatus: UploaderStatus {
        let uploaderDevice = UIDevice.current
        let battery = uploaderDevice.isBatteryMonitoringEnabled ? Int(uploaderDevice.batteryLevel * 100) : 0
        return UploaderStatus(name: uploaderDevice.name, timestamp: date, battery: battery)
    }
    
    var deviceStatus: DeviceStatus {
        return DeviceStatus(device: "loop://\(UIDevice.current.name)",
            timestamp: date,
            pumpStatus: pumpStatus,
            uploaderStatus: uploaderStatus,
            loopStatus: loopStatus,
            overrideStatus: overrideStatus)
    }
    
}

extension StoredDosingDecision.Issue {
    var description: String {
        var description = id
        if let details = details {
            description += String(describing: details)
        }
        return description
    }
}

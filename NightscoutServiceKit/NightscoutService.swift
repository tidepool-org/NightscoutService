//
//  NightscoutService.swift
//  NightscoutServiceKit
//
//  Created by Darin Krauss on 6/20/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import HealthKit
import LoopKit
import NightscoutUploadKit
import os.log

public final class NightscoutService: Service {

    public static let serviceIdentifier = "NightscoutService"

    public static let localizedTitle = LocalizedString("Nightscout", comment: "The title of the Nightscout service")

    public var serviceDelegate: ServiceDelegate?

    public var siteURL: URL?

    public var apiSecret: String?

    private var uploader: NightscoutUploader?

    private var lastSettingsUpload: Date = .distantPast

    private var lastDeviceStatusUpload: Date = .distantPast

    private var lastTempBasalUploaded: DoseEntry?

    private let log = OSLog(category: "NightscoutService")

    public init() {
        if let credentials = try? KeychainManager().getNightscoutCredentials() {
            self.siteURL = credentials.siteURL
            self.apiSecret = credentials.apiSecret
        }
        createUploader()
    }

    public convenience init?(rawState: RawStateValue) {
        self.init()
    }

    public var rawState: RawStateValue {
        return [:]
    }

    public var hasConfiguration: Bool { return siteURL != nil && apiSecret?.isEmpty == false }

    public func verifyConfiguration(completion: @escaping (Error?) -> Void) {
        guard hasConfiguration, let siteURL = siteURL, let apiSecret = apiSecret else {
            return
        }

        let uploader = NightscoutUploader(siteURL: siteURL, APISecret: apiSecret)
        uploader.checkAuth(completion)
    }

    public func completeCreate() {
        try? KeychainManager().setNightscoutCredentials(siteURL: siteURL, apiSecret: apiSecret)
        createUploader()
    }

    public func completeUpdate() {
        try? KeychainManager().setNightscoutCredentials(siteURL: siteURL, apiSecret: apiSecret)
        createUploader()
        serviceDelegate?.serviceDidUpdate(self)
    }

    public func completeDelete() {
        try? KeychainManager().setNightscoutCredentials()
    }

    private func createUploader() {
        if let siteURL = siteURL,
            let apiSecret = apiSecret {
            uploader = NightscoutUploader(siteURL: siteURL, APISecret: apiSecret)
        } else {
            uploader = nil
        }
    }

}

extension NightscoutService: RemoteDataService {

    public func uploadSettings(_ settings: Settings, lastUpdated: Date) {
        guard let uploader = uploader,
            lastUpdated > lastSettingsUpload else
        {
            return
        }

        guard
            let basalRateSchedule = settings.basalRateSchedule,
            let insulinModel = settings.insulinModel,
            let carbRatioSchedule = settings.carbRatioSchedule,
            let insulinSensitivitySchedule = settings.insulinSensitivitySchedule,
            let preferredUnit = settings.glucoseUnit,
            let correctionSchedule = settings.glucoseTargetRangeSchedule else
        {
            log.default("Not uploading due to incomplete configuration")
            return
        }

        let targetLowItems = correctionSchedule.items.map { (item) -> ProfileSet.ScheduleItem in
            return ProfileSet.ScheduleItem(offset: item.startTime, value: item.value.minValue)
        }

        let targetHighItems = correctionSchedule.items.map { (item) -> ProfileSet.ScheduleItem in
            return ProfileSet.ScheduleItem(offset: item.startTime, value: item.value.maxValue)
        }

        let nsScheduledOverride = settings.scheduleOverride?.nsScheduleOverride(for: preferredUnit)

        let nsPreMealTargetRange: ClosedRange<Double>?
        if let preMealTargetRange = settings.preMealTargetRange {
            nsPreMealTargetRange = ClosedRange(uncheckedBounds: (
                lower: preMealTargetRange.minValue,
                upper: preMealTargetRange.maxValue))
        } else {
            nsPreMealTargetRange = nil
        }

        let nsLoopSettings = NightscoutUploadKit.LoopSettings(
            dosingEnabled: settings.dosingEnabled,
            overridePresets: settings.overridePresets.map { $0.nsScheduleOverride(for: preferredUnit) },
            scheduleOverride: nsScheduledOverride,
            minimumBGGuard: settings.suspendThreshold?.quantity.doubleValue(for: preferredUnit),
            preMealTargetRange: nsPreMealTargetRange,
            maximumBasalRatePerHour: settings.maximumBasalRatePerHour,
            maximumBolus: settings.maximumBolus)

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

        let profileSet = ProfileSet(
            startDate: Date(),
            units: preferredUnit.shortLocalizedUnitString(),
            enteredBy: "Loop",
            defaultProfile: "Default",
            store: store,
            settings: nsLoopSettings)

        log.default("Uploading profile")

        uploader.uploadProfile(profileSet: profileSet) { (result) in
            switch(result) {
            case .failure(let error):
                self.log.error("Settings upload failed: %{public}@", String(describing: error))
            case .success:
                DispatchQueue.main.async {
                    self.lastSettingsUpload = Date()
                }
            }
        }
    }

    public func uploadLoopStatus(
        insulinOnBoard: InsulinValue?,
        carbsOnBoard: CarbValue?,
        predictedGlucose: [GlucoseValue]?,
        recommendedTempBasal: (recommendation: TempBasalRecommendation, date: Date)?,
        recommendedBolus: Double?,
        lastReservoirValue: ReservoirValue?,
        pumpManagerStatus: PumpManagerStatus?,
        glucoseTargetRangeSchedule: GlucoseRangeSchedule?,
        scheduleOverride: LoopKit.TemporaryScheduleOverride?,
        glucoseTargetRangeScheduleApplyingOverrideIfActive: GlucoseRangeSchedule?,
        loopError: Error?)
    {
        guard uploader != nil else {
            return
        }

        let statusTime = Date()

        let iob: IOBStatus?

        if let insulinOnBoard = insulinOnBoard {
            iob = IOBStatus(timestamp: insulinOnBoard.startDate, iob: insulinOnBoard.value)
        } else {
            iob = nil
        }

        let cob: COBStatus?

        if let carbsOnBoard = carbsOnBoard {
            cob = COBStatus(cob: carbsOnBoard.quantity.doubleValue(for: HKUnit.gram()), timestamp: carbsOnBoard.startDate)
        } else {
            cob = nil
        }

        let predicted: PredictedBG?
        if let predictedGlucose = predictedGlucose, let startDate = predictedGlucose.first?.startDate {
            let values = predictedGlucose.map { $0.quantity }
            predicted = PredictedBG(startDate: startDate, values: values)
        } else {
            predicted = nil
        }

        let recommended: RecommendedTempBasal?

        if let (recommendation: recommendation, date: date) = recommendedTempBasal {
            recommended = RecommendedTempBasal(timestamp: date, rate: recommendation.unitsPerHour, duration: recommendation.duration)
        } else {
            recommended = nil
        }

        let loopEnacted: LoopEnacted?
        if case .some(.tempBasal(let tempBasal)) = pumpManagerStatus?.basalDeliveryState, lastTempBasalUploaded?.startDate != tempBasal.startDate {
            let duration = tempBasal.endDate.timeIntervalSince(tempBasal.startDate)
            loopEnacted = LoopEnacted(rate: tempBasal.unitsPerHour, duration: duration, timestamp: tempBasal.startDate, received:
                true)
            lastTempBasalUploaded = tempBasal
        } else {
            loopEnacted = nil
        }

        let loopName = Bundle.main.bundleDisplayName
        let loopVersion = Bundle.main.shortVersionString

        //this is the only pill that has the option to modify the text
        //to do that pass a different name value instead of loopName
        let loopStatus = LoopStatus(name: loopName, version: loopVersion, timestamp: statusTime, iob: iob, cob: cob, predicted: predicted, recommendedTempBasal: recommended, recommendedBolus: recommendedBolus, enacted: loopEnacted, failureReason: loopError)

        let pumpStatus: PumpStatus?

        if let pumpManagerStatus = pumpManagerStatus
        {

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
            if let lastReservoirValue = lastReservoirValue, lastReservoirValue.startDate > Date().addingTimeInterval(.minutes(-15)) {
                currentReservoirUnits = lastReservoirValue.unitVolume
            } else {
                currentReservoirUnits = nil
            }

            pumpStatus = PumpStatus(
                clock: Date(),
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
        let unit: HKUnit = glucoseTargetRangeSchedule?.unit ?? HKUnit.milligramsPerDeciliter
        if let override = scheduleOverride, override.isActive(),
            let range = glucoseTargetRangeScheduleApplyingOverrideIfActive?.value(at: Date()) {
            let lowerTarget = HKQuantity(unit: unit, doubleValue: range.minValue)
            let upperTarget = HKQuantity(unit: unit, doubleValue: range.maxValue)
            let correctionRange = CorrectionRange(minValue: lowerTarget, maxValue: upperTarget)
            let endDate = override.endDate
            let duration: TimeInterval?
            if override.duration == .indefinite {
                duration = nil
            } else {
                duration = round(endDate.timeIntervalSince(Date()))
            }
            overrideStatus = NightscoutUploadKit.OverrideStatus(name: override.context.name, timestamp: Date(), active: true, currentCorrectionRange: correctionRange, duration: duration, multiplier: override.settings.insulinNeedsScaleFactor)
        } else {
            overrideStatus = NightscoutUploadKit.OverrideStatus(timestamp: Date(), active: false)
        }

        log.default("Uploading loop status")

        upload(pumpStatus: pumpStatus, loopStatus: loopStatus, deviceName: nil, firmwareVersion: nil, uploaderStatus: getUploaderStatus(), overrideStatus: overrideStatus)
    }

    private func getUploaderStatus() -> UploaderStatus {
        // Gather UploaderStatus
        let uploaderDevice = UIDevice.current

        let battery: Int?
        if uploaderDevice.isBatteryMonitoringEnabled {
            battery = Int(uploaderDevice.batteryLevel * 100)
        } else {
            battery = 0   // Nightscout does not handle missing uploader status battery
        }
        return UploaderStatus(name: uploaderDevice.name, timestamp: Date(), battery: battery)
    }

    private func upload(pumpStatus: PumpStatus?, loopStatus: LoopStatus?, deviceName: String?, firmwareVersion: String?, uploaderStatus: UploaderStatus?, overrideStatus: OverrideStatus?) {
        guard let uploader = uploader else {
            return
        }

        if pumpStatus == nil && loopStatus == nil && uploaderStatus != nil {
            // If we're just uploading phone status, limit it to once every 5 minutes
            if self.lastDeviceStatusUpload.timeIntervalSinceNow > -(TimeInterval(minutes: 5)) {
                return
            }
        }

        let uploaderDevice = UIDevice.current

        // Build DeviceStatus
        let deviceStatus = DeviceStatus(device: "loop://\(uploaderDevice.name)", timestamp: Date(), pumpStatus: pumpStatus, uploaderStatus: uploaderStatus, loopStatus: loopStatus, radioAdapter: nil, overrideStatus: overrideStatus)

        self.lastDeviceStatusUpload = Date()
        uploader.uploadDeviceStatus(deviceStatus)
    }

    public func upload(glucoseValues values: [GlucoseValue], sensorState: SensorDisplayable?) {
        guard let uploader = uploader else {
            return
        }

        let device = "loop://\(UIDevice.current.name)"
        let direction: String? = {
            switch sensorState?.trendType {
            case .up?:
                return "SingleUp"
            case .upUp?, .upUpUp?:
                return "DoubleUp"
            case .down?:
                return "SingleDown"
            case .downDown?, .downDownDown?:
                return "DoubleDown"
            case .flat?:
                return "Flat"
            case .none:
                return nil
            }
        }()

        for value in values {
            uploader.uploadSGV(
                glucoseMGDL: Int(value.quantity.doubleValue(for: .milligramsPerDeciliter)),
                at: value.startDate,
                direction: direction,
                device: device
            )
        }
    }

    public func upload(pumpEvents events: [PersistedPumpEvent], fromSource source: String, completion: @escaping (Result<[URL], Error>) -> Void) {
        guard let uploader = uploader else {
            completion(.success(events.map({ $0.objectIDURL })))
            return
        }

        uploader.upload(events, fromSource: source, completion: completion)
    }

    public func upload(carbEntries entries: [StoredCarbEntry], completion: @escaping (_ entries: [StoredCarbEntry]) -> Void) {
        guard let uploader = uploader else {
            completion(entries)
            return
        }

        uploader.uploadCarbEntries(entries, completion: completion)
    }

    public func delete(carbEntries entries: [DeletedCarbEntry], completion: @escaping (_ entries: [DeletedCarbEntry]) -> Void) {
        guard let uploader = uploader else {
            completion(entries)
            return
        }

        uploader.deleteCarbEntries(entries, completion: completion)
    }

}

private extension Array where Element == RepeatingScheduleValue<Double> {
    func scheduleItems() -> [ProfileSet.ScheduleItem] {
        return map { (item) -> ProfileSet.ScheduleItem in
            return ProfileSet.ScheduleItem(offset: item.startTime, value: item.value)
        }
    }
}

private extension LoopKit.TemporaryScheduleOverride {
    func nsScheduleOverride(for unit: HKUnit) -> NightscoutUploadKit.TemporaryScheduleOverride {
        let nsTargetRange: ClosedRange<Double>?
        if let targetRange = settings.targetRange {
            nsTargetRange = ClosedRange(uncheckedBounds: (
                lower: targetRange.lowerBound.doubleValue(for: unit),
                upper: targetRange.upperBound.doubleValue(for: unit)))
        } else {
            nsTargetRange = nil
        }

        let nsDuration: TimeInterval
        switch duration {
        case .finite(let interval):
            nsDuration = interval
        case .indefinite:
            nsDuration = 0
        }

        return NightscoutUploadKit.TemporaryScheduleOverride(
            targetRange: nsTargetRange,
            insulinNeedsScaleFactor: settings.insulinNeedsScaleFactor,
            symbol: context.symbol,
            duration: nsDuration,
            name: context.name)
    }
}

private extension LoopKit.TemporaryScheduleOverride.Context {
    var name: String? {
        switch self {
        case .custom:
            return nil
        case .legacyWorkout:
            return LocalizedString("Workout", comment: "Name uploaded to Nightscout for legacy workout override")
        case .preMeal:
            return LocalizedString("Pre-Meal", comment: "Name uploaded to Nightscout for Pre-Meal override")
        case .preset(let preset):
            return preset.name
        }
    }

    var symbol: String? {
        switch self {
        case .preset(let preset):
            return preset.symbol
        default:
            return nil
        }
    }
}

private extension LoopKit.TemporaryScheduleOverridePreset {
    func nsScheduleOverride(for unit: HKUnit) -> NightscoutUploadKit.TemporaryScheduleOverride {
        let nsTargetRange: ClosedRange<Double>?
        if let targetRange = settings.targetRange {
            nsTargetRange = ClosedRange(uncheckedBounds: (
                lower: targetRange.lowerBound.doubleValue(for: unit),
                upper: targetRange.upperBound.doubleValue(for: unit)))
        } else {
            nsTargetRange = nil
        }

        let nsDuration: TimeInterval
        switch duration {
        case .finite(let interval):
            nsDuration = interval
        case .indefinite:
            nsDuration = 0
        }

        return NightscoutUploadKit.TemporaryScheduleOverride(
            targetRange: nsTargetRange,
            insulinNeedsScaleFactor: settings.insulinNeedsScaleFactor,
            symbol: self.symbol,
            duration: nsDuration,
            name: self.name)
    }
}

extension KeychainManager {

    func setNightscoutCredentials(siteURL: URL? = nil, apiSecret: String? = nil) throws {
        let credentials: InternetCredentials?

        if let siteURL = siteURL, let apiSecret = apiSecret {
            credentials = InternetCredentials(username: NightscoutAPIAccount, password: apiSecret, url: siteURL)
        } else {
            credentials = nil
        }

        try replaceInternetCredentials(credentials, forAccount: NightscoutAPIAccount)
    }

    func getNightscoutCredentials() throws -> (siteURL: URL, apiSecret: String) {
        let credentials = try getInternetCredentials(account: NightscoutAPIAccount)

        return (siteURL: credentials.url, apiSecret: credentials.password)
    }

}

fileprivate let NightscoutAPIAccount = "NightscoutAPI"

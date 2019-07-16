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


public final class NightscoutService: Service {

    public static let managerIdentifier = "NightscoutService"

    public static let localizedTitle = LocalizedString("Nightscout", comment: "The title of the Nightscout service")

    public var delegateQueue: DispatchQueue! {
        get {
            return delegate.queue
        }
        set {
            delegate.queue = newValue
        }
    }

    public weak var serviceDelegate: ServiceDelegate? {
        get {
            return delegate.delegate
        }
        set {
            delegate.delegate = newValue
        }
    }

    private let delegate = WeakSynchronizedDelegate<ServiceDelegate>()

    public var siteURL: URL?

    public var apiSecret: String?

    private var uploader: NightscoutUploader?

    private var lastDeviceStatusUpload: Date?

    private var lastTempBasalUploaded: DoseEntry?

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

    public var hasValidConfiguration: Bool { return siteURL != nil && apiSecret?.isEmpty == false }

    public func verifyConfiguration(completion: @escaping (Error?) -> Void) {
        guard hasValidConfiguration, let siteURL = siteURL, let apiSecret = apiSecret else {
            return
        }

        let uploader = NightscoutUploader(siteURL: siteURL, APISecret: apiSecret)
        uploader.checkAuth(completion)
    }

    public func notifyCreated(completion: @escaping () -> Void) {
        try? KeychainManager().setNightscoutCredentials(siteURL: siteURL, apiSecret: apiSecret)
        createUploader()
        notifyDelegateOfCreation(completion: completion)
    }

    public func notifyUpdated(completion: @escaping () -> Void) {
        try? KeychainManager().setNightscoutCredentials(siteURL: siteURL, apiSecret: apiSecret)
        createUploader()
        notifyDelegateOfUpdation(completion: completion)
    }

    public func notifyDeleted(completion: @escaping () -> Void) {
        try? KeychainManager().setNightscoutCredentials()
        notifyDelegateOfDeletion(completion: completion)
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


extension NightscoutService {

    public var debugDescription: String {
        return """
        ## NightscoutService
        """
    }

}


extension NightscoutService: RemoteData {

    public func uploadLoopStatus(insulinOnBoard: InsulinValue? = nil, carbsOnBoard: CarbValue? = nil, predictedGlucose: [GlucoseValue]? = nil, recommendedTempBasal: (recommendation: TempBasalRecommendation, date: Date)? = nil, recommendedBolus: Double? = nil, lastTempBasal: DoseEntry? = nil, lastReservoirValue: ReservoirValue? = nil, pumpManagerStatus: PumpManagerStatus? = nil, loopError: Error? = nil) {

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
        if let tempBasal = lastTempBasal, lastTempBasalUploaded?.startDate != tempBasal.startDate {
            let duration = tempBasal.endDate.timeIntervalSince(tempBasal.startDate)
            loopEnacted = LoopEnacted(rate: tempBasal.unitsPerHour, duration: duration, timestamp: tempBasal.startDate, received:
                true)
            lastTempBasalUploaded = tempBasal
        } else {
            loopEnacted = nil
        }

        let loopName = Bundle.main.bundleDisplayName
        let loopVersion = Bundle.main.shortVersionString

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

            pumpStatus = PumpStatus(
                clock: Date(),
                pumpID: pumpManagerStatus.device.localIdentifier ?? "Unknown",
                iob: nil,
                battery: battery,
                suspended: pumpManagerStatus.basalDeliveryState == .suspended,
                bolusing: bolusing,
                reservoir: lastReservoirValue?.unitVolume,
                secondsFromGMT: pumpManagerStatus.timeZone.secondsFromGMT())
        } else {
            pumpStatus = nil
        }

        upload(pumpStatus: pumpStatus, loopStatus: loopStatus, deviceName: nil, firmwareVersion: nil, uploaderStatus: getUploaderStatus())

    }

    private func getUploaderStatus() -> UploaderStatus {
        // Gather UploaderStatus
        let uploaderDevice = UIDevice.current

        let battery: Int?
        if uploaderDevice.isBatteryMonitoringEnabled {
            battery = Int(uploaderDevice.batteryLevel * 100)
        } else {
            battery = nil
        }
        return UploaderStatus(name: uploaderDevice.name, timestamp: Date(), battery: battery)
    }

    private func upload(pumpStatus: PumpStatus?, loopStatus: LoopStatus?, deviceName: String?, firmwareVersion: String?, uploaderStatus: UploaderStatus?) {

        guard let uploader = uploader else {
            return
        }

        if pumpStatus == nil && loopStatus == nil && uploaderStatus != nil {
            // If we're just uploading phone status, limit it to once every 5 minutes
            if self.lastDeviceStatusUpload != nil && self.lastDeviceStatusUpload!.timeIntervalSinceNow > -(TimeInterval(minutes: 5)) {
                return
            }
        }

        let uploaderDevice = UIDevice.current

        // Build DeviceStatus
        let deviceStatus = DeviceStatus(device: "loop://\(uploaderDevice.name)", timestamp: Date(), pumpStatus: pumpStatus, uploaderStatus: uploaderStatus, loopStatus: loopStatus, radioAdapter: nil)

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

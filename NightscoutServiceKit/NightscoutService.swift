//
//  NightscoutService.swift
//  NightscoutServiceKit
//
//  Created by Darin Krauss on 6/20/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import os.log
import HealthKit
import LoopKit
import NightscoutUploadKit

public final class NightscoutService: Service {

    public static let serviceIdentifier = "NightscoutService"

    public static let localizedTitle = LocalizedString("Nightscout", comment: "The title of the Nightscout service")

    public weak var serviceDelegate: ServiceDelegate?

    public weak var remoteDataServiceDelegate: RemoteDataServiceDelegate?

    public var siteURL: URL?

    public var apiSecret: String?

    private let statusRemoteDataQueryMaximumLimit = 1000

    private var statusRemoteDataQuery: StatusRemoteDataQuery

    private let settingsRemoteDataQueryMaximumLimit = 1000

    private var settingsRemoteDataQuery: SettingsRemoteDataQuery

    private let glucoseRemoteDataQueryMaximumLimit = 1000

    private var glucoseRemoteDataQuery: GlucoseRemoteDataQuery

    private let doseRemoteDataQueryMaximumLimit = 1000

    private var doseRemoteDataQuery: DoseRemoteDataQuery

    private let carbRemoteDataQueryMaximumLimit = 1000

    private var carbRemoteDataQuery: CarbRemoteDataQuery

    private var uploader: NightscoutUploader?

    private let log = OSLog(category: "NightscoutService")

    public init() {
        self.statusRemoteDataQuery = StatusRemoteDataQuery()
        self.settingsRemoteDataQuery = SettingsRemoteDataQuery()
        self.glucoseRemoteDataQuery = GlucoseRemoteDataQuery()
        self.doseRemoteDataQuery = DoseRemoteDataQuery()
        self.carbRemoteDataQuery = CarbRemoteDataQuery()
    }

    public required init?(rawState: RawStateValue) {
        guard
            let rawStatusRemoteDataQuery = rawState["statusRemoteDataQuery"] as? StatusRemoteDataQuery.RawValue,
            let statusRemoteDataQuery = StatusRemoteDataQuery(rawValue: rawStatusRemoteDataQuery),
            let rawSettingsRemoteDataQuery = rawState["settingsRemoteDataQuery"] as? SettingsRemoteDataQuery.RawValue,
            let settingsRemoteDataQuery = SettingsRemoteDataQuery(rawValue: rawSettingsRemoteDataQuery),
            let rawGlucoseRemoteDataQuery = rawState["glucoseRemoteDataQuery"] as? GlucoseRemoteDataQuery.RawValue,
            let glucoseRemoteDataQuery = GlucoseRemoteDataQuery(rawValue: rawGlucoseRemoteDataQuery),
            let rawDoseRemoteDataQuery = rawState["doseRemoteDataQuery"] as? DoseRemoteDataQuery.RawValue,
            let doseRemoteDataQuery = DoseRemoteDataQuery(rawValue: rawDoseRemoteDataQuery),
            let rawCarbRemoteDataQuery = rawState["carbRemoteDataQuery"] as? CarbRemoteDataQuery.RawValue,
            let carbRemoteDataQuery = CarbRemoteDataQuery(rawValue: rawCarbRemoteDataQuery) else
        {
            return nil
        }

        self.statusRemoteDataQuery = statusRemoteDataQuery
        self.settingsRemoteDataQuery = settingsRemoteDataQuery
        self.glucoseRemoteDataQuery = glucoseRemoteDataQuery
        self.doseRemoteDataQuery = doseRemoteDataQuery
        self.carbRemoteDataQuery = carbRemoteDataQuery

        restoreCredentials()
    }

    public var rawState: RawStateValue {
        var rawState: RawStateValue = [:]
        rawState["statusRemoteDataQuery"] = statusRemoteDataQuery.rawValue
        rawState["settingsRemoteDataQuery"] = settingsRemoteDataQuery.rawValue
        rawState["glucoseRemoteDataQuery"] = glucoseRemoteDataQuery.rawValue
        rawState["doseRemoteDataQuery"] = doseRemoteDataQuery.rawValue
        rawState["carbRemoteDataQuery"] = carbRemoteDataQuery.rawValue
        return rawState
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
        saveCredentials()
    }

    public func completeUpdate() {
        saveCredentials()
        serviceDelegate?.serviceDidUpdateState(self)
    }

    public func completeDelete() {
        clearCredentials()
    }

    private func saveCredentials() {
        try? KeychainManager().setNightscoutCredentials(siteURL: siteURL, apiSecret: apiSecret)
    }

    private func restoreCredentials() {
        if let credentials = try? KeychainManager().getNightscoutCredentials() {
            self.siteURL = credentials.siteURL
            self.apiSecret = credentials.apiSecret
        }
    }

    private func clearCredentials() {
        try? KeychainManager().setNightscoutCredentials()
    }

}

extension NightscoutService: RemoteDataService {

    public func synchronizeRemoteData(completion: @escaping (Result<Bool, Error>) -> Void) {
        if uploader == nil {
            guard let siteURL = siteURL, let apiSecret = apiSecret else {
                return
            }
            uploader = NightscoutUploader(siteURL: siteURL, APISecret: apiSecret)
        }

        // TODO: Prevent reentrancy
        synchronizeStatusRemoteData { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let uploadedStatus):
                self.synchronizeSettingsRemoteData { result in
                    switch result {
                    case .failure(let error):
                        completion(.failure(error))
                    case .success(let uploadSettings):
                        self.synchronizeGlucoseRemoteData { result in
                            switch result {
                            case .failure(let error):
                                completion(.failure(error))
                            case .success(let uploadedGlucose):
                                self.synchronizeDoseRemoteData { result in
                                    switch result {
                                    case .failure(let error):
                                        completion(.failure(error))
                                    case .success(let uploadedDose):
                                        self.synchronizeCarbRemoteData { result in
                                            switch result {
                                            case .failure(let error):
                                                completion(.failure(error))
                                            case .success(let uploadedCarb):
                                                completion(.success(uploadedStatus || uploadSettings || uploadedGlucose || uploadedDose || uploadedCarb))
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func synchronizeStatusRemoteData(completion: @escaping (Result<Bool, Error>) -> Void) {
        statusRemoteDataQuery.delegate = remoteDataServiceDelegate?.statusRemoteDataQueryDelegate
        statusRemoteDataQuery.execute(maximumLimit: statusRemoteDataQueryMaximumLimit) { result in
            switch result {
            case .failure(let error):
                self.statusRemoteDataQuery.abort()
                completion(.failure(error))
            case .success(let data):
                self.uploadStatuses(data) { result in
                    switch result {
                    case .failure(let error):
                        self.statusRemoteDataQuery.abort()
                        completion(.failure(error))
                    case .success:
                        self.statusRemoteDataQuery.commit()
                        self.serviceDelegate?.serviceDidUpdateState(self)
                        completion(.success(!data.isEmpty))
                    }
                }
            }
        }
    }

    private func uploadStatuses(_ storedStatuses: [StoredStatus], completion: @escaping (Result<Bool, Error>) -> Void) {
        uploader!.uploadDeviceStatuses(storedStatuses.map { DeviceStatus(storedStatus: $0) }, completion: completion)
    }

    private func synchronizeSettingsRemoteData(completion: @escaping (Result<Bool, Error>) -> Void) {
        settingsRemoteDataQuery.delegate = remoteDataServiceDelegate?.settingsRemoteDataQueryDelegate
        settingsRemoteDataQuery.execute(maximumLimit: settingsRemoteDataQueryMaximumLimit) { result in
            switch result {
            case .failure(let error):
                self.settingsRemoteDataQuery.abort()
                completion(.failure(error))
            case .success(let data):
                self.uploadSettings(data) { result in
                    switch result {
                    case .failure(let error):
                        self.settingsRemoteDataQuery.abort()
                        completion(.failure(error))
                    case .success:
                        self.settingsRemoteDataQuery.commit()
                        self.serviceDelegate?.serviceDidUpdateState(self)
                        completion(.success(!data.isEmpty))
                    }
                }
            }
        }
    }

    private func uploadSettings(_ storedSettings: [StoredSettings], completion: @escaping (Result<Bool, Error>) -> Void) {
        uploader!.uploadProfiles(storedSettings.compactMap { ProfileSet(storedSettings: $0) }, completion: completion)
    }

    private func synchronizeGlucoseRemoteData(completion: @escaping (Result<Bool, Error>) -> Void) {
        glucoseRemoteDataQuery.delegate = remoteDataServiceDelegate?.glucoseRemoteDataQueryDelegate
        glucoseRemoteDataQuery.execute(maximumLimit: glucoseRemoteDataQueryMaximumLimit) { result in
            switch result {
            case .failure(let error):
                self.glucoseRemoteDataQuery.abort()
                completion(.failure(error))
            case .success(let data):
                self.uploader!.uploadGlucoseSamples(data) { result in
                    switch result {
                    case .failure(let error):
                        self.glucoseRemoteDataQuery.abort()
                        completion(.failure(error))
                    case .success:
                        self.glucoseRemoteDataQuery.commit()
                        self.serviceDelegate?.serviceDidUpdateState(self)
                        completion(.success(!data.isEmpty))
                    }
                }
            }
        }
    }

    private func synchronizeDoseRemoteData(completion: @escaping (Result<Bool, Error>) -> Void) {
        doseRemoteDataQuery.delegate = remoteDataServiceDelegate?.doseRemoteDataQueryDelegate
        doseRemoteDataQuery.execute(maximumLimit: doseRemoteDataQueryMaximumLimit) { result in
            switch result {
            case .failure(let error):
                self.doseRemoteDataQuery.abort()
                completion(.failure(error))
            case .success(let data):
                self.uploader!.uploadPumpEvents(data) { result in
                    switch result {
                    case .failure(let error):
                        self.doseRemoteDataQuery.abort()
                        completion(.failure(error))
                    case .success:
                        self.doseRemoteDataQuery.commit()
                        self.serviceDelegate?.serviceDidUpdateState(self)
                        completion(.success(!data.isEmpty))
                    }
                }
            }
        }
    }

    private func synchronizeCarbRemoteData(completion: @escaping (Result<Bool, Error>) -> Void) {
        carbRemoteDataQuery.delegate = remoteDataServiceDelegate?.carbRemoteDataQueryDelegate
        carbRemoteDataQuery.execute(maximumLimit: carbRemoteDataQueryMaximumLimit) { result in
            switch result {
            case .failure(let error):
                self.carbRemoteDataQuery.abort()
                completion(.failure(error))
            case .success(let data):
                self.uploader!.uploadCarbEntries(data.stored) { result in
                    switch result {
                    case .failure(let error):
                        self.carbRemoteDataQuery.abort()
                        completion(.failure(error))
                    case .success:
                        self.uploader!.deleteCarbEntries(data.deleted) { result in
                            switch result {
                            case .failure(let error):
                                self.carbRemoteDataQuery.abort()
                                completion(.failure(error))
                            case .success:
                                self.carbRemoteDataQuery.commit()
                                self.serviceDelegate?.serviceDidUpdateState(self)
                                completion(.success(!data.isEmpty))
                            }
                        }
                    }
                }
            }
        }
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

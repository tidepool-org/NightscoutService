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

    public var siteURL: URL?

    public var apiSecret: String?

    private lazy var uploader: NightscoutUploader! = {
        guard let siteURL = siteURL, let apiSecret = apiSecret else {
            return nil
        }
        return NightscoutUploader(siteURL: siteURL, APISecret: apiSecret)
    }()

    private let log = OSLog(category: "NightscoutService")

    public init() {}

    public required init?(rawState: RawStateValue) {
        restoreCredentials()
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

    public var carbDataLimit: Int? { return 1000 }

    public func uploadCarbData(created: [SyncCarbObject], updated: [SyncCarbObject], deleted: [SyncCarbObject], completion: @escaping (Result<Bool, Error>) -> Void) {
        self.uploader.createCarbData(created) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let createdUploaded):
                self.uploader.updateCarbData(updated) { result in
                    switch result {
                    case .failure(let error):
                        completion(.failure(error))
                    case .success(let updatedUploaded):
                        self.uploader.deleteCarbData(deleted) { result in
                            switch result {
                            case .failure(let error):
                                completion(.failure(error))
                            case .success(let deletedUploaded):
                                completion(.success(createdUploaded || updatedUploaded || deletedUploaded))
                            }
                        }
                    }
                }
            }
        }
    }

    public var doseDataLimit: Int? { return 1000 }

    public func uploadDoseData(_ stored: [DoseEntry], completion: @escaping (Result<Bool, Error>) -> Void) {
        uploader.uploadDoses(stored, completion: completion)
    }

    public var dosingDecisionDataLimit: Int? { return 1000 }

    public func uploadDosingDecisionData(_ stored: [StoredDosingDecision], completion: @escaping (Result<Bool, Error>) -> Void) {
        uploader.uploadDeviceStatuses(stored.map { $0.deviceStatus }, completion: completion)
    }

    public var glucoseDataLimit: Int? { return 1000 }

    public func uploadGlucoseData(_ stored: [StoredGlucoseSample], completion: @escaping (Result<Bool, Error>) -> Void) {
        uploader.uploadGlucoseSamples(stored, completion: completion)
    }

    public var pumpEventDataLimit: Int? { return 1000 }

    public func uploadPumpEventData(_ stored: [PersistedPumpEvent], completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success(false))
    }

    public var settingsDataLimit: Int? { return 1000 }

    public func uploadSettingsData(_ stored: [StoredSettings], completion: @escaping (Result<Bool, Error>) -> Void) {
        uploader.uploadProfiles(stored.compactMap { $0.profileSet }, completion: completion)
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

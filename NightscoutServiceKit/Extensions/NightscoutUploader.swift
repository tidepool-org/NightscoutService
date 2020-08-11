//
//  NightscoutUploader.swift
//  NightscoutServiceKit
//
//  Created by Darin Krauss on 6/20/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import LoopKit
import NightscoutUploadKit

extension NightscoutUploader {

    func createCarbData(_ data: [SyncCarbObject], completion: @escaping (Result<Bool, Error>) -> Void) {
        guard !data.isEmpty else {
            completion(.success(false))
            return
        }

        upload(data.compactMap { $0.mealBolusNightscoutTreatment }) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success:
                completion(.success(true))
            }
        }
    }

    func updateCarbData(_ data: [SyncCarbObject], completion: @escaping (Result<Bool, Error>) -> Void) {
        guard !data.isEmpty else {
            completion(.success(false))
            return
        }

        modifyTreatments(data.compactMap { $0.mealBolusNightscoutTreatment }) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(true))
            }
        }
    }

    func deleteCarbData(_ data: [SyncCarbObject], completion: @escaping (Result<Bool, Error>) -> Void) {
        guard !data.isEmpty else {
            completion(.success(false))
            return
        }

        deleteTreatmentsByClientId(data.compactMap { $0.nightscoutIdentifier }) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(true))
            }
        }
    }

}

extension NightscoutUploader {

    func uploadGlucoseSamples(_ samples: [StoredGlucoseSample], completion: @escaping (Result<Bool, Error>) -> Void) {
        guard !samples.isEmpty else {
            completion(.success(false))
            return
        }

        uploadEntries(samples.compactMap { $0.nightscoutEntry }) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success:
                completion(.success(true))
            }
        }
    }

}

extension NightscoutUploader {

    func uploadDoses(_ doses: [DoseEntry], completion: @escaping (Result<Bool, Error>) -> Void) {
        guard !doses.isEmpty else {
            completion(.success(false))
            return
        }

        let source = "loop://\(UIDevice.current.name)"
        self.upload(doses.compactMap { $0.treatment(enteredBy: source) }) { (result) in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success:
                completion(.success(true))
            }
        }
    }

}

extension SyncCarbObject {

    var nightscoutIdentifier: String? {
        return externalID ?? syncIdentifier ?? uuid?.uuidString
    }

}

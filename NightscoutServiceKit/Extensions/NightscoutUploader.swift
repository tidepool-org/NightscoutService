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

    func uploadCarbEntries(_ entries: [StoredCarbEntry], completion: @escaping (Result<Bool, Error>) -> Void) {
        guard !entries.isEmpty else {
            completion(.success(false))
            return
        }

        var created = [MealBolusNightscoutTreatment]()
        var modified = [MealBolusNightscoutTreatment]()

        for entry in entries {
            let treatment = MealBolusNightscoutTreatment(carbEntry: entry)
            if entry.externalID != nil {
                modified.append(treatment)
            } else {
                created.append(treatment)
            }
        }

        upload(created) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success:
                self.modifyTreatments(modified) { error in
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        completion(.success(true))
                    }
                }
            }
        }
    }

    func deleteCarbEntries(_ entries: [DeletedCarbEntry], completion: @escaping (Result<Bool, Error>) -> Void) {
        guard !entries.isEmpty else {
            completion(.success(false))
            return
        }

        let ids = entries.compactMap { $0.nightscoutIdentifier }

        deleteTreatmentsByClientId(ids) { error in
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

        uploadEntries(samples.compactMap { NightscoutEntry(storedGlucoseSample: $0) }) { result in
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

extension StoredCarbEntry {

    var nightscoutIdentifier: String {
        return externalID ?? syncIdentifier ?? sampleUUID.uuidString
    }

}

extension DeletedCarbEntry {

    var nightscoutIdentifier: String? {
        return externalID ?? syncIdentifier ?? uuid?.uuidString
    }

}

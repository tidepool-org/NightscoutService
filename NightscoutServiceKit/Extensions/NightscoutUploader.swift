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

    func uploadCarbEntries(_ entries: [StoredCarbEntry], completion: @escaping ([StoredCarbEntry]) -> Void) {
        var created = [StoredCarbEntry]()
        var modified = [StoredCarbEntry]()

        for entry in entries {
            if entry.externalID != nil {
                modified.append(entry)
            } else {
                created.append(entry)
            }
        }

        upload(created.map { MealBolusNightscoutTreatment(carbEntry: $0) }) { (result) in
            switch result {
            case .success(let ids):
                for (index, id) in ids.enumerated() {
                    created[index].externalID = id
                    created[index].isUploaded = true
                }
                completion(created)
            case .failure(let error):
                self.log.error("%{public}@", String(reflecting: error))
                completion(created)
            }
        }

        modifyTreatments(modified.map { MealBolusNightscoutTreatment(carbEntry: $0) }) { (error) in
            if let error = error {
                self.log.error("%{public}@", String(reflecting: error))
            } else {
                for index in modified.startIndex..<modified.endIndex {
                    modified[index].isUploaded = true
                }
            }

            completion(modified)
        }
    }

    func deleteCarbEntries(_ entries: [DeletedCarbEntry], completion: @escaping ([DeletedCarbEntry]) -> Void) {
        var deleted = entries

        deleteTreatmentsById(deleted.compactMap { $0.externalID }) { (error) in
            if let error = error {
                self.log.error("%{public}@", String(reflecting: error))
            } else {
                for index in deleted.startIndex..<deleted.endIndex {
                    deleted[index].isUploaded = true
                }
            }

            completion(deleted)
        }
    }
    
}


extension NightscoutUploader {

    func upload(_ events: [PersistedPumpEvent], fromSource source: String, completion: @escaping (Result<[URL], Error>) -> Void) {
        var objectIDURLs = [URL]()
        var treatments = [NightscoutTreatment]()

        for event in events {

            objectIDURLs.append(event.objectIDURL)

            guard let treatment = event.treatment(enteredBy: source) else {
                continue
            }

            treatments.append(treatment)
        }

        self.upload(treatments) { (result) in
            switch result {
            case .success( _):
                completion(.success(objectIDURLs))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

}

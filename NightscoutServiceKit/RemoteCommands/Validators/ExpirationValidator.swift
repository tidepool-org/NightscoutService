//
//  ExpirationValidator.swift
//  NightscoutServiceKit
//
//  Created by Bill Gestrich on 2/25/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit

struct ExpirationValidator: RemoteCommandValidator {
    
    let expiration: Date?
    let nowDateSource: () -> Date = {Date()}
    
    enum NotificationValidationError: LocalizedError {
        
        case expiredNotification

        var errorDescription: String? {
            switch  self {
            case .expiredNotification:
                return LocalizedString("Expired", comment: "Remote command error description: expired.")
            }
        }
    }
    
    func validate() throws {
        
        guard let expirationDate = expiration else {
            return //Skip validation if no date included
        }
        
        if nowDateSource() > expirationDate {
            throw NotificationValidationError.expiredNotification
        }
    }
    
}

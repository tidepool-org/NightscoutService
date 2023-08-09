//
//  OTPValidator.swift
//  NightscoutServiceKit
//
//  Created by Bill Gestrich on 2/25/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit

struct OTPValidator: RemoteCommandValidator {
    
    let sentAt: Date?
    let otp: String?
    let otpManager: OTPManager
    let nowDateSource: () -> Date = {Date()}
    
    enum NotificationValidationError: LocalizedError {
        case missingOTP
        
        var errorDescription: String? {
            switch  self {
            case .missingOTP:
                return LocalizedString("Missing OTP", comment: "Remote command error description: Missing OTP.")
            }
        }
    }
    
    func validate() throws {
        
        guard let otp = otp else {
            throw NotificationValidationError.missingOTP
        }
        
        try otpManager.validatePassword(password: otp, deliveryDate: sentAt)
    }
    
}

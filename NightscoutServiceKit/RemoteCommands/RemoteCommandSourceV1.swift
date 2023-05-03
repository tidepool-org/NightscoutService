//
//  RemoteCommandSourceV1.swift
//  NightscoutServiceKit
//
//  Created by Bill Gestrich on 2/25/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit

class RemoteCommandSourceV1: RemoteCommandSource {
    
    private let otpManager: OTPManager
    
    init(otpManager: OTPManager) {
        self.otpManager = otpManager
    }
    
    
    //MARK: RemoteCommandSource
    
    func supportsPushNotification(_ notification: [String: AnyObject]) -> Bool {
        guard let versionString = notification["version"] as? String else {
            return true //Backwards support before version was added
        }
        
        guard let version = Double(versionString) else {
            return false
        }
        
        return version < 2.0
    }
    
    func commandFromPushNotification(_ notification: [String: AnyObject]) async throws -> RemoteCommand {
        
        enum RemoteNotificationError: Error {
            case unhandledNotification
        }
        
        guard let remoteNotification = try notification.toRemoteNotification() else {
            throw RemoteNotificationError.unhandledNotification
        }
        
        return remoteNotification.toRemoteCommand(otpManager: otpManager, commandSource: self)
    }
}

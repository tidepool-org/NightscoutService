//
//  OverrideCancelRemoteNotification.swift
//  NightscoutUploadKit
//
//  Created by Bill Gestrich on 2/25/23.
//  Copyright © 2023 Pete Schwamb. All rights reserved.
//

import Foundation
import LoopKit

public struct OverrideCancelRemoteNotification: RemoteNotification, Codable {
    
    public let remoteAddress: String
    public let expiration: Date?
    public let sentAt: Date?
    public let cancelOverride: Bool

    enum CodingKeys: String, CodingKey {
        case remoteAddress = "remote-address"
        case expiration = "expiration"
        case sentAt = "sent-at"
        case cancelOverride = "cancel-temporary-override"
    }
    
    func toRemoteCommand(otpManager: OTPManager, commandSource: RemoteCommandSource) -> NightscoutRemoteCommand {
        let expirationValidator = ExpirationValidator(expiration: expiration)
        return NightscoutRemoteCommand(id: id,
                                       action: toRemoteAction(),
                                       validators: [expirationValidator],
                                       commandSource: commandSource
        )
    }
    
    func toRemoteAction() -> Action {
        let action = OverrideCancelAction(remoteAddress: remoteAddress)
        return .cancelTemporaryOverride(action)
    }
    
    public static func includedInNotification(_ notification: [String: Any]) -> Bool {
        return notification["cancel-temporary-override"] != nil
    }
}

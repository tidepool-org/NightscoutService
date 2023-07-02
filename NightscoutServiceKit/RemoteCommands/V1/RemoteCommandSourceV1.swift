//
//  RemoteCommandSourceV1.swift
//  NightscoutServiceKit
//
//  Created by Bill Gestrich on 2/25/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import OSLog

class RemoteCommandSourceV1: RemoteCommandSource {
    
    weak var delegate: RemoteCommandSourceV1Delegate?
    private let otpManager: OTPManager
    private let log = OSLog(category: "Remote Command Source V1")
    
    init(otpManager: OTPManager) {
        self.otpManager = otpManager
    }
    
    
    //MARK: RemoteCommandSource
    
    func remoteNotificationWasReceived(_ notification: [String: AnyObject]) async {
        do {
            guard let delegate = delegate else {return}
            let remoteNotification = try notification.toRemoteNotification()
            try remoteNotification.validate(otpManager: otpManager)
            try await delegate.commandSourceV1(self, handleAction: remoteNotification.toRemoteAction())
        } catch {
            log.error("Remote Notification: %{public}@. Error: %{public}@", String(describing: notification), String(describing: error))
            try? await self.delegate?.commandSourceV1(self, uploadError: error, notification: notification)
        }
    }
}

protocol RemoteCommandSourceV1Delegate: AnyObject {
    func commandSourceV1(_: RemoteCommandSourceV1, handleAction action: Action) async throws
    func commandSourceV1(_: RemoteCommandSourceV1, uploadError error: Error, notification: [String: AnyObject]) async throws
}

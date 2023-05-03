//
//  RemoteCommandSource.swift
//  NightscoutServiceKit
//
//  Created by Bill Gestrich on 2/25/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import LoopKit

protocol RemoteCommandSource {
    func commandFromPushNotification(_ notification: [String: AnyObject]) async throws -> RemoteCommand
}

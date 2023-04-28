//
//  NightscoutRemoteCommand.swift
//  NightscoutServiceKit
//
//  Created by Bill Gestrich on 2/25/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit

class NightscoutRemoteCommand: RemoteCommand {
    
    let id: String
    let action: Action
    private let validators: [RemoteCommandValidation]
    private let commandSource: RemoteCommandSource
    
    init(id: String,
         action: Action,
         validators: [RemoteCommandValidation],
         commandSource: RemoteCommandSource)
    {
        self.id = id
        self.action = action
        self.validators = validators
        self.commandSource = commandSource
    }
    
    func validate() throws {
        for validator in validators {
            try validator.validate()
        }
    }

}

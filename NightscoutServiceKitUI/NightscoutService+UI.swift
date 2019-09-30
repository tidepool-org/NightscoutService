//
//  NightscoutService+UI.swift
//  NightscoutServiceKitUI
//
//  Created by Darin Krauss on 6/20/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import LoopKit
import LoopKitUI
import NightscoutServiceKit

extension NightscoutService: ServiceUI {

    public static func setupViewController() -> (UIViewController & ServiceSetupNotifying & CompletionNotifying)? {
        return ServiceViewController(rootViewController: NightscoutServiceTableViewController(nightscoutService: NightscoutService(), for: .create))
    }

    public func settingsViewController() -> (UIViewController & ServiceSetupNotifying & CompletionNotifying) {
      return ServiceViewController(rootViewController: NightscoutServiceTableViewController(nightscoutService: self, for: .update))
    }

}

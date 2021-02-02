//
//  NightscoutService+UI.swift
//  NightscoutServiceKitUI
//
//  Created by Darin Krauss on 6/20/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit
import LoopKitUI
import NightscoutServiceKit

extension NightscoutService: ServiceUI {
    public static var image: UIImage? {
        UIImage(named: "nightscout", in: Bundle(for: ServiceUICoordinator.self), compatibleWith: nil)!
    }

    public static func setupViewController(colorPalette: LoopUIColorPalette) -> SetupUIResult<UIViewController & ServiceCreateNotifying & ServiceOnboardNotifying & CompletionNotifying, ServiceUI> {
        return .userInteractionRequired(ServiceUICoordinator(colorPalette: colorPalette))
    }

    public func settingsViewController(colorPalette: LoopUIColorPalette) -> (UIViewController & ServiceOnboardNotifying & CompletionNotifying) {
        return ServiceUICoordinator(service: self, colorPalette: colorPalette)
    }
}

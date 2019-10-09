//
//  NightscoutEntry.swift
//  NightscoutServiceKit
//
//  Created by Darin Krauss on 10/13/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import LoopKit
import NightscoutUploadKit

extension NightscoutEntry {

    convenience init(storedGlucoseSample: StoredGlucoseSample) {
        self.init(
            glucose: Int(storedGlucoseSample.quantity.doubleValue(for: .milligramsPerDeciliter)),
            timestamp: storedGlucoseSample.startDate,
            device: "loop://\(UIDevice.current.name)",
            glucoseType: .Sensor
//            direction: direction      // TODO: What to do here?
        )
    }

// TODO: How to handle sensorState which ends up in direction above?
//    self.remoteDataServicesManager.upload(glucoseValues: values, sensorState: manager.sensorState)

//    public func upload(glucoseValues values: [GlucoseValue], sensorState: SensorDisplayable?) {

//        let device = "loop://\(UIDevice.current.name)"
//        let direction: String? = {
//            switch sensorState?.trendType {
//            case .up?:
//                return "SingleUp"
//            case .upUp?, .upUpUp?:
//                return "DoubleUp"
//            case .down?:
//                return "SingleDown"
//            case .downDown?, .downDownDown?:
//                return "DoubleDown"
//            case .flat?:
//                return "Flat"
//            case .none:
//                return nil
//            }
//        }()

}

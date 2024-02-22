//
//  CMMotionManager_Extension.swift
//  Sensors
//
//  Created by Etienne Vautherin on 22/02/2024.
//

import CoreMotion

extension CMMotionManager {
    var accelerationUpdates: AsyncThrowingStream<CMAccelerometerData, Error> {
        AsyncThrowingStream<CMAccelerometerData, Error>(
            bufferingPolicy: .bufferingNewest(1)
        ) { continuation in
            
            defaultLog.debug("*** startAccelerometerUpdates")
            self.accelerometerUpdateInterval = 0.02
            self.startAccelerometerUpdates(to: OperationQueue()) { data, error in
                if let error {
                    continuation.finish(throwing: error)
                }
                
                if let data {
                    continuation.yield(data)
                }
            }
            
            continuation.onTermination = { termination in
                defaultLog.debug("*** stopAccelerometerUpdates")
                self.stopAccelerometerUpdates()
            }
        }
    }
}


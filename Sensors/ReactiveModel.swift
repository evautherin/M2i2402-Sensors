//
//  ReactiveModel.swift
//  Sensors
//
//  Created by Etienne Vautherin on 21/02/2024.
//

import OSLog
import SwiftUI
import CoreMotion
import AsyncExtensions

@Observable
class ReactiveModel {
    var started = false
    var acceleration: CMAcceleration?
    var showError = false
    var errorString = ""
    
    private let manager = CMMotionManager()
    private var fileIndex = 0
    private var directoryURL: URL
    private var accelerations = [CMAccelerometerData]()
    
    typealias AccelerationContinuation = AsyncThrowingStream<CMAccelerometerData, Swift.Error>.Continuation
    private var continuation: AccelerationContinuation?
    
    enum Error: Swift.Error {
        case documentDirectory
        case accelerometer
    }
    
    init?() {
        do {
            let fm = FileManager.default
            let documentURL = fm.urls(for: .documentDirectory, in: .userDomainMask).last
            guard let documentURL else {
                throw Error.documentDirectory
            }
            
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd_HHmmss"
            let dateString = formatter.string(from: Date())
            self.directoryURL = documentURL.appendingPathComponent("BinaryData \(dateString).csv")
            if !fm.fileExists(atPath: directoryURL.path) {
                try fm.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
            }
        } catch {
            defaultLog.error("File system error: \(error.localizedDescription)")
            return nil
        }
        
        let accelerationSequence = AsyncThrowingStream<CMAccelerometerData, Swift.Error>(
            bufferingPolicy: .bufferingNewest(1)
        ) { continuation in
            defaultLog.debug("Setting continuation")
            self.continuation = continuation
            
            continuation.onTermination = { [self] termination in
                defaultLog.debug("Sequence terminated")
                self.manager.stopAccelerometerUpdates()
                self.started = false
                
                defaultLog.debug("Got accelerations: \(self.accelerations.count)")
            }
        }

        Task {
            do {
                for try await data in accelerationSequence {
                    defaultLog.debug("Received data: \(data)")
                    self.acceleration = data.acceleration
                    self.accelerations.append(data)
                }
            } catch {
                setError("\(error.localizedDescription)")
            }
        }
    }
    
    func setError(_ message: String) {
        defaultLog.error("\(message)")
        errorString = message
        showError = true
    }
    
    func clearError() {
        errorString = ""
    }
    
    func startAccelSensor() {
        self.started = true
        manager.accelerometerUpdateInterval = 0.02
        manager.startAccelerometerUpdates(to: OperationQueue()) { [self] data, error in
            if error != nil {
                self.continuation?.finish(throwing: Error.accelerometer)
                return
            }
            
            guard let data else { return }
            defaultLog.debug("Emitting data: \(data)")
            self.continuation?.yield(data)
        }
    }
        
    func stopAccelSensor() {
        self.continuation?.finish()
    }
}

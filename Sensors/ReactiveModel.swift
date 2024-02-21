//
//  ReactiveModel.swift
//  Sensors
//
//  Created by Etienne Vautherin on 21/02/2024.
//

import OSLog
import SwiftUI
import CoreMotion
import AsyncAlgorithms
import AsyncExtensions

@Observable
class ReactiveModel {
    var started: Bool { accelerometerTasks != .none }
    var acceleration: CMAcceleration?
    var showError = false
    var errorString = ""
    
    private let manager = CMMotionManager()
    private var accelerometerTasks: Task<(), Swift.Error>?
    private var fileIndex = 0
    private var directoryURL: URL
    private var accelerations = [CMAccelerometerData]()
    
    typealias AccelerationContinuation = AsyncThrowingStream<CMAccelerometerData, Swift.Error>.Continuation
    private var continuation: AccelerationContinuation?
    
    enum Error: Swift.Error {
        case documentDirectory
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
        
//        let accelerationSequence = AsyncThrowingStream<CMAccelerometerData, Swift.Error>(
//            bufferingPolicy: .bufferingNewest(1)
//        ) { continuation in
//            defaultLog.debug("Setting continuation")
//            self.continuation = continuation
//            
//            continuation.onTermination = { [self] termination in
//                defaultLog.debug("Sequence terminated")
//                self.manager.stopAccelerometerUpdates()
//                
//                defaultLog.debug("Got accelerations: \(self.accelerations.count)")
//            }
//        }
//
//        Task {
//            do {
//                for try await data in accelerationSequence {
//                    defaultLog.debug("Received data: \(data)")
//                    self.acceleration = data.acceleration
//                    self.accelerations.append(data)
//                }
//            } catch {
//                setError("\(error.localizedDescription)")
//            }
//        }
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
        let accelerationUpdates = AsyncAccelerometer(manager: manager).accelerationUpdates.share()
        let chunks = accelerationUpdates.chunked(by: .repeating(every: .seconds(5)))
        let indexedChunks = chunks.scan((0, [CMAccelerometerData]())) { previousIndexedChunk, chunk in
            let (previousIndex, _) = previousIndexedChunk
            return (previousIndex + 1, chunk)
        }

        self.accelerometerTasks = Task {
            await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    for try await (i, chunk) in indexedChunks {
                        defaultLog.debug("Chunk #\(i) with \(chunk.count) elements")
                    }
                }
                
                group.addTask {
                    for try await data in accelerationUpdates {
                        self.acceleration = data.acceleration
                    }
                }
            }
        }
        
    }
        
    func stopAccelSensor() {
        self.accelerometerTasks?.cancel()
        self.accelerometerTasks = .none
    }
}

struct AsyncAccelerometer {
    let manager: CMMotionManager
    
    var accelerationUpdates: AsyncThrowingStream<CMAccelerometerData, Error> {
        AsyncThrowingStream<CMAccelerometerData, Error>(
            bufferingPolicy: .bufferingNewest(1)
        ) { continuation in
            
            defaultLog.debug("*** startAccelerometerUpdates")
            manager.accelerometerUpdateInterval = 0.02
            manager.startAccelerometerUpdates(to: OperationQueue()) { data, error in
                if let error {
                    continuation.finish(throwing: error)
                }
                
                if let data {
                    continuation.yield(data)
                }
            }
            
            continuation.onTermination = { termination in
                defaultLog.debug("*** stopAccelerometerUpdates")
                manager.stopAccelerometerUpdates()
            }
        }
    }
}

//
//  ReactiveModel.swift
//  Sensors
//
//  Created by Etienne Vautherin on 21/02/2024.
//

import OSLog
import SwiftUI
import CoreMotion
import simd
import AsyncAlgorithms
import AsyncExtensions

@Observable
class ReactiveModel {
    var started: Bool { accelerometerTasks != .none }
    var acceleration: SIMD3<Double>?
//    var showError = false
//    var errorString = ""
    var displayableError = DisplayableError.noError
    
    private let manager = CMMotionManager()
    private var accelerometerTasks: Task<(), Swift.Error>?
    
    typealias AccelerationContinuation = AsyncThrowingStream<CMAccelerometerData, Swift.Error>.Continuation
    private var continuation: AccelerationContinuation?
    
    enum Error: Swift.Error {
        case documentDirectory
    }
    
    enum DisplayableError: Equatable {
        case noError
        case error(String)
    }
    
    
    func setError(_ message: String) {
        defaultLog.error("\(message)")
//        errorString = message
//        showError = true
        
        self.displayableError = .error(message)
    }
    
    func clearError() {
//        errorString = ""
        self.displayableError = .noError
    }
    
    func startAccelSensor() {
        typealias AccelerometerData = (SIMD3<Double>, TimeInterval)
        let period = 0.5
        let accelerationUpdates = manager.accelerationUpdates.share()
                
        let indexedChunks = accelerationUpdates
            .chunked(by: .repeating(every: .seconds(5)))
            .scan((0, [CMAccelerometerData]())) { previousIndexedChunk, chunk in
                let (previousIndex, _) = previousIndexedChunk
                return (previousIndex + 1, chunk)
            }
        
        let filteredAccelerations = accelerationUpdates
            .scan(AccelerometerData?.none) { state, data in
                let acceleration = SIMD3<Double>(
                    data.acceleration.x,
                    data.acceleration.y,
                    data.acceleration.z
                )
                guard let (filtered0, timestamp0) = state else {
                    return (acceleration, data.timestamp)
                }
                let timestamp1 = data.timestamp
                let dt = timestamp1 - timestamp0
                
                guard dt > 0.0, dt < period else {
                    return (acceleration, data.timestamp)
                }
                
                let ratio = dt/period
                let filteredAcceleration = filtered0*(1.0 - ratio) + acceleration*ratio
                return (filteredAcceleration, data.timestamp)
            }
            .map { $0! }
            .removeDuplicates {
                $1.1 - $0.1 < period
            }

        self.accelerometerTasks = Task { [self] in
            await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    do {
                        let directoryURL = try self.createDirectory()
                        
                        for try await (i, chunk) in indexedChunks {
                            defaultLog.debug("Chunk #\(i) with \(chunk.count) elements")
                            try self.write(indexedChunk: (i, chunk), directoryURL: directoryURL)
                        }
                    } catch {
                        self.setError("\(error.localizedDescription)")
                    }
                }
                
                group.addTask {
                    for try await data in filteredAccelerations {
                        let (acceleration, _) = data
                        self.acceleration = acceleration
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

extension ReactiveModel {
    func createDirectory() throws -> URL {
        let fm = FileManager.default
        let documentURL = fm.urls(for: .documentDirectory, in: .userDomainMask).last
        guard let documentURL else {
            throw Error.documentDirectory
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let dateString = formatter.string(from: Date())
        let directoryURL = documentURL.appendingPathComponent("BinaryData \(dateString)")
        if !fm.fileExists(atPath: directoryURL.path) {
            try fm.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
        }
        return directoryURL
    }

    // MARK: File System
    func write(indexedChunk: (Int, [CMAccelerometerData]), directoryURL: URL) throws {
        let (fileIndex, accelerations) = indexedChunk
        let fileName = String(format: "%05d.csv", fileIndex)
        
        let csvData = accelerations
            .map { data in
                
                func ms2(_ x: Double) -> Float {
                    Float(x*9.81)
                }

                let (x,y,z) = (
                    ms2(data.acceleration.x),
                    ms2(data.acceleration.y),
                    ms2(data.acceleration.z)
                )
                return "\(x)\t\(y)\t\(z)\t\(data.timestamp)"
            }
            .joined(separator: "\n")
            .data(using: .utf8)
        
        guard let csvData else {
            setError("Cannot create data with accelerations")
            return
        }
        
        let fileURL = directoryURL.appendingPathComponent("\(fileName)")
        try csvData.write(to: fileURL)
        defaultLog.debug("Accelerations (\(accelerations.count) written to \(fileURL.absoluteString)")
    }
}

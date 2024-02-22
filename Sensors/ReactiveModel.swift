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
            self.directoryURL = documentURL.appendingPathComponent("BinaryData \(dateString)")
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
        let accelerationUpdates = manager.accelerationUpdates.share()
        let chunks = accelerationUpdates.chunked(by: .repeating(every: .seconds(5)))
        let indexedChunks = chunks.scan((0, [CMAccelerometerData]())) { previousIndexedChunk, chunk in
            let (previousIndex, _) = previousIndexedChunk
            return (previousIndex + 1, chunk)
        }

        self.accelerometerTasks = Task {
            await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    do {
                        for try await (i, chunk) in indexedChunks {
                            defaultLog.debug("Chunk #\(i) with \(chunk.count) elements")
                            try self.write(indexedChunk: (i, chunk))
                        }
                    } catch {
                        self.setError("\(error.localizedDescription)")
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
    
    func write(indexedChunk: (Int, [CMAccelerometerData])) throws {
        let (fileIndex, accelerations) = indexedChunk
        let fileName = String(format: "%05d.csv", fileIndex)
        self.fileIndex += 1
        
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
        
    func stopAccelSensor() {
        self.accelerometerTasks?.cancel()
        self.accelerometerTasks = .none
    }
}

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

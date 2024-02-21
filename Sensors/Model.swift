//
//  Model.swift
//  Sensors
//
//  Created by Etienne Vautherin on 20/02/2024.
//

import OSLog
import SwiftUI
import CoreMotion

@Observable
class Model {
    var started = false
    var acceleration: CMAcceleration?
    var showError = false
    var errorString = ""
    
    private let manager = CMMotionManager()
    private var fileIndex = 0
    private var directoryURL: URL
    private var accelerations = [CMAccelerometerData]()
    
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
            if let error {
                setError("Accelerometer error: \(error.localizedDescription)")
                return
            }
            
            guard let data else { return }
            self.acceleration = data.acceleration
            self.accelerations.append(data)
        }
    }
    
    func stopAccelSensor() {
        manager.stopAccelerometerUpdates()
        self.started = false
        let fileName = String(format: "%05d", fileIndex)
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
        do {
            try csvData.write(to: fileURL)
            defaultLog.debug("Accelerations (\(self.accelerations.count) written to \(fileURL.absoluteString)")
            self.accelerations = []
        } catch {
            setError("Writing error: \(error.localizedDescription)")
        }
    }
}

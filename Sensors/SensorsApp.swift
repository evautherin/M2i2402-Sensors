//
//  SensorsApp.swift
//  Sensors
//
//  Created by Etienne Vautherin on 20/02/2024.
//

import OSLog
import SwiftUI

let defaultLog = Logger()

@main
struct SensorsApp: App {
    var model: Model
    
    init() {
        guard let model = Model() else {
            defaultLog.critical("Cannot insanciate model")
            exit(1)
        }
        
        self.model = model
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(model: self.model)
        }
    }
}

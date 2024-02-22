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
    typealias Model = ReactiveModel
        
    var body: some Scene {
        WindowGroup {
            ContentView().environment(Model())
        }
    }
}

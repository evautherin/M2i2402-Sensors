//
//  ContentView.swift
//  Sensors
//
//  Created by Etienne Vautherin on 20/02/2024.
//

import SwiftUI

struct ContentView: View {    
    @Bindable var model: SensorsApp.Model
    
    var body: some View {
        VStack {
            if model.started {
                if let acceleration = model.acceleration {
                    VStack {
                        Text("x: \(acceleration.x)")
                        Text("y: \(acceleration.y)")
                        Text("z: \(acceleration.z)")
                    }
                }
            } else {
                Button("Start") {
                    model.startAccelSensor()
                }
            }
            Button("Stop") {
                model.stopAccelSensor()
            }.padding()
            Button("Error") {
                model.setError("Big error")
            }
        }
        .padding()
        .alert(model.errorString, isPresented: $model.showError) {
            Button("OK") {
                model.clearError()
            }
        }
    }
}

#Preview {
    ContentView(model: SensorsApp.Model()!)
}

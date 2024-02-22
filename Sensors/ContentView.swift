//
//  ContentView.swift
//  Sensors
//
//  Created by Etienne Vautherin on 20/02/2024.
//

import SwiftUI

struct ContentView: View {    
    @Environment(SensorsApp.Model.self) var model: SensorsApp.Model
    @State var showError = false
    
    var errorMessage: String {
        switch model.displayableError {
        case .noError: return ""
        case .error(let message): return message
        }
    }
    
    var body: some View {
        VStack {
            if model.started {
                if let acceleration = model.acceleration {
                    VStack {
                        Text("x: \(acceleration.x)")
                        Text("y: \(acceleration.y)")
                        Text("z: \(acceleration.z)")
                        Button("Stop") {
                            model.stopAccelSensor()
                        }.padding()
                    }
                }
            } else {
                Button("Start") {
                    model.startAccelSensor()
                }.padding()
            }
            Button("Error") {
                model.setError("Big error")
            }.padding()
        }
        .padding()
        .alert(errorMessage, isPresented: $showError) {
            Button("OK") {
                model.clearError()
            }
        }
        .onChange(of: model.displayableError) { oldValue, newValue in
            switch newValue {
            case .noError: self.showError = false
            case .error(_): self.showError = true
            }
        }
    }
}

#Preview {
    ContentView().environment(SensorsApp.Model())
}

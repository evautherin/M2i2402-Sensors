//
//  Model.swift
//  Sensors
//
//  Created by Etienne Vautherin on 21/02/2024.
//

import Foundation
import CoreMotion


protocol ModelProtocol {
    var started: Bool { get set }
    var acceleration: CMAcceleration? { get set }
    var showError: Bool { get set }
    var errorString: String { get set }
}

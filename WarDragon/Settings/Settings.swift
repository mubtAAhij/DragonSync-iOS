//
//  Settings.swift
//  WarDragon
//
//  Created by Luke on 11/23/24.
//

import Foundation
import SwiftUI

enum ConnectionMode: String, Codable, CaseIterable {
    case multicast = "Multicast"
    case zmq = "Direct ZMQ"
    case both = "Both"
    
    var icon: String {
        switch self {
        case .multicast:
            return "antenna.radiowaves.left.and.right"
        case .zmq:
            return "network"
        case .both:
            return "network.badge.shield.half.filled"
        }
    }
}

class Settings: ObservableObject {
    static let shared = Settings()
    
    @AppStorage("connectionMode") private(set) var connectionMode: ConnectionMode = .multicast
    @AppStorage("zmqHost") private(set) var zmqHost: String = "0.0.0.0"
    @AppStorage("multicastHost") private(set) var multicastHost: String = "239.3.2.1"
    @AppStorage("notificationsEnabled") private(set) var notificationsEnabled = true
    @AppStorage("keepScreenOn") private(set) var keepScreenOn = false
    @AppStorage("telemetryPort") private(set) var telemetryPort: Int = 6969
    @AppStorage("statusPort") private(set) var statusPort: Int = 4225
    @AppStorage("isListening") private(set) var isListening = false
    
    var activeHost: String {
        switch connectionMode {
        case .multicast:
            return multicastHost
        case .zmq:
            return zmqHost
        case .both:
            return "\(multicastHost) and \(zmqHost)"
        }
    }
    
    private init() {
        toggleListening(false)
    }
    
    func updateConnection(mode: ConnectionMode, host: String? = nil) {
        if let host = host {
            switch mode {
            case .multicast:
                multicastHost = host
            case .zmq:
                zmqHost = host
            case .both:
                break
            }
        }
        connectionMode = mode

        telemetryPort = (mode == .zmq) ? 4224 : 6969
        
        objectWillChange.send()
    }

    
    func toggleListening(_ active: Bool) {
        isListening = active
        objectWillChange.send()
    }
    
    func updatePreferences(notifications: Bool, screenOn: Bool) {
        notificationsEnabled = notifications
        keepScreenOn = screenOn
        UIApplication.shared.isIdleTimerDisabled = screenOn
        objectWillChange.send()
    }
}

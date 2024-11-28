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
    
    @AppStorage("connectionMode") var connectionMode: ConnectionMode = .multicast {
        didSet {
            objectWillChange.send()
        }
    }
    @AppStorage("zmqHost") var zmqHost: String = "0.0.0.0" {
        didSet {
            objectWillChange.send()
        }
    }
    @AppStorage("multicastHost") var multicastHost: String = "224.0.0.1" {
        didSet {
            objectWillChange.send()
        }
    }
    @AppStorage("notificationsEnabled") var notificationsEnabled = true {
        didSet {
            objectWillChange.send()
        }
    }
    @AppStorage("keepScreenOn") var keepScreenOn = false {
        didSet {
            objectWillChange.send()
            UIApplication.shared.isIdleTimerDisabled = keepScreenOn
        }
    }
    @AppStorage("multicastPort") var multicastPort: Int = 6969 {
        didSet {
            objectWillChange.send()
        }
    }
    @AppStorage("zmqTelemetryPort") var zmqTelemetryPort: Int = 4224 {
        didSet {
            objectWillChange.send()
        }
    }
    @AppStorage("zmqStatusPort") var zmqStatusPort: Int = 4225 {
        didSet {
            objectWillChange.send()
        }
    }
    @AppStorage("isListening") var isListening = false {
        didSet {
            objectWillChange.send()
        }
    }
    
    private init() {
        toggleListening(false)
    }
    
    func updateConnection(mode: ConnectionMode, host: String? = nil, isZmqHost: Bool = false) {
        if let host = host {
            if isZmqHost {
                zmqHost = host
            } else {
                multicastHost = host
            }
        }
        
        connectionMode = mode
    }
    
    func isHostConfigurationValid() -> Bool {
        switch connectionMode {
        case .multicast:
            return !multicastHost.isEmpty
        case .zmq:
            return !zmqHost.isEmpty
        case .both:
            return !multicastHost.isEmpty && !zmqHost.isEmpty
        }
    }
    
    func toggleListening(_ active: Bool) {
        if active == isListening {
            return
        }
        
        // Set the state first
        isListening = active
        objectWillChange.send()
    }
    
    func updatePreferences(notifications: Bool, screenOn: Bool) {
        notificationsEnabled = notifications
        keepScreenOn = screenOn
    }
}

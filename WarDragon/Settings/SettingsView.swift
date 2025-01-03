//
//  SettingsView.swift
//  WarDragon
//
//  Created by Luke on 11/23/24.
//

import SwiftUI
import Network
import UIKit

struct SettingsView: View {
    @ObservedObject var cotHandler : CoTViewModel
    @StateObject private var settings = Settings.shared
    
    var body: some View {
        Form {
            Section("Connection") {
                HStack {
                    Image(systemName: connectionStatusSymbol)
                        .foregroundStyle(connectionStatusColor)
                        .symbolEffect(.bounce, options: .repeat(3), value: cotHandler.isListeningCot)
                    Text(connectionStatusText)
                        .foregroundStyle(connectionStatusColor)
                }
                
                Picker("Mode", selection: .init(
                    get: { settings.connectionMode },
                    set: { settings.updateConnection(mode: $0) }
                )) {
                    ForEach(ConnectionMode.allCases, id: \.self) { mode in
                        HStack {
                            Image(systemName: mode.icon)
                            Text(mode.rawValue)
                        }
                        .tag(mode)
                    }
                }
                .disabled(settings.isListening)
                
                if settings.connectionMode == .zmq {
                    TextField("ZMQ Host", text: .init(
                        get: { settings.zmqHost },
                        set: { settings.updateConnection(mode: settings.connectionMode, host: $0, isZmqHost: true) }
                    ))
                    .textContentType(.URL)
                    .autocapitalization(.none)
                    .disabled(settings.isListening)
                } else {
                    TextField("Multicast Host", text: .init(
                        get: { settings.multicastHost },
                        set: { settings.updateConnection(mode: settings.connectionMode, host: $0, isZmqHost: false) }
                    ))
                    .textContentType(.URL)
                    .autocapitalization(.none)
                    .disabled(settings.isListening)
                }
                
                Toggle(isOn: .init(
                    get: { settings.isListening && cotHandler.isListeningCot },
                    set: { newValue in
                        if newValue {
                            settings.toggleListening(true)
                            cotHandler.startListening()
                        } else {
                            settings.toggleListening(false)
                            cotHandler.stopListening()
                        }
                    }
                )) {
                    Text(settings.isListening && cotHandler.isListeningCot ? "Active" : "Inactive")
                }
                .disabled(!settings.isHostConfigurationValid())
            }
            
            Section("Preferences") {
                Toggle("Enable Notifications", isOn: .init(
                    get: { settings.notificationsEnabled },
                    set: { settings.updatePreferences(notifications: $0, screenOn: settings.keepScreenOn) }
                ))
                
                Toggle("Auto Spoof Detection", isOn: .init(
                    get: { settings.spoofDetectionEnabled },
                    set: { settings.spoofDetectionEnabled = $0 }
                ))
                
                Toggle("Keep Screen On", isOn: .init(
                    get: { settings.keepScreenOn },
                    set: { settings.updatePreferences(notifications: settings.notificationsEnabled, screenOn: $0) }
                ))
            }
            
            Section("Ports") {
                switch settings.connectionMode {
                case .multicast:
                    HStack {
                        Text("Multicast")
                        Spacer()
                        Text(verbatim: String(settings.multicastPort))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    
                case .zmq:
                    HStack {
                        Text("ZMQ Telemetry")
                        Spacer()
                        Text(verbatim: String(settings.zmqTelemetryPort))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    HStack {
                        Text("ZMQ Status")
                        Spacer()
                        Text(verbatim: String(settings.zmqStatusPort))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    
//                case .both:
//                    HStack {
//                        Text("Multicast")
//                        Spacer()
//                        Text(verbatim: String(settings.multicastPort))
//                            .foregroundStyle(.secondary)
//                            .monospacedDigit()
//                    }
//                    HStack {
//                        Text("ZMQ Telemetry")
//                        Spacer()
//                        Text(verbatim: String(settings.zmqTelemetryPort))
//                            .foregroundStyle(.secondary)
//                            .monospacedDigit()
//                    }
//                    HStack {
//                        Text("ZMQ Status")
//                        Spacer()
//                        Text(verbatim: String(settings.zmqStatusPort))
//                            .foregroundStyle(.secondary)
//                            .monospacedDigit()
//                    }
                }
            }
            
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                        .foregroundStyle(.secondary)
                }
                
                Link(destination: URL(string: "https://github.com/Root-Down-Digital/DragonSync-iOS")!) {
                    HStack {
                        Text("Source Code")
                        Spacer()
                        Image(systemName: "arrow.up.right.circle")
                    }
                }
            }
        }
        .navigationTitle("Settings")
    }
    
    private var connectionStatusSymbol: String {
        if cotHandler.isListeningCot {
            switch settings.connectionMode {
            case .multicast:
                return "antenna.radiowaves.left.and.right.circle.fill"
            case .zmq:
                return "network.badge.shield.half.filled"
//            case .both:
//                return "network.slash.circle.fill"
            }
        } else {
            return "bolt.horizontal.circle"
        }
    }
    
    private var connectionStatusColor: Color {
        if settings.isListening {
            return .green  // Always green when listening
        } else {
            return .red
        }
    }
    
    private var connectionStatusText: String {
        if settings.isListening {
            if cotHandler.isListeningCot {
                return "Connected"
            } else {
                return "Listening..."
            }
        } else {
            return "Disconnected"
        }
    }
}

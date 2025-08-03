//
//  SettingsView.swift
//  WarDragon
//
//  Created by Luke on 11/23/24.
//

import SwiftUI
import UIKit
import Network

struct SettingsView: View {
    @ObservedObject var cotHandler : CoTViewModel
    @StateObject private var settings = Settings.shared
    
    var body: some View {
        Form {
            Section(String(localized: "settings_connection", comment: "Connection settings section")) {
                HStack {
                    Image(systemName: connectionStatusSymbol)
                        .foregroundStyle(connectionStatusColor)
                        .symbolEffect(.bounce, options: .repeat(3), value: cotHandler.isListeningCot)
                    Text(connectionStatusText)
                        .foregroundStyle(connectionStatusColor)
                }
                
                Picker(String(localized: "connection_mode", comment: "Connection mode picker"), selection: .init(
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
                    HStack {
                        TextField(String(localized: "zmq_host", comment: "ZMQ host field label"), text: .init(
                            get: { settings.zmqHost },
                            set: { settings.updateConnection(mode: settings.connectionMode, host: $0, isZmqHost: true) }
                        ))
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .disabled(settings.isListening)
                        
                        if !settings.zmqHostHistory.isEmpty {
                            Menu {
                                ForEach(settings.zmqHostHistory, id: \.self) { host in
                                    Button(host) {
                                        settings.updateConnection(mode: settings.connectionMode, host: host, isZmqHost: true)
                                        settings.updateConnectionHistory(host: host, isZmq: true)
                                    }
                                }
                            } label: {
                                Image(systemName: "clock.arrow.circlepath")
                            }
                            .disabled(settings.isListening)
                        }
                    }
                } else {
                    HStack {
                        TextField(String(localized: "multicast_host", comment: "Multicast host field label"), text: .init(
                            get: { settings.multicastHost },
                            set: { settings.updateConnection(mode: settings.connectionMode, host: $0, isZmqHost: false) }
                        ))
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .disabled(settings.isListening)
                        
                        if !settings.multicastHostHistory.isEmpty {
                            Menu {
                                ForEach(settings.multicastHostHistory, id: \.self) { host in
                                    Button(host) {
                                        settings.updateConnection(mode: settings.connectionMode, host: host, isZmqHost: false)
                                        settings.updateConnectionHistory(host: host, isZmq: false)
                                    }
                                }
                            } label: {
                                Image(systemName: "clock.arrow.circlepath")
                            }
                            .disabled(settings.isListening)
                        }
                    }
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
                    Text(settings.isListening && cotHandler.isListeningCot ? String(localized: "connection_active", comment: "Connection active status") : String(localized: "connection_inactive", comment: "Connection inactive status"))
                }
                .disabled(!settings.isHostConfigurationValid())
            }
            
            Section(String(localized: "settings_preferences", comment: "Preferences settings section")) {
                Toggle(String(localized: "auto_spoof_detection", comment: "Auto spoof detection toggle"), isOn: .init(
                    get: { settings.spoofDetectionEnabled },
                    set: { settings.spoofDetectionEnabled = $0 }
                ))
                
                Toggle(String(localized: "keep_screen_on", comment: "Keep screen on toggle"), isOn: .init(
                    get: { settings.keepScreenOn },
                    set: { settings.updatePreferences(notifications: settings.notificationsEnabled, screenOn: $0) }
                ))
                
                Toggle(String(localized: "enable_background_detection", comment: "Background detection toggle"), isOn: .init(
                    get: { settings.enableBackgroundDetection },
                    set: { settings.enableBackgroundDetection = $0 }
                ))
                .disabled(settings.isListening) // Can't change while listening is active
            }
            
            Section(String(localized: "settings_notifications", comment: "Notifications settings section")) {
                Toggle(String(localized: "enable_push_notifications", comment: "Push notifications toggle"), isOn: .init(
                    get: { settings.notificationsEnabled },
                    set: { settings.updatePreferences(notifications: $0, screenOn: settings.keepScreenOn) }
                ))
                
                if settings.notificationsEnabled {
                    NavigationLink(destination: StatusNotificationSettingsView()) {
                        HStack {
                            Image(systemName: "bell.circle.fill")
                                .foregroundColor(.orange)
                            VStack(alignment: .leading) {
                                Text(String(localized: "notification_settings", comment: "Notification settings link"))
                                Text(String(localized: "configure_frequency_types", comment: "Notification settings description"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    Text(String(localized: "notifications_description", comment: "Description of push notifications feature"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section(String(localized: "webhooks_external_services", comment: "Webhooks settings section")) {
                Toggle(String(localized: "enable_webhooks", comment: "Webhooks toggle"), isOn: .init(
                    get: { settings.webhooksEnabled },
                    set: { settings.updateWebhookSettings(enabled: $0) }
                ))
                
                if settings.webhooksEnabled {
                    NavigationLink(destination: WebhookSettingsView()) {
                        HStack {
                            Image(systemName: "link.circle.fill")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text(String(localized: "webhook_services", comment: "Webhook services link"))
                                Text(String(localized: "services_configured", comment: "Number of configured webhook services").replacingOccurrences(of: "{count}", with: "\(WebhookManager.shared.configurations.count)"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    Text(String(localized: "webhooks_description", comment: "Description of webhooks feature"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section(String(localized: "settings_performance", comment: "Performance settings section")) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(String(localized: "message_processing_interval", comment: "Message processing interval setting"))
                        Spacer()
                        Stepper(value: $settings.messageProcessingInterval, in: 300...5000, step: 50) {
                            Text(String(localized: "milliseconds_unit", comment: "Milliseconds unit").replacingOccurrences(of: "{value}", with: "\(settings.messageProcessingInterval)"))
                                .font(.appCaption)
                                .bold()
                                .foregroundColor(.primary)
                                .frame(width: 100, alignment: .trailing)
                        }
                    }
                }
            }
            
            Section(String(localized: "warning_thresholds", comment: "Warning thresholds settings section")) {
                VStack(alignment: .leading) {
                    Toggle(String(localized: "system_warnings", comment: "System warnings toggle"), isOn: $settings.systemWarningsEnabled)
                        .padding(.bottom)
                    
                    if settings.systemWarningsEnabled {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 30) {
                                TacDial(
                                    title: String(localized: "cpu_usage_threshold", comment: "CPU usage threshold dial"),
                                    value: $settings.cpuWarningThreshold,
                                    range: 50...90,
                                    step: 5,
                                    unit: "%",
                                    color: .blue
                                )
                                
                                TacDial(
                                    title: String(localized: "system_temp_threshold", comment: "System temperature threshold dial"),
                                    value: $settings.tempWarningThreshold,
                                    range: 40...85,
                                    step: 5,
                                    unit: "°C",
                                    color: .red
                                )
                                
                                TacDial(
                                    title: String(localized: "memory_threshold", comment: "Memory threshold dial"),
                                    value: .init(
                                        get: { settings.memoryWarningThreshold * 100 },
                                        set: { settings.memoryWarningThreshold = $0 / 100 }
                                    ),
                                    range: 50...95,
                                    step: 5,
                                    unit: "%",
                                    color: .green
                                )
                                
                                TacDial(
                                    title: String(localized: "pluto_temp_threshold", comment: "Pluto temperature threshold dial"),
                                    value: $settings.plutoTempThreshold,
                                    range: 40...100,
                                    step: 5,
                                    unit: "°C",
                                    color: .purple
                                )
                                
                                TacDial(
                                    title: String(localized: "zynq_temp_threshold", comment: "Zynq temperature threshold dial"),
                                    value: $settings.zynqTempThreshold,
                                    range: 40...100,
                                    step: 5,
                                    unit: "°C",
                                    color: .orange
                                )
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                VStack(alignment: .leading) {
                    Toggle(String(localized: "proximity_warnings", comment: "Proximity warnings toggle"), isOn: $settings.enableProximityWarnings)
                        .padding(.vertical)
                    
                    if settings.enableProximityWarnings {
                        HStack {
                            TacDial(
                                title: String(localized: "rssi_threshold", comment: "RSSI threshold dial"),
                                value: .init(
                                    get: { Double(settings.proximityThreshold) },
                                    set: { settings.proximityThreshold = Int($0) }
                                ),
                                range: -90...(-30),
                                step: 5,
                                unit: "dBm",
                                color: .yellow
                            )
                        }
                        .padding(.horizontal)
                    }
                }
            }
            
            Section(String(localized: "settings_ports", comment: "Ports settings section")) {
                switch settings.connectionMode {
                case .multicast:
                    HStack {
                        Text(String(localized: "multicast", comment: "Multicast connection mode"))
                        Spacer()
                        Text(verbatim: String(settings.multicastPort))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    
                case .zmq:
                    HStack {
                        Text(String(localized: "zmq_telemetry", comment: "ZMQ telemetry section header"))
                        Spacer()
                        Text(verbatim: String(settings.zmqTelemetryPort))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    HStack {
                        Text(String(localized: "zmq_status", comment: "ZMQ status section header"))
                        Spacer()
                        Text(verbatim: String(settings.zmqStatusPort))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
            
            Section(String(localized: "about", comment: "About section header")) {
                HStack {
                    Text(String(localized: "version", comment: "Version label"))
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                        .foregroundStyle(.secondary)
                }
                
                Link(destination: URL(string: "https://github.com/Root-Down-Digital/DragonSync-iOS")!) {
                    HStack {
                        Text(String(localized: "source_code", comment: "Source code link label"))
                        Spacer()
                        Image(systemName: "arrow.up.right.circle")
                    }
                }
            }
        }
        .navigationTitle(String(localized: "settings", comment: "Settings navigation title"))
        .font(.appHeadline)
    }
    
    private var connectionStatusSymbol: String {
        if cotHandler.isListeningCot {
            switch settings.connectionMode {
            case .multicast:
                return "antenna.radiowaves.left.and.right.circle.fill"
            case .zmq:
                return "network.badge.shield.half.filled"
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
                return String(localized: "connected", comment: "Connection status - connected")
            } else {
                return String(localized: "listening", comment: "Connection status - listening")
            }
        } else {
            return String(localized: "disconnected", comment: "Connection status - disconnected")
        }
    }
}

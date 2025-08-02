//
//  WebhookEventsView.swift
//  WarDragon
//
//  Created by Luke on 6/23/25.
//

import SwiftUI

struct WebhookEventsView: View {
    @StateObject private var settings = Settings.shared
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(String(localized: "event_configuration", comment: "Event configuration section header"))) {
                    Text(String(localized: "event_configuration_help", comment: "Event configuration help text"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text(String(localized: "detection_events", comment: "Detection events section header"))) {
                    EventToggleRow(event: .droneDetected, settings: settings)
                    EventToggleRow(event: .fpvSignal, settings: settings)
                    EventToggleRow(event: .proximityWarning, settings: settings)
                }
                
                Section(header: Text(String(localized: "system_events", comment: "System events section header"))) {
                    EventToggleRow(event: .systemAlert, settings: settings)
                    EventToggleRow(event: .temperatureAlert, settings: settings)
                    EventToggleRow(event: .memoryAlert, settings: settings)
                    EventToggleRow(event: .cpuAlert, settings: settings)
                    
                    // Quick Actions for System Events
                    HStack {
                        Button(String(localized: "enable_all_system_events", comment: "Enable all system events button text")) {
                            var events = settings.enabledWebhookEvents
                            let systemEvents: [WebhookEvent] = [.systemAlert, .temperatureAlert, .memoryAlert, .cpuAlert]
                            for event in systemEvents {
                                events.insert(event)
                            }
                            settings.enabledWebhookEvents = events
                        }
                        .disabled(systemEventsAllEnabled)
                        .font(.caption)
                        
                        Spacer()
                        
                        Button(String(localized: "disable_all_system_events", comment: "Disable all system events button text")) {
                            var events = settings.enabledWebhookEvents
                            let systemEvents: [WebhookEvent] = [.systemAlert, .temperatureAlert, .memoryAlert, .cpuAlert]
                            for event in systemEvents {
                                events.remove(event)
                            }
                            settings.enabledWebhookEvents = events
                        }
                        .disabled(systemEventsAllDisabled)
                        .foregroundColor(.red)
                        .font(.caption)
                    }
                }
                
                Section(header: Text(String(localized: "connection_events", comment: "Connection events section header"))) {
                    EventToggleRow(event: .connectionLost, settings: settings)
                    EventToggleRow(event: .connectionRestored, settings: settings)
                }
                
                Section(header: Text(String(localized: "quick_actions", comment: "Quick actions section header"))) {
                    HStack {
                        Button(String(localized: "enable_all_events", comment: "Enable all events button text")) {
                            settings.enabledWebhookEvents = Set(WebhookEvent.allCases)
                        }
                        .disabled(allEventsEnabled)
                        
                        Spacer()
                        
                        Button(String(localized: "disable_all_events", comment: "Button to disable all webhook events")) {
                            settings.enabledWebhookEvents = []
                        }
                        .disabled(allEventsDisabled)
                        .foregroundColor(.red)
                    }
                }
                
                Section(header: Text(String(localized: "event_summary", comment: "Section header for event summary"))) {
                    HStack {
                        Text(String(localized: "events_enabled", comment: "Label for number of enabled events"))
                        Spacer()
                        Text(String(localized: "events_count_format", comment: "Format showing X of Y events enabled").replacingOccurrences(of: "{count}", with: "\(settings.enabledWebhookEvents.count)").replacingOccurrences(of: "{total}", with: "\(WebhookEvent.allCases.count)"))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle(String(localized: "webhook_events", comment: "Navigation title for webhook events screen"))
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    // MARK: - Computed Properties
    
    private var systemEventsAllEnabled: Bool {
        let systemEvents: [WebhookEvent] = [.systemAlert, .temperatureAlert, .memoryAlert, .cpuAlert]
        return systemEvents.allSatisfy { settings.enabledWebhookEvents.contains($0) }
    }
    
    private var systemEventsAllDisabled: Bool {
        let systemEvents: [WebhookEvent] = [.systemAlert, .temperatureAlert, .memoryAlert, .cpuAlert]
        return systemEvents.allSatisfy { !settings.enabledWebhookEvents.contains($0) }
    }
    
    private var allEventsEnabled: Bool {
        return settings.enabledWebhookEvents.count == WebhookEvent.allCases.count
    }
    
    private var allEventsDisabled: Bool {
        return settings.enabledWebhookEvents.isEmpty
    }
}

struct EventToggleRow: View {
    let event: WebhookEvent
    @ObservedObject var settings: Settings
    
    var body: some View {
        HStack {
            Image(systemName: eventIcon)
                .foregroundColor(eventColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(event.displayName)
                    .font(.headline)
                Text(eventDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: .init(
                get: { settings.enabledWebhookEvents.contains(event) },
                set: { enabled in
                    var events = settings.enabledWebhookEvents
                    if enabled {
                        events.insert(event)
                    } else {
                        events.remove(event)
                    }
                    settings.enabledWebhookEvents = events
                }
            ))
        }
        .padding(.vertical, 4)
    }
    
    private var eventIcon: String {
        switch event {
        case .droneDetected: return "airplane.circle.fill"
        case .fpvSignal: return "antenna.radiowaves.left.and.right"
        case .proximityWarning: return "exclamationmark.triangle.fill"
        case .systemAlert: return "gear.circle.fill"
        case .temperatureAlert: return "thermometer"
        case .memoryAlert: return "memorychip.fill"
        case .cpuAlert: return "cpu.fill"
        case .connectionLost: return "wifi.slash"
        case .connectionRestored: return "wifi"
        }
    }
    
    private var eventColor: Color {
        switch event {
        case .droneDetected: return .blue
        case .fpvSignal: return .purple
        case .proximityWarning: return .orange
        case .systemAlert: return .gray
        case .temperatureAlert, .memoryAlert, .cpuAlert: return .red
        case .connectionLost: return .red
        case .connectionRestored: return .green
        }
    }
    
    private var eventDescription: String {
        switch event {
        case .droneDetected: return "When a new drone is detected"
        case .fpvSignal: return "When an FPV signal is detected"
        case .proximityWarning: return "When a drone comes too close"
        case .systemAlert: return "General system alerts"
        case .temperatureAlert: return "High temperature warnings"
        case .memoryAlert: return "High memory usage warnings"
        case .cpuAlert: return "High CPU usage warnings"
        case .connectionLost: return "When connection is lost"
        case .connectionRestored: return "When connection is restored"
        }
    }
}

#Preview {
    WebhookEventsView()
}

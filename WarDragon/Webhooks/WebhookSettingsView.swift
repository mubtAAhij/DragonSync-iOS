//
//  WebhookSettingsView.swift.swift
//  WarDragon
//
//  Created by Luke on 6/23/25.
//

import SwiftUI

struct WebhookSettingsView: View {
    @StateObject private var webhookManager = WebhookManager.shared
    @StateObject private var settings = Settings.shared
    @State private var showingAddWebhook = false
    @State private var selectedConfig: WebhookConfiguration?
    
    var body: some View {

        Form {
            Section(header: Text(String(localized: "webhook_system", comment: "Section header for webhook system settings"))) {
                Toggle(String(localized: "enable_webhooks", comment: "Toggle to enable webhook functionality"), isOn: .init(
                    get: { settings.webhooksEnabled },
                    set: { settings.updateWebhookSettings(enabled: $0) }
                ))
                
                if settings.webhooksEnabled {
                    Text(String(localized: "webhook_description", comment: "Description of webhook functionality"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if settings.webhooksEnabled {
                Section(header: Text(String(localized: "event_types", comment: "Section header for event type selection"))) {
                    Text(String(localized: "select_webhook_events", comment: "Description for event type selection"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Quick actions for all status notifications
                    HStack {
                        Image(systemName: "bell.slash.fill")
                            .foregroundColor(.gray)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: "disable_all_status_notifications", comment: "Toggle to disable all status notifications"))
                                .font(.headline)
                            Text(String(localized: "disable_status_description", comment: "Description for disabling status notifications"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: .init(
                            get: {
                                !settings.enabledWebhookEvents.contains(.systemAlert) &&
                                !settings.enabledWebhookEvents.contains(.temperatureAlert) &&
                                !settings.enabledWebhookEvents.contains(.memoryAlert) &&
                                !settings.enabledWebhookEvents.contains(.cpuAlert)
                            },
                            set: { enabled in
                                var events = settings.enabledWebhookEvents
                                if enabled {
                                    events.remove(.systemAlert)
                                    events.remove(.temperatureAlert)
                                    events.remove(.memoryAlert)
                                    events.remove(.cpuAlert)
                                } else {
                                    events.insert(.systemAlert)
                                    events.insert(.temperatureAlert)
                                    events.insert(.memoryAlert)
                                    events.insert(.cpuAlert)
                                }
                                settings.enabledWebhookEvents = events
                            }
                        ))
                    }
                    
                    // Individual event toggles
                    eventToggleRow(for: .droneDetected, title: String(localized: "drone_detection_title", comment: "Title for drone detection event toggle"), description: String(localized: "new_drone_detected", comment: "Description for drone detection event"), icon: "airplane.circle.fill", color: .blue)
                    // TODO merge FPV branch and SDR scripts..
//                    eventToggleRow(for: .fpvSignal, title: "FPV Signal", description: "FPV video signal detected", icon: "tv.fill", color: .purple)
//                    
                    eventToggleRow(for: .proximityWarning, title: String(localized: "proximity_warning_title", comment: "Title for proximity warning event toggle"), description: String(localized: "drone_approaching_threshold", comment: "Description for proximity warning event"), icon: "exclamationmark.triangle.fill", color: .orange)
                    
                    eventToggleRow(for: .systemAlert, title: String(localized: "system_alert_title", comment: "Title for system alert event toggle"), description: String(localized: "general_system_warnings", comment: "Description for system alert event"), icon: "exclamationmark.circle.fill", color: .red)
                    
                    eventToggleRow(for: .temperatureAlert, title: String(localized: "temperature_alert_title", comment: "Title for temperature alert event toggle"), description: String(localized: "high_temperature_warnings", comment: "Description for temperature alert event"), icon: "thermometer.high", color: .red)
                    
                    eventToggleRow(for: .memoryAlert, title: String(localized: "memory_alert_title", comment: "Title for memory alert event toggle"), description: String(localized: "high_memory_warnings", comment: "Description for memory alert event"), icon: "memorychip.fill", color: .yellow)
                    
                    eventToggleRow(for: .cpuAlert, title: String(localized: "cpu_alert_title", comment: "Title for CPU alert event toggle"), description: String(localized: "high_cpu_warnings", comment: "Description for CPU alert event"), icon: "cpu.fill", color: .red)
                }
                
                Section(header: Text(String(localized: "webhook_services", comment: "Section header for webhook services"))) {
                    if webhookManager.configurations.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(localized: "no_webhook_services", comment: "Message when no webhook services are configured"))
                                .foregroundColor(.secondary)
                            Text(String(localized: "add_webhook_services_description", comment: "Description of available webhook services"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        ForEach(webhookManager.configurations) { config in
                            WebhookRowView(config: config) {
                                selectedConfig = config
                            }
                        }
                        .onDelete(perform: deleteWebhooks)
                    }
                    
                    Button(String(localized: "add_webhook_service", comment: "Button to add a new webhook service")) {
                        showingAddWebhook = true
                    }
                    .foregroundColor(.blue)
                }
                
                Section(header: Text(String(localized: "recent_deliveries", comment: "Section header for recent webhook deliveries"))) {
                    if webhookManager.recentDeliveries.isEmpty {
                        Text(String(localized: "no_recent_deliveries", comment: "Message when no recent webhook deliveries exist"))
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(webhookManager.recentDeliveries.prefix(5)) { delivery in
                            WebhookDeliveryRowView(delivery: delivery)
                        }
                    }
                }
            }
        }
        .navigationTitle(String(localized: "webhooks", comment: "Navigation title for webhooks settings"))
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingAddWebhook) {
            WebhookConfigurationView(config: nil) { config in
                webhookManager.addConfiguration(config)
            }
        }
        .sheet(item: $selectedConfig) { config in
            WebhookConfigurationView(config: config) { updatedConfig in
                webhookManager.updateConfiguration(updatedConfig)
            }
        }
    }
    
    private func eventToggleRow(for event: WebhookEvent, title: String, description: String, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
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
    }
    
    private func deleteWebhooks(offsets: IndexSet) {
        for index in offsets {
            let config = webhookManager.configurations[index]
            webhookManager.removeConfiguration(config)
        }
    }
}

struct WebhookRowView: View {
    let config: WebhookConfiguration
    let onTap: () -> Void
    @StateObject private var webhookManager = WebhookManager.shared
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: config.type.icon)
                        .foregroundColor(colorForType(config.type))
                    Text(config.name)
                        .font(.headline)
                    Spacer()
                    if !config.isEnabled {
                        Text(String(localized: "disabled", comment: "Status label for disabled webhook"))
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                    }
                }
                
                Text(config.type.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(String(localized: "webhook_events_enabled_format", comment: "Format showing number of events enabled for webhook").replacingOccurrences(of: "{count}", with: "\(config.enabledEvents.count)"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: .init(
                get: { config.isEnabled },
                set: { _ in webhookManager.toggleWebhook(config) }
            ))
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
    
    private func colorForType(_ type: WebhookType) -> Color {
        switch type {
        case .ifttt: return .blue
        case .matrix: return .green
        case .discord: return .indigo
        case .custom: return .gray
        }
    }
}

struct WebhookDeliveryRowView: View {
    let delivery: WebhookManager.WebhookDelivery
    
    var body: some View {
        HStack {
            Image(systemName: delivery.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(delivery.success ? .green : .red)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(delivery.webhookName)
                    .font(.headline)
                Text(delivery.event.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let error = delivery.error {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(delivery.timestamp, style: .time)
                    .font(.caption)
                if let code = delivery.responseCode {
                    Text(String(localized: "http_status_format", comment: "Format for HTTP status code").replacingOccurrences(of: "{code}", with: "\(code)"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if delivery.retryAttempt > 0 {
                    Text(String(localized: "retry_attempt_format", comment: "Format for retry attempt number").replacingOccurrences(of: "{attempt}", with: "\(delivery.retryAttempt)"))
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
    }
}

#Preview {
    WebhookSettingsView()
}

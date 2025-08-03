//
//  StatusNotificationSettingsView.swift
//  WarDragon
//
//  Created by Luke on 6/23/25.
//


import SwiftUI

struct StatusNotificationSettingsView: View {
    @StateObject private var settings = Settings.shared
    
    var body: some View {
        Form {
            Section(header: Text(String(localized: "status_notifications_title", comment: "Status notifications section title"))) {
                Toggle("Enable Status Notifications", isOn: .init(
                    get: { settings.statusNotificationsEnabled },
                    set: { enabled in
                        settings.updateStatusNotificationSettings(
                            enabled: enabled,
                            interval: settings.statusNotificationInterval,
                            thresholds: settings.statusNotificationThresholds
                        )
                    }
                ))
                
                if settings.statusNotificationsEnabled {
                    Text("Receive system status updates on this device and via webhooks (if enabled)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if Settings.shared.webhooksEnabled {
                Section(header: Text("Webhook Status Notifications")) {
                    Toggle("Send Status to Webhooks", isOn: .init(
                        get: { settings.enabledWebhookEvents.contains(.systemAlert) },
                        set: { enabled in
                            var events = settings.enabledWebhookEvents
                            if enabled {
                                events.insert(.systemAlert)
                                events.insert(.temperatureAlert)
                                events.insert(.memoryAlert)
                                events.insert(.cpuAlert)
                            } else {
                                events.remove(.systemAlert)
                                events.remove(.temperatureAlert)
                                events.remove(.memoryAlert)
                                events.remove(.cpuAlert)
                            }
                            settings.enabledWebhookEvents = events
                        }
                    ))
                    
                    if settings.enabledWebhookEvents.contains(.systemAlert) {
                        Text(String(localized: "webhook_notifications_description", comment: "Description for webhook notifications"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if settings.statusNotificationsEnabled {
                Section(header: Text(String(localized: "notification_frequency_title", comment: "Notification frequency section title"))) {
                    ForEach(StatusNotificationInterval.allCases, id: \.self) { interval in
                        NotificationIntervalRow(
                            interval: interval,
                            isSelected: settings.statusNotificationInterval == interval
                        ) {
                            settings.updateStatusNotificationSettings(
                                enabled: settings.statusNotificationsEnabled,
                                interval: interval,
                                thresholds: settings.statusNotificationThresholds
                            )
                        }
                    }
                }
                
                // Show threshold alerts section for all intervals except never
                if settings.statusNotificationInterval != .never {
                    Section(header: Text(String(localized: "threshold_alerts_title", comment: "Threshold alerts section title"))) {
                        Toggle(String(localized: "enable_threshold_alerts", comment: "Toggle to enable threshold alerts"), isOn: .init(
                            get: { settings.statusNotificationThresholds },
                            set: { enabled in
                                settings.updateStatusNotificationSettings(
                                    enabled: settings.statusNotificationsEnabled,
                                    interval: settings.statusNotificationInterval,
                                    thresholds: enabled
                                )
                            }
                        ))
                        
                        if settings.statusNotificationThresholds {
                            if settings.statusNotificationInterval == .always {
                                Text(String(localized: "threshold_alerts_description_always", comment: "Description for threshold alerts when always sending"))
                            } else {
                                Text(String(localized: "threshold_alerts_description_regular", comment: "Description for threshold alerts with regular updates"))
                            }
                        }
                    }
                }
                
                
                Section(header: Text(String(localized: "current_status_title", comment: "Current status section title"))) {
                    StatusSummaryView()
                }
                
                Section(header: Text(String(localized: "preview_title", comment: "Preview section title"))) {
                    Button(String(localized: "send_test_notification", comment: "Button to send test notification")) {
                        sendTestStatusNotification()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .navigationTitle(String(localized: "status_notifications_nav_title", comment: "Navigation title for status notifications"))
        .navigationBarTitleDisplayMode(.large)
    }
    
    private func sendTestStatusNotification() {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "test_notification_title", comment: "Test notification title")
        content.body = String(localized: "test_notification_message", comment: "Test notification message content")
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
        
        // Also send webhook if enabled
        if Settings.shared.webhooksEnabled {
            let data: [String: Any] = [
                "title": String(localized: "test_notification_webhook_title", comment: "Test notification webhook title"),
                "message": "This is a test status notification from WarDragon",
                "cpu_usage": 45.0,
                "memory_usage": 60.0,
                "temperature": 65.0,
                "test": true
            ]
            
            WebhookManager.shared.sendWebhook(event: .systemAlert, data: data)
        }
    }
}

struct NotificationIntervalRow: View {
    let interval: StatusNotificationInterval
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: interval.icon)
                .foregroundColor(iconColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(interval.displayName)
                    .font(.headline)
                Text(interval.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
    
    private var iconColor: Color {
        switch interval {
        case .never:
            return .gray
        case .always:
            return .red  // Red for high frequency
        case .thresholdOnly:
            return .orange
        case .every5Minutes, .every15Minutes, .every30Minutes:
            return .blue
        case .hourly, .every2Hours, .every6Hours:
            return .green
        case .daily:
            return .purple
        }
    }
}

struct StatusSummaryView: View {
    @StateObject private var settings = Settings.shared
    
    private var timeUntilNextNotification: String {
        switch settings.statusNotificationInterval {
        case .never:
            return "N/A"
        case .always:
            return String(localized: "notification_immediate", comment: "Immediate notification timing")
        case .thresholdOnly:
            return String(localized: "notification_threshold_based", comment: "Threshold-based notification timing")
        default:
            guard let interval = settings.statusNotificationInterval.intervalSeconds else {
                return "N/A"
            }
            
            let timeSinceLastNotification = Date().timeIntervalSince(settings.lastStatusNotificationTime)
            let timeRemaining = interval - timeSinceLastNotification
            
            if timeRemaining <= 0 {
                return String(localized: "notification_ready_to_send", comment: "Notification ready to send status")
            }
            
            let hours = Int(timeRemaining) / 3600
            let minutes = Int(timeRemaining.truncatingRemainder(dividingBy: 3600)) / 60
            
            if hours > 0 {
                return String(localized: "time_format_hours_minutes", comment: "Time format with hours and minutes").replacingOccurrences(of: "{hours}", with: "\(hours)").replacingOccurrences(of: "{minutes}", with: "\(minutes)")
            } else {
                return String(localized: "time_format_minutes", comment: "Time format with minutes only").replacingOccurrences(of: "{minutes}", with: "\(minutes)")
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(String(localized: "current_setting_label", comment: "Current setting label"))
                Spacer()
                Text(settings.statusNotificationInterval.displayName)
                    .foregroundColor(.secondary)
            }
            
            if settings.statusNotificationInterval != .never && settings.statusNotificationInterval != .thresholdOnly {
                HStack {
                    Text(String(localized: "last_notification_label", comment: "Last notification label"))
                    Spacer()
                    Text(settings.lastStatusNotificationTime, style: .relative)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text(String(localized: "next_notification_label", comment: "Next notification label"))
                    Spacer()
                    Text(timeUntilNextNotification)
                        .foregroundColor(settings.statusNotificationInterval == .always ? .green : .secondary)
                }
            }
            
            HStack {
                Text(String(localized: "threshold_alerts_label", comment: "Threshold alerts status label"))
                Spacer()
                Text(settings.statusNotificationThresholds ? String(localized: "status_enabled", comment: "Enabled status") : String(localized: "status_disabled", comment: "Disabled status"))
                    .foregroundColor(settings.statusNotificationThresholds ? .green : .secondary)
            }
        }
    }
}

#Preview {
    NavigationView {
        StatusNotificationSettingsView()
    }
}

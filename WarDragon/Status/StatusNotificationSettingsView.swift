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
            Section(header: Text(String(localized: "status_notifications", comment: "Status notifications section header"))) {
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
                        Text(String(localized: "status_notifications_webhook_info", comment: "Information about webhook status notifications"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if settings.statusNotificationsEnabled {
                Section(header: Text(String(localized: "notification_frequency", comment: "Notification frequency section header"))) {
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
                    Section(header: Text(String(localized: "threshold_alerts", comment: "Threshold alerts section header"))) {
                        Toggle(String(localized: "also_send_threshold_alerts", comment: "Toggle for threshold alerts"), isOn: .init(
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
                                Text(String(localized: "threshold_alerts_always_description", comment: "Description for threshold alerts with always notifications"))
                            } else {
                                Text(String(localized: "threshold_alerts_regular_description", comment: "Description for threshold alerts with regular notifications"))
                            }
                        }
                    }
                }
                
                
                Section(header: Text(String(localized: "current_status", comment: "Current status section header"))) {
                    StatusSummaryView()
                }
                
                Section(header: Text(String(localized: "preview", comment: "Preview section header"))) {
                    Button(String(localized: "send_test_status_notification", comment: "Button to send test notification")) {
                        sendTestStatusNotification()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .navigationTitle(String(localized: "status_notifications", comment: "Status notifications navigation title"))
        .navigationBarTitleDisplayMode(.large)
    }
    
    private func sendTestStatusNotification() {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "test_status_notification", comment: "Test notification title")
        content.body = String(localized: "test_notification_body", comment: "Test notification body text")
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
        
        // Also send webhook if enabled
        if Settings.shared.webhooksEnabled {
            let data: [String: Any] = [
                "title": String(localized: "test_status_notification", comment: "Test notification webhook title"),
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
            return String(localized: "immediate", comment: "Immediate notification timing")
        case .thresholdOnly:
            return String(localized: "threshold_based", comment: "Threshold-based notification timing")
        default:
            guard let interval = settings.statusNotificationInterval.intervalSeconds else {
                return "N/A"
            }
            
            let timeSinceLastNotification = Date().timeIntervalSince(settings.lastStatusNotificationTime)
            let timeRemaining = interval - timeSinceLastNotification
            
            if timeRemaining <= 0 {
                return String(localized: "ready_to_send", comment: "Ready to send notification status")
            }
            
            let hours = Int(timeRemaining) / 3600
            let minutes = Int(timeRemaining.truncatingRemainder(dividingBy: 3600)) / 60
            
            if hours > 0 {
                return "\(hours)h \(minutes)m"
            } else {
                return "\(minutes)m"
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(String(localized: "current_setting", comment: "Current setting label"))
                Spacer()
                Text(settings.statusNotificationInterval.displayName)
                    .foregroundColor(.secondary)
            }
            
            if settings.statusNotificationInterval != .never && settings.statusNotificationInterval != .thresholdOnly {
                HStack {
                    Text(String(localized: "last_notification", comment: "Last notification label"))
                    Spacer()
                    Text(settings.lastStatusNotificationTime, style: .relative)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text(String(localized: "next_notification", comment: "Next notification label"))
                    Spacer()
                    Text(timeUntilNextNotification)
                        .foregroundColor(settings.statusNotificationInterval == .always ? .green : .secondary)
                }
            }
            
            HStack {
                Text(String(localized: "threshold_alerts_status", comment: "Threshold alerts status label"))
                Spacer()
                Text(settings.statusNotificationThresholds ? String(localized: "enabled", comment: "Enabled status") : String(localized: "disabled", comment: "Disabled status"))
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

//
//  WebhookManager.swift
//  WarDragon
//
//  Enhanced webhook integration system
//

import Foundation
import Combine

enum WebhookType: String, CaseIterable, Codable {
    case ifttt = "IFTTT"
    case matrix = "Matrix"
    case discord = "Discord"
    case custom = "Custom"
    
    var icon: String {
        switch self {
        case .ifttt: return "link.circle.fill"
        case .matrix: return "message.circle.fill"
        case .discord: return "bubble.left.and.bubble.right.fill"
        case .custom: return "globe"
        }
    }
    
    var color: String {
        switch self {
        case .ifttt: return "blue"
        case .matrix: return "green"
        case .discord: return "indigo"
        case .custom: return "gray"
        }
    }
}

enum WebhookEvent: String, CaseIterable, Codable {
    case droneDetected = "drone_detected"
    case fpvSignal = "fpv_signal"
    case systemAlert = "system_alert"
    case proximityWarning = "proximity_warning"
    case temperatureAlert = "temperature_alert"
    case memoryAlert = "memory_alert"
    case cpuAlert = "cpu_alert"
    case connectionLost = "connection_lost"
    case connectionRestored = "connection_restored"
    
    var displayName: String {
        switch self {
        case .droneDetected: return String(localized: "drone_detected", comment: "Display name for drone detected event")
        case .fpvSignal: return String(localized: "fpv_signal", comment: "Display name for FPV signal event")
        case .systemAlert: return String(localized: "system_alert", comment: "Display name for system alert event")
        case .proximityWarning: return String(localized: "proximity_warning", comment: "Display name for proximity warning event")
        case .temperatureAlert: return String(localized: "temperature_alert", comment: "Display name for temperature alert event")
        case .memoryAlert: return String(localized: "memory_alert", comment: "Display name for memory alert event")
        case .cpuAlert: return String(localized: "cpu_alert", comment: "Display name for CPU alert event")
        case .connectionLost: return String(localized: "connection_lost", comment: "Display name for connection lost event")
        case .connectionRestored: return String(localized: "connection_restored", comment: "Display name for connection restored event")
        }
    }
}

struct WebhookConfiguration: Codable, Identifiable {
    let id = UUID()
    var name: String
    var type: WebhookType
    var url: String
    var isEnabled: Bool
    var enabledEvents: Set<WebhookEvent>
    var customHeaders: [String: String]
    var retryCount: Int
    var timeoutSeconds: Double
    
    // Type-specific configurations
    var iftttEventName: String? // For IFTTT
    var matrixRoomId: String? // For Matrix
    var matrixAccessToken: String? // For Matrix
    var discordUsername: String? // For Discord
    var discordAvatarURL: String? // For Discord
    
    init(name: String, type: WebhookType, url: String) {
        self.name = name
        self.type = type
        self.url = url
        self.isEnabled = true
        self.enabledEvents = Set(WebhookEvent.allCases)
        self.customHeaders = [:]
        self.retryCount = 3
        self.timeoutSeconds = 10.0
    }
}

struct WebhookPayload {
    let event: WebhookEvent
    let timestamp: Date
    let data: [String: Any]
    let metadata: [String: String]
    
    func toIFTTTPayload(eventName: String) -> [String: Any] {
        return [
            "value1": event.displayName,
            "value2": formatTimestamp(),
            "value3": formatDataForDisplay()
        ]
    }
    
    func toMatrixPayload() -> [String: Any] {
        let body = """
        🚁 **\(event.displayName)**
        
        **Time:** \(formatTimestamp())
        **Details:** \(formatDataForDisplay())
        
        \(formatMetadata())
        """
        
        return [
            "msgtype": "m.text",
            "body": body,
            "format": "org.matrix.custom.html",
            "formatted_body": formatMatrixHTML()
        ]
    }
    
    func toDiscordPayload(username: String?, avatarURL: String?) -> [String: Any] {
        var payload: [String: Any] = [
            "embeds": [[
                "title": event.displayName,
                "description": formatDataForDisplay(),
                "color": getEventColor(),
                "timestamp": ISO8601DateFormatter().string(from: timestamp),
                "fields": formatFieldsForDiscord(),
                "footer": [
                    "text": String(localized: "wardragon_alert_system", comment: "Footer text for Discord webhook alerts")
                ]
            ]]
        ]
        
        if let username = username {
            payload["username"] = username
        }
        
        if let avatarURL = avatarURL {
            payload["avatar_url"] = avatarURL
        }
        
        return payload
    }
    
    private func formatTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }
    
    private func formatDataForDisplay() -> String {
        var parts: [String] = []
        
        for (key, value) in data {
            parts.append("\(key.capitalized): \(value)")
        }
        
        return parts.joined(separator: ", ")
    }
    
    private func formatMetadata() -> String {
        guard !metadata.isEmpty else { return "" }
        
        var parts: [String] = []
        for (key, value) in metadata {
            parts.append("**\(key.capitalized):** \(value)")
        }
        
        return parts.joined(separator: "\n")
    }
    
    private func formatMatrixHTML() -> String {
        let body = """
        <h3>🚁 \(event.displayName)</h3>
        <p><strong>Time:</strong> \(formatTimestamp())</p>
        <p><strong>Details:</strong> \(formatDataForDisplay())</p>
        \(formatMetadataHTML())
        """
        return body
    }
    
    private func formatMetadataHTML() -> String {
        guard !metadata.isEmpty else { return "" }
        
        var html = "<ul>"
        for (key, value) in metadata {
            html += "<li><strong>\(key.capitalized):</strong> \(value)</li>"
        }
        html += "</ul>"
        
        return html
    }
    
    private func formatFieldsForDiscord() -> [[String: Any]] {
        var fields: [[String: Any]] = []
        
        for (key, value) in data {
            fields.append([
                "name": key.capitalized,
                "value": "\(value)",
                "inline": true
            ])
        }
        
        for (key, value) in metadata {
            fields.append([
                "name": key.capitalized,
                "value": value,
                "inline": true
            ])
        }
        
        return fields
    }
    
    private func getEventColor() -> Int {
        switch event {
        case .droneDetected: return 0x3498db // Blue
        case .fpvSignal: return 0x9b59b6 // Purple
        case .systemAlert, .temperatureAlert, .memoryAlert, .cpuAlert: return 0xe74c3c // Red
        case .proximityWarning: return 0xf39c12 // Orange
        case .connectionLost: return 0xe74c3c // Red
        case .connectionRestored: return 0x27ae60 // Green
        }
    }
}

class WebhookManager: ObservableObject {
    static let shared = WebhookManager()
    
    @Published var configurations: [WebhookConfiguration] = []
    @Published var recentDeliveries: [WebhookDelivery] = []
    
    private var session: URLSession
    private let maxDeliveryHistory = 100
    
    struct WebhookDelivery: Identifiable {
        let id = UUID()
        let webhookName: String
        let event: WebhookEvent
        let timestamp: Date
        let success: Bool
        let responseCode: Int?
        let error: String?
        let retryAttempt: Int
    }
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
        
        loadConfigurations()
    }
    
    // MARK: - Configuration Management
    
    func addConfiguration(_ config: WebhookConfiguration) {
        configurations.append(config)
        saveConfigurations()
    }
    
    func updateConfiguration(_ config: WebhookConfiguration) {
        if let index = configurations.firstIndex(where: { $0.id == config.id }) {
            configurations[index] = config
            saveConfigurations()
        }
    }
    
    func removeConfiguration(_ config: WebhookConfiguration) {
        configurations.removeAll { $0.id == config.id }
        saveConfigurations()
    }
    
    func toggleWebhook(_ config: WebhookConfiguration) {
        if let index = configurations.firstIndex(where: { $0.id == config.id }) {
            configurations[index].isEnabled.toggle()
            saveConfigurations()
        }
    }
    
    private func saveConfigurations() {
        if let data = try? JSONEncoder().encode(configurations) {
            UserDefaults.standard.set(data, forKey: "webhook_configurations")
        }
    }
    
    private func loadConfigurations() {
        if let data = UserDefaults.standard.data(forKey: "webhook_configurations"),
           let configs = try? JSONDecoder().decode([WebhookConfiguration].self, from: data) {
            configurations = configs
        }
    }
    
    // MARK: - Webhook Delivery
    
    func sendWebhook(event: WebhookEvent, data: [String: Any], metadata: [String: String] = [:]) {
        // Check if webhooks are globally enabled
        guard Settings.shared.webhooksEnabled else { return }
        
        // Check if this event type is globally enabled
        guard Settings.shared.enabledWebhookEvents.contains(event) else { return }
        
        // Check if any webhooks are configured and enabled for this event
        let enabledConfigs = configurations.filter {
            $0.isEnabled && $0.enabledEvents.contains(event)
        }
        
        guard !enabledConfigs.isEmpty else { return }
        
        let payload = WebhookPayload(
            event: event,
            timestamp: Date(),
            data: data,
            metadata: metadata
        )
        
        for config in enabledConfigs {
            Task {
                await deliverWebhook(config: config, payload: payload)
            }
        }
    }
    
    private func deliverWebhook(config: WebhookConfiguration, payload: WebhookPayload, retryAttempt: Int = 0) async {
        do {
            let request = try buildRequest(config: config, payload: payload)
            let (data, response) = try await session.data(for: request)
            
            let httpResponse = response as? HTTPURLResponse
            let statusCode = httpResponse?.statusCode ?? 0
            
            let success = statusCode >= 200 && statusCode < 300
            
            DispatchQueue.main.async {
                self.recordDelivery(
                    webhookName: config.name,
                    event: payload.event,
                    success: success,
                    responseCode: statusCode,
                    error: success ? nil : "HTTP \(statusCode)",
                    retryAttempt: retryAttempt
                )
            }
            
            if !success && retryAttempt < config.retryCount {
                // Exponential backoff
                let delay = pow(2.0, Double(retryAttempt)) * 1.0
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                await deliverWebhook(config: config, payload: payload, retryAttempt: retryAttempt + 1)
            }
            
        } catch {
            DispatchQueue.main.async {
                self.recordDelivery(
                    webhookName: config.name,
                    event: payload.event,
                    success: false,
                    responseCode: nil,
                    error: error.localizedDescription,
                    retryAttempt: retryAttempt
                )
            }
            
            if retryAttempt < config.retryCount {
                let delay = pow(2.0, Double(retryAttempt)) * 1.0
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                await deliverWebhook(config: config, payload: payload, retryAttempt: retryAttempt + 1)
            }
        }
    }
    
    private func buildRequest(config: WebhookConfiguration, payload: WebhookPayload) throws -> URLRequest {
        guard let url = URL(string: config.url) else {
            throw NSError(domain: "WebhookManager", code: 1, userInfo: [NSLocalizedDescriptionKey: String(localized: "invalid_url", comment: "Error message for invalid webhook URL")])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = config.timeoutSeconds
        
        // Set content type
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add custom headers
        for (key, value) in config.customHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Build payload based on webhook type
        let jsonPayload: [String: Any]
        
        switch config.type {
        case .ifttt:
            jsonPayload = payload.toIFTTTPayload(eventName: config.iftttEventName ?? "wardragon_alert")
        case .matrix:
            jsonPayload = payload.toMatrixPayload()
            if let accessToken = config.matrixAccessToken {
                request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            }
        case .discord:
            jsonPayload = payload.toDiscordPayload(username: config.discordUsername, avatarURL: config.discordAvatarURL)
        case .custom:
            jsonPayload = [
                "event": payload.event.rawValue,
                "event_name": payload.event.displayName,
                "timestamp": ISO8601DateFormatter().string(from: payload.timestamp),
                "data": payload.data,
                "metadata": payload.metadata
            ]
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: jsonPayload)
        
        return request
    }
    
    private func recordDelivery(webhookName: String, event: WebhookEvent, success: Bool, responseCode: Int?, error: String?, retryAttempt: Int) {
        let delivery = WebhookDelivery(
            webhookName: webhookName,
            event: event,
            timestamp: Date(),
            success: success,
            responseCode: responseCode,
            error: error,
            retryAttempt: retryAttempt
        )
        
        recentDeliveries.insert(delivery, at: 0)
        
        if recentDeliveries.count > maxDeliveryHistory {
            recentDeliveries = Array(recentDeliveries.prefix(maxDeliveryHistory))
        }
    }
    
    // MARK: - Testing
    
    func testWebhook(_ config: WebhookConfiguration) async -> Bool {
        let testPayload = WebhookPayload(
            event: .systemAlert,
            timestamp: Date(),
            data: ["message": "Test webhook from WarDragon"],
            metadata: ["test": "true"]
        )
        
        do {
            let request = try buildRequest(config: config, payload: testPayload)
            let (_, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode >= 200 && httpResponse.statusCode < 300
            }
            return false
        } catch {
            return false
        }
    }
}

extension WebhookManager {
    /// Record a test‐send in the delivery history so it shows up in the UI.
    func recordTestDelivery(
        config: WebhookConfiguration,
        success: Bool,
        responseCode: Int? = nil,
        error: String? = nil
    ) {
        let delivery = WebhookDelivery(
            webhookName: config.name,
            event: .systemAlert,          // use a generic event for test
            timestamp: Date(),
            success: success,
            responseCode: responseCode,
            error: error,
            retryAttempt: 0
        )
        DispatchQueue.main.async {
            self.recentDeliveries.insert(delivery, at: 0)
            if self.recentDeliveries.count > 100 {
                self.recentDeliveries.removeLast(self.recentDeliveries.count - 100)
            }
        }
    }
}

//
//  WebhookConfigurationView.swift
//  WarDragon
//
//  Created by Luke on 6/23/25.
//

import SwiftUI

struct WebhookConfigurationView: View {
    let config: WebhookConfiguration?
    let onSave: (WebhookConfiguration) -> Void
    
    @State private var name: String
    @State private var type: WebhookType
    @State private var url: String
    @State private var enabledEvents: Set<WebhookEvent>
    @State private var retryCount: Int
    @State private var timeoutSeconds: Double
    
    // IFTTT specific
    @State private var iftttEventName: String
    
    // Matrix specific
    @State private var matrixRoomId: String
    @State private var matrixAccessToken: String
    
    // Discord specific
    @State private var discordUsername: String
    @State private var discordAvatarURL: String
    
    // Custom headers
    @State private var customHeaders: [HeaderPair]
    @State private var showingHeaderEditor = false
    
    @State private var isTesting = false
    @State private var testResult: String?
    
    @Environment(\.presentationMode) var presentationMode
    
    struct HeaderPair: Identifiable {
        let id = UUID()
        var key: String
        var value: String
    }
    
    init(config: WebhookConfiguration?, onSave: @escaping (WebhookConfiguration) -> Void) {
        self.config = config
        self.onSave = onSave
        
        _name = State(initialValue: config?.name ?? "")
        _type = State(initialValue: config?.type ?? .ifttt)
        _url = State(initialValue: config?.url ?? "")
        _enabledEvents = State(initialValue: config?.enabledEvents ?? Set(WebhookEvent.allCases))
        _retryCount = State(initialValue: config?.retryCount ?? 3)
        _timeoutSeconds = State(initialValue: config?.timeoutSeconds ?? 10.0)
        
        _iftttEventName = State(initialValue: config?.iftttEventName ?? "wardragon_alert")
        _matrixRoomId = State(initialValue: config?.matrixRoomId ?? "")
        _matrixAccessToken = State(initialValue: config?.matrixAccessToken ?? "")
        _discordUsername = State(initialValue: config?.discordUsername ?? "WarDragon")
        _discordAvatarURL = State(initialValue: config?.discordAvatarURL ?? "")
        
        let headers = config?.customHeaders.map { HeaderPair(key: $0.key, value: $0.value) } ?? []
        _customHeaders = State(initialValue: headers)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(String(localized: "basic_configuration", comment: "Section header for basic webhook configuration"))) {
                    TextField(String(localized: "name", comment: "Label for webhook name field"), text: $name)
                    
                    Picker(String(localized: "type", comment: "Label for webhook type picker"), selection: $type) {
                        ForEach(WebhookType.allCases, id: \.self) { webhookType in
                            HStack {
                                Image(systemName: webhookType.icon)
                                Text(webhookType.rawValue)
                            }
                            .tag(webhookType)
                        }
                    }
                    
                    TextField(String(localized: "url", comment: "Label for webhook URL field"), text: $url)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                }
                
                // Type-specific configuration
                switch type {
                case .ifttt:
                    iftttConfigurationSection
                case .matrix:
                    matrixConfigurationSection
                case .discord:
                    discordConfigurationSection
                case .custom:
                    customConfigurationSection
                }
                
                Section(header: Text(String(localized: "events", comment: "Section header for webhook events"))) {
                    ForEach(WebhookEvent.allCases, id: \.self) { event in
                        Toggle(event.displayName, isOn: .init(
                            get: { enabledEvents.contains(event) },
                            set: { enabled in
                                if enabled {
                                    enabledEvents.insert(event)
                                } else {
                                    enabledEvents.remove(event)
                                }
                            }
                        ))
                    }
                }
                
                Section(header: Text(String(localized: "advanced_settings", comment: "Section header for advanced webhook settings"))) {
                    HStack {
                        Text(String(localized: "retry_count", comment: "Label for retry count setting"))
                        Spacer()
                        Stepper("\(retryCount)", value: $retryCount, in: 0...10)
                    }
                    
                    HStack {
                        Text(String(localized: "timeout", comment: "Label for timeout setting"))
                        Spacer()
                        Text("\(timeoutSeconds, specifier: "%.0f")s")
                        Slider(value: $timeoutSeconds, in: 5...60, step: 5)
                    }
                }
                
                Section(header: Text(String(localized: "test", comment: "Section header for webhook testing"))) {
                    Button(action: testWebhook) {
                        HStack {
                            if isTesting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "network")
                            }
                            Text(String(localized: "test_webhook", comment: "Button to test webhook"))
                        }
                    }
                    .disabled(url.isEmpty || isTesting)
                    
                    if let result = testResult {
                        Text(result)
                            .font(.caption)
                            .foregroundColor(result.contains("Success") ? .green : .red)
                    }
                }
            }
            .navigationTitle(config == nil ? String(localized: "add_webhook", comment: "Title for adding webhook") : String(localized: "edit_webhook", comment: "Title for editing webhook"))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button(String(localized: "cancel", comment: "Cancel button")) {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button(String(localized: "save", comment: "Save button")) {
                    saveConfiguration()
                }
                    .disabled(name.isEmpty || url.isEmpty)
            )
        }
    }
    
    // MARK: - Type-specific sections
    
    private var iftttConfigurationSection: some View {
        Section(header: Text(String(localized: "ifttt_configuration", comment: "Section header for IFTTT configuration"))) {
            TextField(String(localized: "event_name", comment: "Label for IFTTT event name field"), text: $iftttEventName)
                .autocapitalization(.none)
            
            Text(String(localized: "ifttt_configuration_help", comment: "Help text for IFTTT webhook configuration"))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var matrixConfigurationSection: some View {
        Section(header: Text(String(localized: "matrix_configuration", comment: "Section header for Matrix webhook settings"))) {
            TextField(String(localized: "room_id", comment: "Label for Matrix room ID field"), text: $matrixRoomId)
                .autocapitalization(.none)
            
            SecureField(String(localized: "access_token", comment: "Label for Matrix access token field"), text: $matrixAccessToken)
            
            Text(String(localized: "matrix_configuration_help", comment: "Help text for Matrix webhook configuration"))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var discordConfigurationSection: some View {
        Section(header: Text(String(localized: "discord_configuration", comment: "Section header for Discord webhook settings"))) {
            TextField(String(localized: "bot_username", comment: "Label for Discord bot username field"), text: $discordUsername)
            
            TextField(String(localized: "avatar_url_optional", comment: "Label for Discord avatar URL field"), text: $discordAvatarURL)
                .keyboardType(.URL)
                .autocapitalization(.none)
            
            Text(String(localized: "discord_configuration_help", comment: "Help text for Discord webhook configuration"))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var customConfigurationSection: some View {
        Section(header: Text(String(localized: "custom_headers", comment: "Section header for custom headers"))) {
            ForEach(customHeaders) { header in
                HStack {
                    TextField(String(localized: "header", comment: "Placeholder for header name field"), text: .init(
                        get: { header.key },
                        set: { newValue in
                            if let index = customHeaders.firstIndex(where: { $0.id == header.id }) {
                                customHeaders[index].key = newValue
                            }
                        }
                    ))
                    
                    TextField(String(localized: "value", comment: "Placeholder for header value field"), text: .init(
                        get: { header.value },
                        set: { newValue in
                            if let index = customHeaders.firstIndex(where: { $0.id == header.id }) {
                                customHeaders[index].value = newValue
                            }
                        }
                    ))
                }
            }
            .onDelete { indexSet in
                customHeaders.remove(atOffsets: indexSet)
            }
            
            Button(String(localized: "add_header", comment: "Button to add new custom header")) {
                customHeaders.append(HeaderPair(key: "", value: ""))
            }
        }
    }
    
    // MARK: - Actions
    
    private func testWebhook() {
        isTesting = true
        testResult = nil
        
        let testConfig = buildConfiguration()
        
        Task {
            let success = await WebhookManager.shared.testWebhook(testConfig)
            DispatchQueue.main.async {
                self.isTesting = false
                self.testResult = success ? String(localized: "test_successful", comment: "Message shown when webhook test succeeds") : String(localized: "test_failed", comment: "Message shown when webhook test fails")
                // now log it into the Recent Deliveries list
                WebhookManager.shared.recordTestDelivery(
                    config: testConfig,
                    success: success,
                    error: success ? nil : "Test failed"
                )
            }
        }
    }
    
    private func saveConfiguration() {
        let configuration = buildConfiguration()
        onSave(configuration)
        presentationMode.wrappedValue.dismiss()
    }
    
    private func buildConfiguration() -> WebhookConfiguration {
        var configuration = config ?? WebhookConfiguration(name: name, type: type, url: url)
        
        configuration.name = name
        configuration.type = type
        configuration.url = url
        configuration.enabledEvents = enabledEvents
        configuration.retryCount = retryCount
        configuration.timeoutSeconds = timeoutSeconds
        
        // Type-specific configurations
        configuration.iftttEventName = iftttEventName.isEmpty ? nil : iftttEventName
        configuration.matrixRoomId = matrixRoomId.isEmpty ? nil : matrixRoomId
        configuration.matrixAccessToken = matrixAccessToken.isEmpty ? nil : matrixAccessToken
        configuration.discordUsername = discordUsername.isEmpty ? nil : discordUsername
        configuration.discordAvatarURL = discordAvatarURL.isEmpty ? nil : discordAvatarURL
        
        // Custom headers
        var headers: [String: String] = [:]
        for header in customHeaders {
            if !header.key.isEmpty && !header.value.isEmpty {
                headers[header.key] = header.value
            }
        }
        configuration.customHeaders = headers
        
        return configuration
    }
}

#Preview {
    WebhookConfigurationView(config: nil) { _ in }
}

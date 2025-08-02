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
                Section(header: Text(String(localized: "basic_configuration", comment: "Basic configuration section header"))) {
                    TextField(String(localized: "name", comment: "Name field label"), text: $name)
                    
                    Picker(String(localized: "type", comment: "Type field label"), selection: $type) {
                        ForEach(WebhookType.allCases, id: \.self) { webhookType in
                            HStack {
                                Image(systemName: webhookType.icon)
                                Text(webhookType.rawValue)
                            }
                            .tag(webhookType)
                        }
                    }
                    
                    TextField(String(localized: "url", comment: "URL field label"), text: $url)
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
                
                Section(header: Text(String(localized: "events", comment: "Events section header"))) {
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
                
                Section(header: Text(String(localized: "advanced_settings", comment: "Advanced settings section header"))) {
                    HStack {
                        Text(String(localized: "retry_count", comment: "Retry count setting label"))
                        Spacer()
                        Stepper("\(retryCount)", value: $retryCount, in: 0...10)
                    }
                    
                    HStack {
                        Text(String(localized: "timeout", comment: "Timeout setting label"))
                        Spacer()
                        Text(String(localized: "timeout_seconds_format", comment: "Timeout seconds format").replacingOccurrences(of: "{seconds}", with: "\(timeoutSeconds, specifier: "%.0f")"))
                        Slider(value: $timeoutSeconds, in: 5...60, step: 5)
                    }
                }
                
                Section(header: Text(String(localized: "test", comment: "Test section header"))) {
                    Button(action: testWebhook) {
                        HStack {
                            if isTesting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "network")
                            }
                            Text(String(localized: "test_webhook", comment: "Test webhook button text"))
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
            .navigationTitle(config == nil ? String(localized: "add_webhook", comment: "Add webhook title") : String(localized: "edit_webhook", comment: "Edit webhook title"))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button(String(localized: "cancel", comment: "Cancel button text")) {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button(String(localized: "save", comment: "Save button text")) {
                    saveConfiguration()
                }
                    .disabled(name.isEmpty || url.isEmpty)
            )
        }
    }
    
    // MARK: - Type-specific sections
    
    private var iftttConfigurationSection: some View {
        Section(header: Text(String(localized: "ifttt_configuration", comment: "IFTTT configuration section header"))) {
            TextField(String(localized: "event_name", comment: "Event name field label"), text: $iftttEventName)
                .autocapitalization(.none)
            
            Text(String(localized: "ifttt_configuration_help", comment: "IFTTT configuration help text"))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var matrixConfigurationSection: some View {
        Section(header: Text(String(localized: "matrix_configuration", comment: "Matrix configuration section header"))) {
            TextField(String(localized: "room_id", comment: "Room ID field label"), text: $matrixRoomId)
                .autocapitalization(.none)
            
            SecureField(String(localized: "access_token", comment: "Access token field label"), text: $matrixAccessToken)
            
            Text(String(localized: "matrix_configuration_help", comment: "Matrix configuration help text"))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var discordConfigurationSection: some View {
        Section(header: Text(String(localized: "discord_configuration", comment: "Discord configuration section header"))) {
            TextField(String(localized: "bot_username", comment: "Bot username field label"), text: $discordUsername)
            
            TextField(String(localized: "avatar_url_optional", comment: "Avatar URL optional field label"), text: $discordAvatarURL)
                .keyboardType(.URL)
                .autocapitalization(.none)
            
            Text(String(localized: "discord_configuration_help", comment: "Discord configuration help text"))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var customConfigurationSection: some View {
        Section(header: Text(String(localized: "custom_headers", comment: "Custom headers section header"))) {
            ForEach(customHeaders) { header in
                HStack {
                    TextField(String(localized: "header", comment: "Header field label"), text: .init(
                        get: { header.key },
                        set: { newValue in
                            if let index = customHeaders.firstIndex(where: { $0.id == header.id }) {
                                customHeaders[index].key = newValue
                            }
                        }
                    ))
                    
                    TextField(String(localized: "value", comment: "Value field label"), text: .init(
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
            
            Button(String(localized: "add_header", comment: "Add header button text")) {
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
                self.testResult = success ? String(localized: "test_successful", comment: "Test successful message") : String(localized: "test_failed", comment: "Test failed message")
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

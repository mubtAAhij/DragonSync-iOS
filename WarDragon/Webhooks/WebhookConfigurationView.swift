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
                Section(header: Text("Basic Configuration")) {
                    TextField("Name", text: $name)
                    
                    Picker("Type", selection: $type) {
                        ForEach(WebhookType.allCases, id: \.self) { webhookType in
                            HStack {
                                Image(systemName: webhookType.icon)
                                Text(webhookType.rawValue)
                            }
                            .tag(webhookType)
                        }
                    }
                    
                    TextField("URL", text: $url)
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
                
                Section(header: Text("Events")) {
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
                
                Section(header: Text("Advanced Settings")) {
                    HStack {
                        Text("Retry Count")
                        Spacer()
                        Stepper("\(retryCount)", value: $retryCount, in: 0...10)
                    }
                    
                    HStack {
                        Text("Timeout")
                        Spacer()
                        Text("\(timeoutSeconds, specifier: "%.0f")s")
                        Slider(value: $timeoutSeconds, in: 5...60, step: 5)
                    }
                }
                
                Section(header: Text("Test")) {
                    Button(action: testWebhook) {
                        HStack {
                            if isTesting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "network")
                            }
                            Text("Test Webhook")
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
            .navigationTitle(config == nil ? "Add Webhook" : "Edit Webhook")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    saveConfiguration()
                }
                    .disabled(name.isEmpty || url.isEmpty)
            )
        }
    }
    
    // MARK: - Type-specific sections
    
    private var iftttConfigurationSection: some View {
        Section(header: Text("IFTTT Configuration")) {
            TextField("Event Name", text: $iftttEventName)
                .autocapitalization(.none)
            
            Text("Use your IFTTT webhook URL. Event name will be included in the payload.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var matrixConfigurationSection: some View {
        Section(header: Text("Matrix Configuration")) {
            TextField("Room ID", text: $matrixRoomId)
                .autocapitalization(.none)
            
            SecureField("Access Token", text: $matrixAccessToken)
            
            Text("Use the Matrix room send message API endpoint. Format: https://matrix.org/_matrix/client/r0/rooms/{roomId}/send/m.room.message")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var discordConfigurationSection: some View {
        Section(header: Text("Discord Configuration")) {
            TextField("Bot Username", text: $discordUsername)
            
            TextField("Avatar URL (optional)", text: $discordAvatarURL)
                .keyboardType(.URL)
                .autocapitalization(.none)
            
            Text("Use your Discord webhook URL. Messages will be sent as rich embeds.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var customConfigurationSection: some View {
        Section(header: Text("Custom Headers")) {
            ForEach(customHeaders) { header in
                HStack {
                    TextField("Header", text: .init(
                        get: { header.key },
                        set: { newValue in
                            if let index = customHeaders.firstIndex(where: { $0.id == header.id }) {
                                customHeaders[index].key = newValue
                            }
                        }
                    ))
                    
                    TextField("Value", text: .init(
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
            
            Button("Add Header") {
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
                self.testResult = success ? "✅ Test successful!" : "❌ Test failed"
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

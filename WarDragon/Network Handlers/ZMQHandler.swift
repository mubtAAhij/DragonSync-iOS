//
//  ZMQHandler.swift
//  WarDragon
//
//  Created by Luke on 11/25/24.
//

import Foundation
import Network

class ZMQHandler: ObservableObject {
    @Published var isConnected = false
    @Published var connectionError: String?
    
    // Socket configuration
    private enum SocketType: Int32 {
        case publish = 1
        case subscribe = 2
        case xpublish = 9
        case xsubscribe = 10
    }
    
    private enum SocketOption: UInt8 {
        case subscribe = 0x01
        case unsubscribe = 0x00
    }
    
    // Connection management
    private var telemetryConnection: NWConnection?
    private var statusConnection: NWConnection?
    private let queue = DispatchQueue(label: "com.wardragon.zmq", qos: .userInitiated)
    private var isDisconnecting = false
    private var messageBuffer = Data()
    
    // ZMTP Protocol
    private let zmqGreeting: Data = {
        var greeting = Data()
        // Signature
        greeting.append(0xFF)
        greeting.append(contentsOf: [UInt8](repeating: 0x00, count: 8))
        greeting.append(0x7F)
        // Version (3.0)
        greeting.append(contentsOf: [0x03, 0x00])
        // Mechanism (NULL padded to 20 bytes)
        let mechanism = "NULL".padding(toLength: 20, withPad: "\0", startingAt: 0)
        greeting.append(mechanism.data(using: .ascii)!)
        // Filler (31 bytes)
        greeting.append(contentsOf: [UInt8](repeating: 0x00, count: 31))
        return greeting
    }()
    
    // Handlers and state
    private weak var cotViewModel: CoTViewModel?
    private var telemetryHandler: ((String) -> Void)?
    private var statusHandler: ((String) -> Void)?
    private let maxReconnectAttempts = 3
    private let reconnectDelay: TimeInterval = 5.0
    
    // Connection attempt tracking
    private var connectionAttempts = [String: Int]()
    
    init(cotViewModel: CoTViewModel) {
        self.cotViewModel = cotViewModel
    }
    
    private var serviceStatus = [ConnectionType: Bool]() {
        didSet {
            updateConnectionState()
        }
    }
    
    // MARK: - Public Interface
    
    func connect(host: String,
                zmqTelemetryPort: UInt16,
                zmqStatusPort: UInt16,
                onTelemetry: @escaping (String) -> Void,
                onStatus: @escaping (String) -> Void) {
        
        cleanupExistingConnections()
        
        telemetryHandler = onTelemetry
        statusHandler = onStatus
        
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        
        setupConnection(for: .telemetry,
                       host: host,
                       port: zmqTelemetryPort,
                       parameters: parameters)
        
        setupConnection(for: .status,
                       host: host,
                       port: zmqStatusPort,
                       parameters: parameters)
    }
    
    func disconnect() {
        guard !isDisconnecting else { return }
        
        isDisconnecting = true
        cleanupExistingConnections()
        resetState()
        isDisconnecting = false
    }
    
    // MARK: - Connection Management
    
    private enum ConnectionType: String {
        case telemetry, status
    }
    
    private func setupConnection(for type: ConnectionType,
                               host: String,
                               port: UInt16,
                               parameters: NWParameters) {
        
        let endpoint = NWEndpoint.hostPort(host: .init(host), port: .init(integerLiteral: port))
        let connection = NWConnection(to: endpoint, using: parameters)
        
        configureConnection(connection, type: type, host: host, port: port, parameters: parameters)
        connection.start(queue: queue)
        
        switch type {
        case .telemetry:
            telemetryConnection = connection
        case .status:
            statusConnection = connection
        }
    }
    
    private func updateConnectionState() {
        DispatchQueue.main.async {
            // Consider connected if at least one service is available
            self.isConnected = self.serviceStatus.values.contains(true)
            self.cotViewModel?.isListeningCot = self.isConnected
            
            // Update error message based on service status
            if !self.serviceStatus[.telemetry, default: false] {
                self.connectionError = "Telemetry service unavailable"
            } else if !self.serviceStatus[.status, default: false] {
                self.connectionError = "Status service unavailable"
            } else {
                self.connectionError = nil
            }
        }
    }
    
    private func configureConnection(_ connection: NWConnection,
                                   type: ConnectionType,
                                   host: String,
                                   port: UInt16,
                                   parameters: NWParameters) {
        
        connection.stateUpdateHandler = { [weak self] state in
            guard let self = self, !self.isDisconnecting else { return }
            
            switch state {
            case .ready:
                self.handleConnectionReady(connection, type: type)
                
            case .failed(let error), .waiting(let error):
                self.handleConnectionError(error, type: type, host: host, port: port, parameters: parameters)
                
            case .cancelled:
                guard !self.isDisconnecting else { return }
                self.handleConnectionDrop(type: type, host: host, port: port, parameters: parameters)
                
            case .preparing:
                self.connectionError = "Connecting to \(type.rawValue)..."
                
            default:
                break
            }
        }
    }

    private func handleConnectionError(_ error: NWError,
                                     type: ConnectionType,
                                     host: String,
                                     port: UInt16,
                                     parameters: NWParameters) {
        print("\(type) connection error: \(error)")
        
        // Update connection state before retry
        serviceStatus[type] = false
        
        // Only show error if both services are down
        if !serviceStatus.values.contains(true) {
            DispatchQueue.main.async {
                self.connectionError = error.localizedDescription
            }
        }
        
        // Clean up failed connection before retry
        switch type {
        case .telemetry:
            telemetryConnection?.stateUpdateHandler = nil
            telemetryConnection?.cancel()
            telemetryConnection = nil
        case .status:
            statusConnection?.stateUpdateHandler = nil
            statusConnection?.cancel()
            statusConnection = nil
        }

        handleConnectionDrop(type: type, host: host, port: port, parameters: parameters)
    }

    private func handleHandshakeError(_ error: Error, type: ConnectionType) {
        print("\(type) handshake error: \(error)")
        
        DispatchQueue.main.async {
            self.connectionError = "Handshake failed for \(type.rawValue): \(error.localizedDescription)"
            self.isConnected = false
            self.cotViewModel?.isListeningCot = false
        }
    }

    private func handleConnectionDrop(type: ConnectionType,
                                    host: String,
                                    port: UInt16,
                                    parameters: NWParameters) {
        guard !isDisconnecting else { return }
        
        print("\(type) connection dropped, attempting reconnect...")
        
        let attempts = connectionAttempts[type.rawValue] ?? 0
        connectionAttempts[type.rawValue] = attempts + 1
        
        if attempts < maxReconnectAttempts {
            DispatchQueue.main.asyncAfter(deadline: .now() + reconnectDelay) { [weak self] in
                guard let self = self else { return }
                
                print("Attempting reconnection for \(type): attempt \(attempts + 1) of \(self.maxReconnectAttempts)")
                self.setupConnection(for: type, host: host, port: port, parameters: parameters)
            }
        } else {
            print("Max reconnection attempts reached for \(type)")
            DispatchQueue.main.async {
                // Only turn everything off if both have failed
                if (self.connectionAttempts["telemetry"] ?? 0) >= self.maxReconnectAttempts &&
                   (self.connectionAttempts["status"] ?? 0) >= self.maxReconnectAttempts {
                    self.isConnected = false
                    self.cotViewModel?.isListeningCot = false
                    Settings.shared.toggleListening(false)
                    self.connectionError = "Connection lost after \(self.maxReconnectAttempts) attempts"
                }
            }
        }
    }
    
    // MARK: - ZMTP Protocol Implementation
    
    private func handleConnectionReady(_ connection: NWConnection, type: ConnectionType) {
        connectionAttempts[type.rawValue] = 0
        serviceStatus[type] = true  // Mark this service as available
        
        performZMQHandshake(connection: connection, type: type) { [weak self] success in
            guard let self = self else { return }
            
            if success {
                if type == .telemetry {
                    self.subscribeToTopics(connection: connection)
                }
                self.startReceiving(from: connection, type: type)
            } else {
                self.serviceStatus[type] = false  // Mark service as unavailable if handshake fails
            }
        }
    }
    
    private func performZMQHandshake(connection: NWConnection,
                                   type: ConnectionType,
                                   completion: @escaping (Bool) -> Void) {
        
        connection.send(content: zmqGreeting, completion: .contentProcessed { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                self.handleHandshakeError(error, type: type)
                completion(false)
                return
            }
            
            self.receiveGreeting(connection: connection, type: type, completion: completion)
        })
    }
    
    private func receiveGreeting(connection: NWConnection,
                               type: ConnectionType,
                               completion: @escaping (Bool) -> Void) {
        
        connection.receive(minimumIncompleteLength: 64,
                         maximumLength: 64) { [weak self] data, _, _, error in
            
            guard let self = self else { return }
            
            if let error = error {
                self.handleHandshakeError(error, type: type)
                completion(false)
                return
            }
            
            guard let data = data, data.count == 64,
                  data[0] == 0xFF, data[9] == 0x7F else {
                print("Invalid ZMQ greeting received for \(type)")
                completion(false)
                return
            }
            
            completion(true)
        }
    }
    
    // MARK: - Subscription Management
    
    private func subscribeToTopics(connection: NWConnection) {
        subscribe(to: "", connection: connection)  // Subscribe to all
        subscribe(to: "AUX_ADV_IND", connection: connection)
        subscribe(to: "DroneID", connection: connection)
    }
    
    private func unsubscribeFromTopics(connection: NWConnection) {
        unsubscribe(from: "", connection: connection)
        unsubscribe(from: "AUX_ADV_IND", connection: connection)
        unsubscribe(from: "DroneID", connection: connection)
    }
    
    private func subscribe(to topic: String, connection: NWConnection) {
        let subscribeData = Data([SocketOption.subscribe.rawValue]) + topic.data(using: .utf8)!
        sendFramedMessage(subscribeData, on: connection)
    }
    
    private func unsubscribe(from topic: String, connection: NWConnection) {
        let unsubscribeData = Data([SocketOption.unsubscribe.rawValue]) + topic.data(using: .utf8)!
        sendFramedMessage(unsubscribeData, on: connection)
    }
    
    // MARK: - Message Handling
    
    private func startReceiving(from connection: NWConnection, type: ConnectionType) {
        receiveNextMessage(from: connection, type: type)
    }
    
    private func receiveNextMessage(from connection: NWConnection, type: ConnectionType) {
        connection.receive(minimumIncompleteLength: 1,
                         maximumLength: 65536) { [weak self] data, _, isComplete, error in
            
            guard let self = self, !self.isDisconnecting else { return }
            
            defer {
                if !isComplete && self.isConnected && !self.isDisconnecting {
                    self.receiveNextMessage(from: connection, type: type)
                }
            }
            
            if let error = error {
                print("\(type) receive error: \(error)")
                return
            }
            
            if let data = data {
                self.processReceivedData(data, type: type)
            }
        }
    }
    
    private func processReceivedData(_ data: Data, type: ConnectionType) {
        messageBuffer.append(data)
        
        while !messageBuffer.isEmpty {
            let (messageData, remaining) = processZMQFrame(messageBuffer)
            messageBuffer = remaining
            
            if let messageData = messageData,
               let message = String(data: messageData, encoding: .utf8) {
                
                dispatchMessage(message, type: type)
            } else {
                break
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func sendFramedMessage(_ data: Data, on connection: NWConnection) {
        let framedMessage = frameZMQMessage(data)
        connection.send(content: framedMessage,
                       completion: .contentProcessed { error in
            if let error = error {
                print("Send error: \(error)")
            }
        })
    }
    
    private func frameZMQMessage(_ data: Data) -> Data {
        var frame = Data()
        let length = UInt64(data.count)
        
        if length > 255 {
            frame.append(0x02)
            withUnsafeBytes(of: length.bigEndian) { frame.append(contentsOf: $0) }
        } else {
            frame.append(0x00)
            frame.append(UInt8(length))
        }
        
        frame.append(data)
        return frame
    }
    
    private func processZMQFrame(_ data: Data) -> (message: Data?, remaining: Data) {
        guard data.count >= 2 else { return (nil, data) }
        
        let flags = data[0]
        let isLongMessage = (flags & 0x02) == 0x02
        let headerSize = isLongMessage ? 9 : 2
        
        guard data.count >= headerSize else { return (nil, data) }
        
        let length = isLongMessage ?
            data[1...8].withUnsafeBytes { $0.load(as: UInt64.self).bigEndian } :
            UInt64(data[1])
        
        let totalSize = Int(length) + headerSize
        guard data.count >= totalSize else { return (nil, data) }
        
        let message = data[headerSize..<totalSize]
        let remaining = data[totalSize...]
        
        return (Data(message), Data(remaining))
    }
    
    private func dispatchMessage(_ message: String, type: ConnectionType) {
        DispatchQueue.main.async {
            switch type {
            case .telemetry:
                if self.validateTelemetryMessage(message) {
                    self.telemetryHandler?(message)
                }
            case .status:
                self.statusHandler?(message)
            }
        }
    }
    
    private func validateTelemetryMessage(_ message: String) -> Bool {
        guard let data = message.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }
        
        if let auxAdv = json["AUX_ADV_IND"] as? [String: Any],
           let aa = auxAdv["aa"] as? Int,
           aa == 0x8e89bed6,
           let _ = json["AdvData"] as? String {
            return true
        }
        
        if json["DroneID"] != nil {
            return true
        }
        
        return false
    }
    
    private func cleanupExistingConnections() {
        // Properly close each connection with state tracking
        if let conn = telemetryConnection {
            serviceStatus[.telemetry] = false
            // Only attempt unsubscribe if connection was previously active
            if isConnected {
                unsubscribeFromTopics(connection: conn)
            }
            conn.stateUpdateHandler = nil // Remove handler before canceling
            conn.cancel()
        }
        
        if let conn = statusConnection {
            serviceStatus[.status] = false
            conn.stateUpdateHandler = nil
            conn.cancel()
        }

        // Clear connection references after cleanup
        telemetryConnection = nil
        statusConnection = nil
    }

    
    private func resetState() {
        isConnected = false
        cotViewModel?.isListeningCot = false
        messageBuffer.removeAll()
        connectionAttempts.removeAll()
    }
    
    deinit {
        if isConnected {
            disconnect()
        }
    }
}

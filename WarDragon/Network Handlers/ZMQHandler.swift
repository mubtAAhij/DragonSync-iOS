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
    private var telemetryAttempts = 0
    private var statusAttempts = 0
    private let maxConnectionAttempts = 3
    private let reconnectDelay: TimeInterval = 5.0
    private var reconnectTimer: Timer?
    private var telemetryConnection: NWConnection?
    private var statusConnection: NWConnection?
    private let queue = DispatchQueue(label: "com.wardragon.zmq")
    private var isDisconnecting = false
    private var messageBuffer = Data()
    
    private var telemetryHandler: ((String) -> Void)?
    private var statusHandler: ((String) -> Void)?
    
    private weak var cotViewModel: CoTViewModel?
    
    // ZMTP Protocol Constants
    private let zmqSubscribe: UInt8 = 0x01
    private let zmqUnsubscribe: UInt8 = 0x00
    private let zmqGreeting: Data = {
        // Signature + Version (3.0)
        var greeting = Data([0xFF, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x7F, 0x03, 0x00])
        // Mechanism (NULL) padded to 20 bytes
        greeting.append("NULL".padding(toLength: 20, withPad: " ", startingAt: 0).data(using: .ascii)!)
        // As-Server + Filler (31 bytes)
        greeting.append(Data([0x00] + Array(repeating: 0x00, count: 31)))
        return greeting
    }()
    
    init(cotViewModel: CoTViewModel) {
        self.cotViewModel = cotViewModel
    }
    
    func connect(host: String,
                 zmqTelemetryPort: UInt16,
                 zmqStatusPort: UInt16,
                 onTelemetry: @escaping (String) -> Void,
                 onStatus: @escaping (String) -> Void) {
        
        isDisconnecting = false
        
        if isConnected {
            disconnect()
        }
        
        telemetryHandler = onTelemetry
        statusHandler = onStatus
        
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
//        parameters.prohibitedInterfaceTypes = [.cellular]
//        parameters.requiredInterfaceType = .wifi
//        
        setupConnection(for: "telemetry", host: host, port: zmqTelemetryPort, parameters: parameters) { connection in
            self.telemetryConnection = connection
        }
        
        setupConnection(for: "status", host: host, port: zmqStatusPort, parameters: parameters) { connection in
            self.statusConnection = connection
        }
    }
    
    private func setupConnection(for type: String, host: String, port: UInt16, parameters: NWParameters,
                                 completion: @escaping (NWConnection) -> Void) {
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(integerLiteral: port))
        let connection = NWConnection(to: endpoint, using: parameters)
        
        connection.stateUpdateHandler = { [weak self] state in
            guard let self = self, !self.isDisconnecting else { return }
            
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    print("\(type) connection ready")
                    if type == "telemetry" {
                        self.telemetryAttempts = 0
                    } else {
                        self.statusAttempts = 0
                    }
                    self.performZMQHandshake(connection: connection, type: type) {
                        self.isConnected = true
                        self.cotViewModel?.isListeningCot = true
                        
                        if type == "telemetry" {
                            self.subscribe(to: "", connection: connection) // Subscribe to all topics initially
                            let telemetryTopics = ["AUX_ADV_IND", "DroneID"]
                            telemetryTopics.forEach { self.subscribe(to: $0, connection: connection) }
                        } else {
                            self.receiveMessages(from: connection, type: type)
                        }

                        
                        self.receiveMessages(from: connection, type: type)
                    }
                    
                case .failed(let error):
                    print("\(type) connection failed: \(error)")
                    self.connectionError = error.localizedDescription
                    if !self.isDisconnecting {  // Only handle drops if not intentionally disconnecting
                        self.handleConnectionDrop(type: type, host: host, port: port, parameters: parameters)
                    }
                    
                case .cancelled:
                    print("\(type) connection cancelled")
                    if !self.isDisconnecting {
                        self.handleConnectionDrop(type: type, host: host, port: port, parameters: parameters)
                    }
                    
                case .preparing:
                    print("\(type) connection preparing...")
                    
                case .waiting(let error):
                    print("\(type) connection waiting: \(error)")
                    self.handleConnectionDrop(type: type, host: host, port: port, parameters: parameters)
                    
                default:
                    break
                }
            }
        }
        
        completion(connection)
        connection.start(queue: queue)
    }
    
    private func performZMQHandshake(connection: NWConnection, type: String, completion: @escaping () -> Void) {
        // Send greeting
        connection.send(content: zmqGreeting, completion: .contentProcessed { error in
            if let error = error {
                print("Handshake error for \(type): \(error)")
                return
            }
            
            // Receive peer's greeting
            connection.receive(minimumIncompleteLength: 64, maximumLength: 64) { data, _, _, error in
                if let error = error {
                    print("Failed to receive peer greeting for \(type): \(error)")
                    return
                }
                
                guard let data = data, data.count == 64 else {
                    print("Invalid greeting received for \(type), greeting: \(String(describing: data))")
                    return
                }
                
                // Verify greeting (basic check)
                if data[0] == 0xFF && data[9] == 0x7F {
                    print("Valid ZMQ greeting received for \(type)")
                    completion()
                } else {
                    print("Invalid ZMQ greeting received for \(type)")
                }
            }
        })
    }
    
    private func frameZMQMessage(_ data: Data) -> Data {
        var frame = Data()
        let length = UInt64(data.count)
        
        if length > 255 {
            // Long message
            frame.append(0x02) // Flag for long message
            withUnsafeBytes(of: length.bigEndian) { frame.append(contentsOf: $0) }
        } else {
            // Short message
            frame.append(0x00) // Flag for short message
            frame.append(UInt8(length))
        }
        
        frame.append(data)
        return frame
    }
    
    private func subscribe(to topic: String, connection: NWConnection) {
        let subscribeData = Data([zmqSubscribe]) + topic.data(using: .utf8)!
        let framedMessage = frameZMQMessage(subscribeData)
        
        connection.send(content: framedMessage, completion: .contentProcessed { error in
            if let error = error {
                print("Failed to subscribe to \(topic): \(error)")
            } else {
                print("Subscribed to \(topic)")
            }
        })
    }
    
    private func processZMQFrame(_ data: Data) -> (message: Data?, remaining: Data) {
        guard data.count >= 2 else { return (nil, data) }
        
        let flags = data[0]
        let isLongMessage = (flags & 0x02) == 0x02
        
        if isLongMessage {
            guard data.count >= 9 else { return (nil, data) }
            
            let length = data[1...8].withUnsafeBytes { $0.load(as: UInt64.self).bigEndian }
            let messageStart = 9
            let messageEnd = messageStart + Int(length)
            
            guard data.count >= messageEnd else { return (nil, data) }
            
            let message = data[messageStart..<messageEnd]
            let remaining = data[messageEnd...]
            
            return (Data(message), Data(remaining))
        } else {
            let length = Int(data[1])
            let messageStart = 2
            let messageEnd = messageStart + length
            
            guard data.count >= messageEnd else { return (nil, data) }
            
            let message = data[messageStart..<messageEnd]
            let remaining = data[messageEnd...]
            
            return (Data(message), Data(remaining))
        }
    }
    
    private func handleConnectionDrop(type: String, host: String, port: UInt16, parameters: NWParameters) {
        guard !isDisconnecting else { return }
        
        print("\(type) connection dropped, attempting reconnect...")
        
        if type == "telemetry" {
            telemetryAttempts += 1
        } else {
            statusAttempts += 1
        }
        
        print("telem attempts: \(telemetryAttempts) and status attempts: \(statusAttempts)")
        
        if (type == "telemetry" && telemetryAttempts < maxConnectionAttempts) ||
            (type == "status" && statusAttempts < maxConnectionAttempts) {
            DispatchQueue.main.asyncAfter(deadline: .now() + reconnectDelay) { [weak self] in
                guard let self = self else { return }
                
                print("Attempting reconnection for \(type): \(type == "telemetry" ? self.telemetryAttempts : self.statusAttempts) of \(self.maxConnectionAttempts)")
                self.setupConnection(for: type, host: host, port: port, parameters: parameters) { connection in
                    if type == "telemetry" {
                        self.telemetryConnection = connection
                    } else {
                        self.statusConnection = connection
                    }
                }
            }
        } else {
            print("Max reconnection attempts reached for \(type)")
            DispatchQueue.main.async {
                // Only turn everything off if both have failed
                if self.telemetryAttempts >= self.maxConnectionAttempts &&
                    self.statusAttempts >= self.maxConnectionAttempts {
                    self.isConnected = false
                    self.cotViewModel?.isListeningCot = false
                    Settings.shared.toggleListening(false)
                    self.connectionError = "Connection lost after \(self.maxConnectionAttempts) attempts"
                }
            }

        }
    }
    
    private func validateAndProcessMessage(_ message: String, type: String) {
        guard let data = message.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        
        // Match dragonsync.py validation
        if let auxAdv = json["AUX_ADV_IND"] as? [String: Any],
           let aa = auxAdv["aa"] as? Int,
           aa == 0x8e89bed6,
           let _ = json["AdvData"] as? String {  // Use _ since we're just checking existence
            DispatchQueue.main.async {
                self.telemetryHandler?(message)
            }
        } else if json["DroneID"] != nil {
            DispatchQueue.main.async {
                self.telemetryHandler?(message)
            }
        }
    }
    
    private func receiveMessages(from connection: NWConnection, type: String) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self, !self.isDisconnecting else { return }
            
            defer {
                if !isComplete && self.isConnected && !self.isDisconnecting {
                    self.receiveMessages(from: connection, type: type)
                }
            }
            
            if let error = error {
                print("\(type) receive error: \(error)")
                return
            }
            
            if let data = data {
                self.messageBuffer.append(data)
                
                while !self.messageBuffer.isEmpty {
                    let (messageData, remaining) = self.processZMQFrame(self.messageBuffer)
                    self.messageBuffer = remaining
                    
                    if let messageData = messageData,
                       let message = String(data: messageData, encoding: .utf8) {
                        
                        if type == "telemetry" {
                            // Validate and process drone telemetry
                            self.validateAndProcessMessage(message, type: type)
                        } else {
                            // Status messages don't need validation, just forward that json
                            DispatchQueue.main.async {
                                self.statusHandler?(message)
                            }
                        }
                    } else {
                        break
                    }
                }
            }
        }
    }
    
    func disconnect() {
        isDisconnecting = true
        telemetryAttempts = 0
        statusAttempts = 0
        
        if let connection = telemetryConnection {
            let topics = ["AUX_ADV_IND", "DroneID"]
            for topic in topics {
                let unsubscribeData = Data([zmqUnsubscribe]) + topic.data(using: .utf8)!
                let framedMessage = frameZMQMessage(unsubscribeData)
                connection.send(content: framedMessage, completion: .contentProcessed { _ in })
            }
        }
        
        telemetryConnection?.cancel()
        statusConnection?.cancel()
        telemetryConnection = nil
        statusConnection = nil
        isConnected = false
        cotViewModel?.isListeningCot = false
        messageBuffer.removeAll()
        isDisconnecting = false
    }
    
    deinit {
        if isConnected {
            disconnect()
        }
    }
}

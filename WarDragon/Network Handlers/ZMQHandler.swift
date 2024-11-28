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
    @Published var subscribedTopics: [String] = [] // Tracks current subscriptions
    
    private var telemetryConnection: NWConnection?
    private var statusConnection: NWConnection?
    private let queue = DispatchQueue(label: "com.wardragon.zmq")
    
    private var telemetryHandler: ((String) -> Void)?
    private var statusHandler: ((String) -> Void)?
    
    func connect(host: String,
                 zmqTelemetryPort: UInt16,
                 zmqStatusPort: UInt16,
                 onTelemetry: @escaping (String) -> Void,
                 onStatus: @escaping (String) -> Void) {
        if isConnected {
            print("Already connected. Disconnecting before reconnecting.")
            disconnect()
        }
        
        telemetryHandler = onTelemetry
        statusHandler = onStatus
        
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        
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
            guard let self = self else { return }
            
            switch state {
            case .ready:
                print("\(type) connection ready")
                self.isConnected = true
                
                // Subscribe to default topics
                self.subscribeToDefaultTopics(connection: connection, type: type)
                
                // Start receiving messages
                self.receiveMessages(from: connection, type: type)
                
            case .failed(let error):
                print("\(type) connection failed: \(error)")
                self.connectionError = error.localizedDescription
                self.isConnected = false
                
            case .cancelled:
                print("\(type) connection cancelled")
                self.isConnected = false
                
            default:
                break
            }
        }
        
        completion(connection)
        connection.start(queue: queue)
    }
    
    private func subscribeToDefaultTopics(connection: NWConnection, type: String) {
        // Default topics
        let topics = ["{\"AUX_ADV_IND\"}", "{\"DroneID\"}"]
        
        for topic in topics {
            addSubscription(topic: topic, to: connection, type: type)
        }
    }
    
    func addSubscription(topic: String, to connection: NWConnection?, type: String) {
        guard let connection = connection else { return }
        guard !subscribedTopics.contains(topic) else {
            print("Already subscribed to topic '\(topic)' on \(type)")
            return
        }
        
        let subscribeData = Data([0x01]) + topic.data(using: .utf8)!
        
        connection.send(content: subscribeData, completion: .contentProcessed { error in
            if let error = error {
                print("Error subscribing to topic '\(topic)' on \(type): \(error)")
            } else {
                DispatchQueue.main.async {
                    self.subscribedTopics.append(topic)
                }
                print("Subscribed to topic '\(topic)' on \(type)")
            }
        })
    }
    
    
    private weak var cotViewModel: CoTViewModel?
    
    init(cotViewModel: CoTViewModel) {
        self.cotViewModel = cotViewModel
    }
    
    private func receiveMessages(from connection: NWConnection, type: String) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else {
                print("\(type) connection handler deallocated.")
                return
            }
            
            defer {
                if !isComplete && self.isConnected {
                    self.receiveMessages(from: connection, type: type)
                } else {
                    connection.cancel()
                }
            }
            
            if let error = error {
                print("\(type) receive error: \(error)")
                return
            }
            
            guard let data = data, !data.isEmpty else {
                print("No data received on \(type).")
                return
            }
            
            if let message = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    if type == "telemetry" {
                        self.telemetryHandler?(message)
                    } else {
                        self.statusHandler?(message)
                    }
                }
            }
        }
    }
    
    
    func disconnect() {
        if isConnected {
            if let telemetryConnection = telemetryConnection {
                unsubscribeFromAllTopics(connection: telemetryConnection, type: "telemetry")
            }
            
            if let statusConnection = statusConnection {
                unsubscribeFromAllTopics(connection: statusConnection, type: "status")
            }
        }
        
        telemetryConnection?.cancel()
        statusConnection?.cancel()
        telemetryConnection = nil
        statusConnection = nil
        isConnected = false
        subscribedTopics.removeAll()
    }
    
    
    private func unsubscribeFromAllTopics(connection: NWConnection, type: String) {
        for topic in subscribedTopics {
            let unsubscribeData = Data([0x00]) + topic.data(using: .utf8)!
            connection.send(content: unsubscribeData, completion: .contentProcessed { _ in })
        }
        print("Unsubscribed from all topics on \(type)")
    }
    
    deinit {
        disconnect()
    }
}


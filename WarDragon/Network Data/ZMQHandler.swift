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
    
    private var telemetryConnection: NWConnection?
    private var statusConnection: NWConnection?
    private let queue = DispatchQueue(label: "com.wardragon.zmq")
    
    private var telemetryHandler: ((String) -> Void)?
    private var statusHandler: ((String) -> Void)?
    
    func connect(host: String,
                telemetryPort: UInt16,
                statusPort: UInt16,
                onTelemetry: @escaping (String) -> Void,
                onStatus: @escaping (String) -> Void) {
        disconnect()
        
        telemetryHandler = onTelemetry
        statusHandler = onStatus
        
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        parameters.prohibitedInterfaceTypes = [.cellular]
        parameters.requiredInterfaceType = .wifi
        
        setupConnection(for: "telemetry", host: host, port: telemetryPort, parameters: parameters) { connection in
            self.telemetryConnection = connection
        }
        
        setupConnection(for: "status", host: host, port: statusPort, parameters: parameters) { connection in
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
                
                // Send ZMQ subscribe messages
                let sub1 = Data([0x01]) + "{\"AUX_ADV_IND\"".data(using: .utf8)!
                let sub2 = Data([0x01]) + "{\"DroneID\"".data(using: .utf8)!
                
                connection.batch {
                    connection.send(content: sub1, completion: .contentProcessed { error in
                        if let error = error {
                            print("Error sending \(type) subscribe 1: \(error)")
                        }
                    })
                    connection.send(content: sub2, completion: .contentProcessed { error in
                        if let error = error {
                            print("Error sending \(type) subscribe 2: \(error)")
                        }
                    })
                }
                
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
    
    private func receiveMessages(from connection: NWConnection, type: String) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            
            if let error = error {
                print("\(type) receive error: \(error)")
                return
            }
            
            if let data = data, let message = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    if type == "telemetry" {
                        self.telemetryHandler?(message)
                    } else {
                        self.statusHandler?(message)
                    }
                }
            }
            
            if !isComplete && self.isConnected {
                self.receiveMessages(from: connection, type: type)
            }
        }
    }
    
    func disconnect() {
        if let telemetryConnection = telemetryConnection {
            let unsub1 = Data([0x00]) + "{\"AUX_ADV_IND\"".data(using: .utf8)!
            let unsub2 = Data([0x00]) + "{\"DroneID\"".data(using: .utf8)!
            
            telemetryConnection.batch {
                telemetryConnection.send(content: unsub1, completion: .contentProcessed { _ in })
                telemetryConnection.send(content: unsub2, completion: .contentProcessed { _ in })
            }
        }
        
        telemetryConnection?.cancel()
        statusConnection?.cancel()
        telemetryConnection = nil
        statusConnection = nil
        isConnected = false
        telemetryHandler = nil
        statusHandler = nil
    }
    
    deinit {
        disconnect()
    }
}

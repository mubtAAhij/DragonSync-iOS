//
//  ZMQHandler.swift
//  WarDragon
//  Created by Root Down Digital on 11/25/24.
//

import Foundation
import SwiftyZeroMQ5

/// Handles ZeroMQ connections for both XPUB telemetry and PUB status messages
class ZMQHandler: ObservableObject {
    
    // MARK: - Types
    
    /// Callback type for handling received messages
    typealias MessageHandler = (String) -> Void
    
    /// Custom errors specific to ZMQHandler
    enum HandlerError: Error {
        case invalidHost
        case invalidPort
        case socketSetupFailed
        case connectionFailed
        case contextCreationFailed
    }
    
    // MARK: - Properties
    
    /// Published state indicating if ZMQ connections are active
    @Published var isConnected = false {
        didSet {
            if oldValue != isConnected {
                DispatchQueue.main.async {
                    Settings.shared.isListening = self.isConnected
                }
            }
        }
    }
    
    // Private properties
    private var context: SwiftyZeroMQ.Context?
    private var telemetrySocket: SwiftyZeroMQ.Socket?  // For XPUB telemetry data
    private var statusSocket: SwiftyZeroMQ.Socket?     // For PUB status data
    private var telemetryQueue: DispatchQueue?
    private var statusQueue: DispatchQueue?
    private var shouldContinueRunning = false
    
    // Socket configuration constants
    private static let defaultHighWaterMark: Int32 = 1000
    private static let defaultReceiveTimeout: Int32 = 1000  // milliseconds
    private static let defaultBufferSize: Int = 65536      // 64KB
    
    // MARK: - Public Methods
    
    /// Establishes connections to both telemetry and status publishers
    /// - Parameters:
    ///   - host: The host address to connect to
    ///   - zmqTelemetryPort: Port for telemetry data (XPUB)
    ///   - zmqStatusPort: Port for status data (PUB)
    ///   - onTelemetry: Callback for received telemetry messages
    ///   - onStatus: Callback for received status messages
    func connect(
        host: String,
        zmqTelemetryPort: UInt16,
        zmqStatusPort: UInt16,
        onTelemetry: @escaping MessageHandler,
        onStatus: @escaping MessageHandler
    ) {
        // Validate inputs
        guard !host.isEmpty else {
            print("Error: Invalid host")
            return
        }
        
        guard zmqTelemetryPort > 0 && zmqStatusPort > 0 else {
            print("Error: Invalid ports")
            return
        }
        
        // Prevent duplicate connections
        guard !isConnected else {
            print("Already connected")
            return
        }
        
        // Ensure clean state
        disconnect()
        shouldContinueRunning = true
        
        do {
            // Initialize and configure context
            context = try SwiftyZeroMQ.Context()
            try configureContext(context!)
            
            // Setup sockets
            telemetrySocket = try setupTelemetrySocket(
                context: context!,
                host: host,
                port: zmqTelemetryPort
            )
            
            statusSocket = try setupStatusSocket(
                context: context!,
                host: host,
                port: zmqStatusPort
            )
            
            // Create dedicated queues
            telemetryQueue = DispatchQueue(label: "com.wardragon.telemetry", qos: .userInitiated)
            statusQueue = DispatchQueue(label: "com.wardragon.status", qos: .userInitiated)
            
            // Start receive loops
            startReceiving(
                socket: telemetrySocket!,
                queue: telemetryQueue!,
                name: "Telemetry",
                handler: onTelemetry
            )
            
            startReceiving(
                socket: statusSocket!,
                queue: statusQueue!,
                name: "Status",
                handler: onStatus
            )
            
            isConnected = true
            
        } catch let error as SwiftyZeroMQ.ZeroMQError {
            handleZMQError(error)
            disconnect()
        } catch {
            print("Unexpected error during connection: \(error)")
            disconnect()
        }
    }
    
    // MARK: - Private Methods
    
    private func configureContext(_ context: SwiftyZeroMQ.Context) throws {
        try context.setBlocky(true)     // Default but explicit
        try context.setIOThreads(1)     // Single I/O thread sufficient for our needs
        try context.setMaxSockets(2)    // We only need 2 sockets
    }
    
    private func setupTelemetrySocket(
        context: SwiftyZeroMQ.Context,
        host: String,
        port: UInt16
    ) throws -> SwiftyZeroMQ.Socket {
        print("Setting up telemetry SUB socket...")
        let socket = try context.socket(.subscribe)
        try configureSocket(socket)
        print("Connecting SUB to tcp://\(host):\(port)...")
        try socket.connect("tcp://\(host):\(port)")
        return socket
    }
    
    private func setupStatusSocket(
        context: SwiftyZeroMQ.Context,
        host: String,
        port: UInt16
    ) throws -> SwiftyZeroMQ.Socket {
        let socket = try context.socket(.subscribe)
        try configureSocket(socket)
        try socket.connect("tcp://\(host):\(port)")
        print("Connecting SUB to tcp://\(host):\(port)...")
        try socket.connect("tcp://\(host):\(port)")
        return socket
    }
    
    private func configureSocket(_ socket: SwiftyZeroMQ.Socket) throws {
        try socket.setRecvHighWaterMark(Self.defaultHighWaterMark)
        try socket.setLinger(0)
        try socket.setMaxReconnectInterval(10)
        try socket.setRecvTimeout(Self.defaultReceiveTimeout)
        try socket.setImmediate(true)
        try socket.setSubscribe("")  // Subscribe to all topics
    }
    
    private func startReceiving(
        socket: SwiftyZeroMQ.Socket,
        queue: DispatchQueue,
        name: String,
        handler: @escaping MessageHandler
    ) {
        print("Starting \(name) receiver...")
        
        queue.async { [weak self] in
            guard let self = self else { return }
            
            while self.shouldContinueRunning {
                do {
                    print("\(name): Waiting for message...")
                    
                    if let data = try socket.recv(bufferLength: Self.defaultBufferSize) {
                        if let message = String(data: data, encoding: .utf8) {
                            print("\(name): Received message: \(message)")
                            DispatchQueue.main.async {
                                handler(message)
                            }
                        } else {
                            print("\(name): Failed to decode message as UTF-8")
                        }
                    }
                } catch let error as SwiftyZeroMQ.ZeroMQError {
                    print("\(name) Error: \(error.description)")
                    if error.description != "Resource temporarily unavailable" && self.shouldContinueRunning {
                        self.handleZMQError(error, context: name)
                    }
                } catch {
                    if self.shouldContinueRunning {
                        print("\(name) Unexpected Error: \(error)")
                    }
                }
//                // Add a 5-second delay after processing each message
//                if self.shouldContinueRunning {
//                    print("\(name): Sleeping for 5 seconds...")
//                    Thread.sleep(forTimeInterval: 5.0)
//                }
            }
            print("\(name) receiver stopped.")
        }
    }
    
    private func handleZMQError(_ error: SwiftyZeroMQ.ZeroMQError, context: String = "") {
        let errorContext = context.isEmpty ? "" : "[\(context)] "
        switch error.description {
        case "Context was terminated":
            print("\(errorContext)Context was terminated")
        case "Resource temporarily unavailable":
            print("\(errorContext)Non-blocking operation would block")
        case "Invalid argument":
            print("\(errorContext)Invalid argument")
        case "Bad address":
            print("\(errorContext)Memory fault")
        case "Interrupted system call":
            print("\(errorContext)Operation interrupted")
        default:
            print("\(errorContext)ZMQ Error: \(error)")
        }
    }
    
    // MARK: - Lifecycle
    
    // Disconnect all ZMQ connections and clean up resources
    func disconnect() {
        print("ZMQHandler: Disconnect called")
        shouldContinueRunning = false
        
        do {
            print("ZMQHandler: Closing sockets...")
            try telemetrySocket?.close()
            try statusSocket?.close()
            
            print("ZMQHandler: Terminating context...")
            try context?.terminate()
        } catch let error as SwiftyZeroMQ.ZeroMQError {
            handleZMQError(error)
        } catch {
            print("Cleanup Error: \(error)")
        }
        
        telemetrySocket = nil
        statusSocket = nil
        context = nil
        telemetryQueue = nil
        statusQueue = nil
        isConnected = false
        print("ZMQHandler: Disconnect complete")
    }
    
    deinit {
        if isConnected {
            disconnect()
        }
    }
}

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
            
        } catch let error as ZeroMQError {
            handleZMQError(error)
            disconnect()
        } catch {
            print("Unexpected error during connection: \(error)")
            disconnect()
        }
    }
    
    /// Disconnects all ZMQ connections and cleans up resources
    func disconnect() {
        shouldContinueRunning = false
        
        do {
            // Close sockets first
            try telemetrySocket?.close()
            try statusSocket?.close()
            
            // Then terminate context
            try context?.terminate()
        } catch let error as ZeroMQError {
            handleZMQError(error)
        } catch {
            print("Cleanup Error: \(error)")
        }
        
        // Clear all resources
        telemetrySocket = nil
        statusSocket = nil
        context = nil
        telemetryQueue = nil
        statusQueue = nil
        
        // Update state last
        isConnected = false
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
        let socket = try context.socket(.xsubscribe)  // For XPUB server
        try configureSocket(socket)
        try socket.connect("tcp://\(host):\(port)")
        return socket
    }
    
    private func setupStatusSocket(
        context: SwiftyZeroMQ.Context,
        host: String,
        port: UInt16
    ) throws -> SwiftyZeroMQ.Socket {
        let socket = try context.socket(.subscribe)  // For PUB server
        try configureSocket(socket)
        try socket.connect("tcp://\(host):\(port)")
        return socket
    }
    
    private func configureSocket(_ socket: SwiftyZeroMQ.Socket) throws {
        try socket.setRecvHighWaterMark(Self.defaultHighWaterMark)
        try socket.setLinger(0)
        try socket.setReceiveTimeout(Self.defaultReceiveTimeout)
        try socket.setImmediate(true)
        try socket.setSubscribe("")  // Subscribe to all topics
    }
    
    private func startReceiving(
        socket: SwiftyZeroMQ.Socket,
        queue: DispatchQueue,
        name: String,
        handler: @escaping MessageHandler
    ) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            while self.shouldContinueRunning {
                do {
                    if let data = try socket.recv(bufferLength: Self.defaultBufferSize) {
                        if let message = String(data: data, encoding: .utf8) {
                            DispatchQueue.main.async {
                                handler(message)
                            }
                        }
                    }
                } catch let error as ZeroMQError {
                    // Ignore EAGAIN which just means no message available
                    if error.errorCode != EAGAIN && self.shouldContinueRunning {
                        self.handleZMQError(error, context: name)
                    }
                } catch {
                    if self.shouldContinueRunning {
                        print("Unexpected \(name) Error: \(error)")
                    }
                }
            }
        }
    }
    
    private func handleZMQError(_ error: ZeroMQError, context: String = "") {
        let errorContext = context.isEmpty ? "" : "[\(context)] "
        switch error.errorCode {
        case ETERM:
            print("\(errorContext)Context was terminated")
        case EAGAIN:
            print("\(errorContext)Non-blocking operation would block")
        case EINVAL:
            print("\(errorContext)Invalid argument")
        case EFAULT:
            print("\(errorContext)Memory fault")
        case EINTR:
            print("\(errorContext)Operation interrupted")
        default:
            print("\(errorContext)ZMQ Error: \(error)")
        }
    }
    
    // MARK: - Lifecycle
    
    deinit {
        disconnect()
    }
}

//
//  ZMQHandler.swift
//  WarDragon
//  Created by Root Down Digital on 11/25/24.
//

import Foundation
import SwiftyZeroMQ5

class ZMQHandler {
    @Published var isConnected = false {
        didSet {
            if oldValue != isConnected {
                DispatchQueue.main.async {
                    Settings.shared.isListening = self.isConnected
                }
            }
        }
    }
    
    private struct Metrics {
        var messageCount: Int = 0
        var errorCount: Int = 0
        var lastMessageTime: Date?
        var lastErrorTime: Date?
        var reconnectAttempts: Int = 0
        var bytesReceived: Int64 = 0
    }
    
    private struct Config {
        let maxReconnectAttempts: Int = 10
        let maxReconnectDelay: TimeInterval = 30.0
        let healthCheckInterval: TimeInterval = 5.0
    }
    
    private var metrics = Metrics()
    private let config = Config()
    private let healthCheckTimer: DispatchSourceTimer
    
    private var context: SwiftyZeroMQ.Context?
    private var telemetrySocket: SwiftyZeroMQ.Socket?
    private var statusSocket: SwiftyZeroMQ.Socket?
    private var poller: SwiftyZeroMQ.Poller?
    private var shouldContinueRunning = false
    private let processor = ZMQMessageProcessor()
    
    private let retryInterval: TimeInterval = 5.0
    private let socketTimeout: Int32 = 1000 // ms
    private let highWaterMark: Int32 = 1000
    
    //MARK - Connection
    
    init() {
        healthCheckTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        healthCheckTimer.schedule(deadline: .now() + config.healthCheckInterval,
                                  repeating: config.healthCheckInterval)
        healthCheckTimer.setEventHandler { [weak self] in
            self?.performHealthCheck()
        }
    }
    
    private func performHealthCheck() {
        guard isConnected else { return }
        
        if let lastMessage = metrics.lastMessageTime,
           Date().timeIntervalSince(lastMessage) > config.healthCheckInterval * 2 {
            print("Connection may be stale, attempting recovery...")
            disconnect()
        }
    }
    
    func connect(
        host: String,
        zmqTelemetryPort: UInt16,
        zmqStatusPort: UInt16,
        onTelemetry: @escaping (String) -> Void,
        onStatus: @escaping (String) -> Void
    ) {
        guard !isConnected else { return }
        
        disconnect()
        shouldContinueRunning = true
        metrics.reconnectAttempts += 1
        
        do {
            try setupZMQ(
                host: host,
                telemetryPort: zmqTelemetryPort,
                statusPort: zmqStatusPort
            )
            
            startPolling(onTelemetry: onTelemetry, onStatus: onStatus)
            isConnected = true
            
        } catch {
            print("ZMQ Setup Error: \(error)")
            scheduleReconnect(
                host: host,
                telemetryPort: zmqTelemetryPort,
                statusPort: zmqStatusPort,
                onTelemetry: onTelemetry,
                onStatus: onStatus
            )
        }
    }
    
    private func setupZMQ(host: String, telemetryPort: UInt16, statusPort: UInt16) throws {
        context = try SwiftyZeroMQ.Context()
        try context?.setBlocky(true)
        try context?.setIOThreads(1)
        
        telemetrySocket = try context?.socket(.subscribe)
        statusSocket = try context?.socket(.subscribe)
        
        try configureSocket(telemetrySocket!, host: host, port: telemetryPort)
        try configureSocket(statusSocket!, host: host, port: statusPort)
        
        poller = SwiftyZeroMQ.Poller()
        try poller?.register(socket: telemetrySocket!, flags: .pollIn)
        try poller?.register(socket: statusSocket!, flags: .pollIn)
    }
    
    private func configureSocket(_ socket: SwiftyZeroMQ.Socket, host: String, port: UInt16) throws {
        try socket.setSubscribe("")
        try socket.setRecvHighWaterMark(highWaterMark)
        try socket.setLinger(0)
        try socket.setRecvTimeout(socketTimeout)
        try socket.setImmediate(true)
        try socket.setReconnectInterval(Int32(retryInterval * 1000))
        try socket.connect("tcp://\(host):\(port)")
    }
    
    
    private func startPolling(onTelemetry: @escaping (String) -> Void, onStatus: @escaping (String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            while self.shouldContinueRunning {
                do {
                    if let items = try self.poller?.poll(timeout: 0.1) {
                        for (socket, events) in items {
                            if events.contains(.pollIn) {
                                try self.handleReceivedMessage(
                                    from: socket,
                                    onTelemetry: onTelemetry,
                                    onStatus: onStatus
                                )
                            }
                        }
                    }
                } catch let error as SwiftyZeroMQ.ZeroMQError {
                    if error.description != "Resource temporarily unavailable" &&
                        self.shouldContinueRunning {
                        print("ZMQ Polling Error: \(error)")
                    }
                } catch {
                    if self.shouldContinueRunning {
                        print("ZMQ Unexpected Error: \(error)")
                    }
                }
            }
        }
    }
    
    
    private func handleReceivedMessage(
        from socket: SwiftyZeroMQ.Socket,
        onTelemetry: @escaping (String) -> Void,
        onStatus: @escaping (String) -> Void
    ) throws {
        guard let data = try socket.recv(bufferLength: 65536),
              let message = String(data: data, encoding: .utf8) else {
            return
        }
        
        metrics.messageCount += 1
        metrics.lastMessageTime = Date()
        metrics.bytesReceived += Int64(data.count)
        
        DispatchQueue.main.async {
            if socket === self.telemetrySocket {
                if let processed = self.processor.processTelemetryMessage(message) {
                    onTelemetry(processed)
                }
            } else if socket === self.statusSocket {
                if let processed = self.processor.processStatusMessage(message) {
                    onStatus(processed)
                }
            }
        }
    }
    
    private func scheduleReconnect(
        host: String,
        telemetryPort: UInt16,
        statusPort: UInt16,
        onTelemetry: @escaping (String) -> Void,
        onStatus: @escaping (String) -> Void
    ) {
        DispatchQueue.global().asyncAfter(deadline: .now() + retryInterval) { [weak self] in
            self?.connect(
                host: host,
                zmqTelemetryPort: telemetryPort,
                zmqStatusPort: statusPort,
                onTelemetry: onTelemetry,
                onStatus: onStatus
            )
        }
    }
    
    private func getMetrics() -> Metrics {
        return metrics
    }
    
    func disconnect() {
        shouldContinueRunning = false
        
        do {
            try telemetrySocket?.close()
            try statusSocket?.close()
            try context?.terminate()
        } catch {
            print("ZMQ Cleanup Error: \(error)")
        }
        
        telemetrySocket = nil
        statusSocket = nil
        context = nil
        poller = nil
        isConnected = false
    }
    
    deinit {
        disconnect()
    }
}

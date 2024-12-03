//
//  ZMQHandler.swift
//  WarDragon
//  Created by Root Down Digital on 11/25/24.
//

import Foundation
import SwiftyZeroMQ5


class ZMQHandler: ObservableObject {
    @Published var isConnected = false {
        didSet {
            if oldValue != isConnected {
                DispatchQueue.main.async {
                    Settings.shared.isListening = self.isConnected
                }
            }
        }
    }
    
    private var context: SwiftyZeroMQ.Context?
    private var telemetrySocket: SwiftyZeroMQ.Socket?
    private var statusSocket: SwiftyZeroMQ.Socket?
    private var poller: SwiftyZeroMQ.Poller?
    private var pollingQueue: DispatchQueue?
    private var shouldContinueRunning = false
    
    typealias MessageHandler = (String) -> Void
    
    func connect(
        host: String,
        zmqTelemetryPort: UInt16,
        zmqStatusPort: UInt16,
        onTelemetry: @escaping MessageHandler,
        onStatus: @escaping MessageHandler
    ) {
        guard !host.isEmpty && zmqTelemetryPort > 0 && zmqStatusPort > 0 else {
            print("Invalid connection parameters")
            return
        }
        
        guard !isConnected else {
            print("Already connected")
            return
        }
        
        disconnect()
        shouldContinueRunning = true
        
        do {
            // Initialize context and poller
            context = try SwiftyZeroMQ.Context()
            poller = SwiftyZeroMQ.Poller()
            
            // Setup telemetry socket
            telemetrySocket = try context?.socket(.subscribe)
            try telemetrySocket?.setSubscribe("")
            try configureSocket(telemetrySocket!)
            try telemetrySocket?.connect("tcp://\(host):\(zmqTelemetryPort)")
            try poller?.register(socket: telemetrySocket!, flags: .pollIn)
            
            // Setup status socket
            statusSocket = try context?.socket(.subscribe)
            try statusSocket?.setSubscribe("")
            try configureSocket(statusSocket!)
            try statusSocket?.connect("tcp://\(host):\(zmqStatusPort)")
            try poller?.register(socket: statusSocket!, flags: .pollIn)
            
            // Start polling on background queue
            pollingQueue = DispatchQueue(label: "com.wardragon.zmq.polling")
            startPolling(onTelemetry: onTelemetry, onStatus: onStatus)
            
            isConnected = true
            print("ZMQ: Connected successfully")
            
        } catch {
            print("ZMQ Setup Error: \(error)")
            disconnect()
        }
    }
    
    private func configureSocket(_ socket: SwiftyZeroMQ.Socket) throws {
        try socket.setRecvHighWaterMark(1000)
        try socket.setLinger(0)
        try socket.setRecvTimeout(1000)
        try socket.setImmediate(true)
    }
    
    private func startPolling(onTelemetry: @escaping MessageHandler, onStatus: @escaping MessageHandler) {
        pollingQueue?.async { [weak self] in
            guard let self = self else { return }
            
            while self.shouldContinueRunning {
                do {
                    if let items = try self.poller?.poll(timeout: 0.1) {
                        for (socket, events) in items {
                            if events.contains(.pollIn) {
                                // Get raw data from socket
                                if let data = try socket.recv(bufferLength: 65536),
                                   let jsonString = String(data: data, encoding: .utf8) {
                                    
                                    // Convert to XML based on socket type
                                    if socket === self.telemetrySocket {
                                        if let xmlMessage = self.convertTelemetryToXML(jsonString) {
                                            DispatchQueue.main.async {
                                                onTelemetry(xmlMessage)
                                            }
                                        }
                                    } else if socket === self.statusSocket {
                                        if let xmlMessage = self.convertStatusToXML(jsonString) {
                                            DispatchQueue.main.async {
                                                onStatus(xmlMessage)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                } catch let error as SwiftyZeroMQ.ZeroMQError {
                    if error.description != "Resource temporarily unavailable" && self.shouldContinueRunning {
                        print("ZMQ Polling Error: \(error)")
                    }
                } catch {
                    if self.shouldContinueRunning {
                        print("ZMQ Polling Error: \(error)")
                    }
                }
            }
        }
    }
    
    private func convertTelemetryToXML(_ jsonString: String) -> String? {
        guard let jsonData = jsonString.data(using: .utf8) else { return nil }
        
        do {
            // Handle both array and single object formats
            if let array = try JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] {
                return createDroneXML(from: array)
            } else if let dict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                return createDroneXML(from: [dict])
            }
        } catch {
            print("Telemetry JSON parsing error: \(error)")
        }
        return nil
    }
    
    private func convertStatusToXML(_ jsonString: String) -> String? {
        guard let jsonData = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return nil
        }
        return createStatusXML(json)
    }
    
    private func createDroneXML(from messages: [[String: Any]]) -> String {
        var droneInfo: [String: Any] = [:]
        
        // Parse all message parts
        for message in messages {
            if let basicId = message["Basic ID"] as? [String: Any],
               let idType = basicId["id_type"] as? String {
                if (idType == "Serial Number (ANSI/CTA-2063-A)" ||
                    idType == "CAA Assigned Registration ID") &&
                    droneInfo["id"] == nil {
                    droneInfo["id"] = basicId["id"] as? String ?? "unknown"
                }
            }
            
            if let location = message["Location/Vector Message"] as? [String: Any] {
                droneInfo["lat"] = location["latitude"] as? Double ?? 0.0
                droneInfo["lon"] = location["longitude"] as? Double ?? 0.0
                droneInfo["speed"] = location["speed"] as? Double ?? 0.0
                droneInfo["vspeed"] = location["vert_speed"] as? Double ?? 0.0
                droneInfo["alt"] = location["geodetic_altitude"] as? Double ?? 0.0
                droneInfo["height"] = location["height_agl"] as? Double ?? 0.0
            }
            
            if let selfId = message["Self-ID Message"] as? [String: Any] {
                droneInfo["description"] = selfId["text"] as? String ?? ""
            }
            
            if let system = message["System Message"] as? [String: Any] {
                droneInfo["pilot_lat"] = system["latitude"] as? Double ?? 0.0
                droneInfo["pilot_lon"] = system["longitude"] as? Double ?? 0.0
            }
        }
        
        var id = droneInfo["id"] as? String ?? "unknown"
        if !id.starts(with: "drone-") {
            id = "drone-\(id)"
        }
        
        return """
        <event version="2.0" uid="\(id)" type="a-f-G-U-C">
          <point lat="\(droneInfo["lat"] as? Double ?? 0.0)" lon="\(droneInfo["lon"] as? Double ?? 0.0)" hae="\(droneInfo["alt"] as? Double ?? 0.0)" ce="9999999" le="9999999"/>
          <detail>
            <contact callsign="\(id)"/>
            <track course="0" speed="\(droneInfo["speed"] as? Double ?? 0.0)"/>
            <remarks>\(droneInfo["description"] as? String ?? "")</remarks>
            <Speed>\(droneInfo["speed"] as? Double ?? 0.0)</Speed>
            <VerticalSpeed>\(droneInfo["vspeed"] as? Double ?? 0.0)</VerticalSpeed>
            <Altitude>\(droneInfo["alt"] as? Double ?? 0.0)</Altitude>
            <height>\(droneInfo["height"] as? Double ?? 0.0)</height>
            <PilotLocation>
              <lat>\(droneInfo["pilot_lat"] as? Double ?? 0.0)</lat>
              <lon>\(droneInfo["pilot_lon"] as? Double ?? 0.0)</lon>
            </PilotLocation>
          </detail>
        </event>
        """
    }
    
    private func createStatusXML(_ json: [String: Any]) -> String {
        let serialNumber = json["serial_number"] as? String ?? "8447891c1561"
        let gpsData = json["gps_data"] as? [String: Any] ?? [:]
        let systemStats = json["system_stats"] as? [String: Any] ?? [:]
        
        let memory = systemStats["memory"] as? [String: Any] ?? [:]
        let memoryTotal = Double(memory["total"] as? Int64 ?? 0) / (1024 * 1024)
        let memoryAvailable = Double(memory["available"] as? Int64 ?? 0) / (1024 * 1024)
        
        let disk = systemStats["disk"] as? [String: Any] ?? [:]
        let diskTotal = Double(disk["total"] as? Int64 ?? 0) / (1024 * 1024)
        let diskUsed = Double(disk["used"] as? Int64 ?? 0) / (1024 * 1024)

        // Exact format that CoTMessageParser.parseRemarks() expects
        let remarks = "CPU Usage: \(systemStats["cpu_usage"] as? Double ?? 0.0)%, " +
                     "Memory Total: \(String(format: "%.1f", memoryTotal)) MB, " +
                     "Memory Available: \(String(format: "%.1f", memoryAvailable)) MB, " +
                     "Disk Total: \(String(format: "%.1f", diskTotal)) MB, " +
                     "Disk Used: \(String(format: "%.1f", diskUsed)) MB, " +
                     "Temperature: \(systemStats["temperature"] as? Double ?? 0.0)°C, " +
                     "Uptime: \(systemStats["uptime"] as? Double ?? 0.0) seconds"

        return """
        <event version="2.0" uid="\(serialNumber)" type="b-m-p-s-m">
            <point lat="\(gpsData["latitude"] as? Double ?? 0.0)" lon="\(gpsData["longitude"] as? Double ?? 0.0)" hae="\(gpsData["altitude"] as? Double ?? 0.0)" ce="9999999" le="9999999"/>
            <detail>
                <status readiness="true"/>
                <remarks>\(remarks)</remarks>
            </detail>
        </event>
        """
    }
    
    func disconnect() {
        print("ZMQ: Disconnecting...")
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
        print("ZMQ: Disconnected")
    }
    
    deinit {
        disconnect()
    }
}

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
    
    func convertTelemetryToXML(_ jsonString: String) -> String? {
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
    
    func convertStatusToXML(_ jsonString: String) -> String? {
        guard let jsonData = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return nil
        }
        return createStatusXML(json)
    }
    
    private func createDroneXML(from messages: [[String: Any]]) -> String? {
        var droneInfo: [String: Any] = [:]
        
        // Parse all message parts
        for message in messages {
            // Handle BT4/5 messages
            if let auxAdvInd = message["AUX_ADV_IND"] as? [String: Any] {
                if let addr = auxAdvInd["addr"] as? String {
                    droneInfo["id"] = addr
                }
                // Need to check if BT messages have aa, advData, or other fields
                // Log all fields to verify what we're getting
                print("BT Message fields: \(auxAdvInd.keys)")
            }
            
            // Handle Basic ID
            if let basicId = message["Basic ID"] as? [String: Any] {
                droneInfo["id"] = basicId["id"] as? String
                droneInfo["id_type"] = basicId["id_type"] as? String
                droneInfo["ua_type"] = basicId["ua_type"] as? Int
                droneInfo["mac"] = basicId["MAC"] as? String
                // Log to verify all Basic ID fields
                print("Basic ID fields: \(basicId.keys)")
            }
            
            // Handle Location
            if let location = message["Location/Vector Message"] as? [String: Any] {
                let lat = location["latitude"] as? Double ?? 0.0
                let lon = location["longitude"] as? Double ?? 0.0
                
                if lat == 0.0 && lon == 0.0 {
                    print("Discarding telemetry with zero coordinates")
                    return nil
                }
                
                droneInfo["lat"] = lat
                droneInfo["lon"] = lon
                droneInfo["speed"] = location["speed"] as? Double
                droneInfo["time_speed"] = location["time_speed"] as? Int
                droneInfo["vspeed"] = location["vert_speed"] as? Double
                droneInfo["alt"] = location["geodetic_altitude"] as? Double
                droneInfo["height"] = location["height_agl"] as? Double
                droneInfo["status"] = location["status"] as? Int
                droneInfo["direction"] = location["direction"] as? Int
                droneInfo["alt_pressure"] = location["alt_pressure"] as? Double
                droneInfo["height_type"] = location["height_type"] as? Int
                droneInfo["horiz_acc"] = location["horiz_acc"] as? Double
                droneInfo["vert_acc"] = location["vert_acc"] as? Double
                droneInfo["baro_acc"] = location["baro_acc"] as? Double
                droneInfo["speed_acc"] = location["speed_acc"] as? Double
                droneInfo["timestamp"] = location["timestamp"] as? Int
                // Log to verify all Location fields
                print("Location fields: \(location.keys)")
            }
            
            // Handle Self-ID
            if let selfId = message["Self-ID Message"] as? [String: Any] {
                droneInfo["description"] = selfId["description"] as? String
                droneInfo["self_id_type"] = selfId["type"] as? Int
                droneInfo["self_id_id"] = selfId["id"] as? String
                droneInfo["timestamp"] = selfId["timestamp"] as? Int
                // Log to verify all Self-ID fields
                print("Self-ID fields: \(selfId.keys)")
            }
            
            // Handle System Message
            if let system = message["System Message"] as? [String: Any] {
                droneInfo["pilot_lat"] = system["operator_lat"] as? Double
                droneInfo["pilot_lon"] = system["operator_lon"] as? Double
                droneInfo["area_count"] = system["area_count"] as? Int
                droneInfo["area_radius"] = system["area_radius"] as? Double
                droneInfo["area_ceiling"] = system["area_ceiling"] as? Double
                droneInfo["area_floor"] = system["area_floor"] as? Double
                droneInfo["operator_alt_geo"] = system["operator_alt_geo"] as? Double
                droneInfo["classification"] = system["classification"] as? Int
                droneInfo["timestamp"] = system["timestamp"] as? Int
                // Log to verify all System fields
                print("System fields: \(system.keys)")
            }
            
            // Handle Auth Message
            if let auth = message["Auth Message"] as? [String: Any] {
                droneInfo["auth_type"] = auth["type"] as? Int
                droneInfo["auth_page"] = auth["page"] as? Int
                droneInfo["auth_length"] = auth["length"] as? Int
                droneInfo["auth_timestamp"] = auth["timestamp"] as? Int
                droneInfo["auth_data"] = auth["data"] as? String
                // Log to verify all Auth fields
                print("Auth fields: \(auth.keys)")
            }
        }

        // Add debug logging to see all collected fields
        print("All collected fields: \(droneInfo.keys)")

        var id = droneInfo["id"] as? String ?? "unknown"
//        if !id.starts(with: "drone-") {
//            id = "drone-\(id)"
//        }

        // Create XML with all available fields
        return """
        <event version="2.0" uid="\(id)" type="a-f-G-U-C">
          <point lat="\(droneInfo["lat"] as? Double ?? 0.0)" lon="\(droneInfo["lon"] as? Double ?? 0.0)" hae="\(droneInfo["alt"] as? Double ?? 0.0)" ce="9999999" le="9999999"/>
          <detail>
            <contact callsign="\(id)"/>
            <track course="\(droneInfo["direction"] as? Int ?? 0)" speed="\(droneInfo["speed"] as? Double ?? 0.0)"/>
            <remarks>\(droneInfo["description"] as? String ?? "")</remarks>
            <Speed>\(droneInfo["speed"] as? Double ?? 0.0)</Speed>
            <VerticalSpeed>\(droneInfo["vspeed"] as? Double ?? 0.0)</VerticalSpeed>
            <Altitude>\(droneInfo["alt"] as? Double ?? 0.0)</Altitude>
            <height>\(droneInfo["height"] as? Double ?? 0.0)</height>
            <status>\(droneInfo["status"] as? Int ?? 0)</status>
            <heightType>\(droneInfo["height_type"] as? Int ?? 0)</heightType>
            <TimeSpeed>\(droneInfo["time_speed"] as? Int ?? 0)</TimeSpeed>
            <AltPressure>\(droneInfo["alt_pressure"] as? Double ?? 0.0)</AltPressure>
            <HorizAcc>\(droneInfo["horiz_acc"] as? Double ?? 0.0)</HorizAcc>
            <VertAcc>\(droneInfo["vert_acc"] as? Double ?? 0.0)</VertAcc>
            <BaroAcc>\(droneInfo["baro_acc"] as? Double ?? 0.0)</BaroAcc>
            <SpeedAcc>\(droneInfo["speed_acc"] as? Double ?? 0.0)</SpeedAcc>
            <UAType>\(droneInfo["ua_type"] as? Int ?? 0)</UAType>
            <Classification>\(droneInfo["classification"] as? Int ?? 0)</Classification>
            <PilotLocation>
              <lat>\(droneInfo["pilot_lat"] as? Double ?? 0.0)</lat>
              <lon>\(droneInfo["pilot_lon"] as? Double ?? 0.0)</lon>
              <altGeo>\(droneInfo["operator_alt_geo"] as? Double ?? 0.0)</altGeo>
            </PilotLocation>
            <OperationArea>
              <count>\(droneInfo["area_count"] as? Int ?? 0)</count>
              <radius>\(droneInfo["area_radius"] as? Double ?? 0.0)</radius>
              <ceiling>\(droneInfo["area_ceiling"] as? Double ?? 0.0)</ceiling>
              <floor>\(droneInfo["area_floor"] as? Double ?? 0.0)</floor>
            </OperationArea>
          </detail>
        </event>
        """
    }
    
    private func createStatusXML(_ json: [String: Any]) -> String {
        // top level
        let serialNumber = json["serial_number"] as? String ?? ""
        let gpsData = json["gps_data"] as? [String: Any] ?? [:]
        let systemStats = json["system_stats"] as? [String: Any] ?? [:]
        
        // memory block
        let memory = systemStats["memory"] as? [String: Any] ?? [:]
        let memoryTotal = Double(memory["total"] as? Int64 ?? 0) / (1024 * 1024)
        let memoryAvailable = Double(memory["available"] as? Int64 ?? 0) / (1024 * 1024)
        let memoryPercent = Double(memory["percent"] as? Double ?? 0.0)
        let memoryUsed = Double(memory["used"] as? Int64 ?? 0) / (1024 * 1024)
        let memoryFree = Double(memory["free"] as? Int64 ?? 0) / (1024 * 1024)
        let memoryActive = Double(memory["active"] as? Int64 ?? 0) / (1024 * 1024)
        let memoryInactive = Double(memory["inactive"] as? Int64 ?? 0) / (1024 * 1024)
        let memoryBuffers = Double(memory["buffers"] as? Int64 ?? 0) / (1024 * 1024)
        let memoryShared = Double(memory["shared"] as? Int64 ?? 0) / (1024 * 1024)
        let memoryCached = Double(memory["cached"] as? Int64 ?? 0) / (1024 * 1024)
        let memorySlab = Double(memory["slab"] as? Int64 ?? 0) / (1024 * 1024)
        
        // disk stats
        let disk = systemStats["disk"] as? [String: Any] ?? [:]
        let diskTotal = Double(disk["total"] as? Int64 ?? 0) / (1024 * 1024)
        let diskUsed = Double(disk["used"] as? Int64 ?? 0) / (1024 * 1024)
        let diskFree = Double(disk["free"] as? Int64 ?? 0) / (1024 * 1024)
        let diskPercent = Double(disk["percent"] as? Double ?? 0.0)

        // Exact format that parseRemarks() expects
        let remarks = "CPU Usage: \(systemStats["cpu_usage"] as? Double ?? 0.0)%, " +
                     "Memory Total: \(String(format: "%.1f", memoryTotal)) MB, " +
                     "Memory Available: \(String(format: "%.1f", memoryAvailable)) MB, " +
                     "Memory Used: \(String(format: "%.1f", memoryUsed)) MB, " +
                     "Memory Free: \(String(format: "%.1f", memoryFree)) MB, " +
                     "Memory Active: \(String(format: "%.1f", memoryActive)) MB, " +
                     "Memory Inactive: \(String(format: "%.1f", memoryInactive)) MB, " +
                     "Memory Buffers: \(String(format: "%.1f", memoryBuffers)) MB, " +
                     "Memory Shared: \(String(format: "%.1f", memoryShared)) MB, " +
                     "Memory Cached: \(String(format: "%.1f", memoryCached)) MB, " +
                     "Memory Slab: \(String(format: "%.1f", memorySlab)) MB, " +
                     "Memory Percent: \(String(format: "%.1f", memoryPercent))%, " +
                     "Disk Total: \(String(format: "%.1f", diskTotal)) MB, " +
                     "Disk Used: \(String(format: "%.1f", diskUsed)) MB, " +
                     "Disk Free: \(String(format: "%.1f", diskFree)) MB, " +
                     "Disk Percent: \(String(format: "%.1f", diskPercent))%, " +
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

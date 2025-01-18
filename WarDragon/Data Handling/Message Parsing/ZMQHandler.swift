//
//  ZMQHandler.swift
//  WarDragon
//  Created by Root Down Digital on 11/25/24.
//

import Foundation
import SwiftyZeroMQ5


class ZMQHandler: ObservableObject {
    //MARK: - ZMQ Connection
    
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
            
            // Initial immediate poll for any pending messages
            pollingQueue?.async { [weak self] in
                guard let self = self else { return }
                do {
                    print("Performing initial poll...")
                    if let items = try self.poller?.poll(timeout: 0.1) {
                        for (socket, events) in items {
                            if events.contains(.pollIn) {
                                if let data = try socket.recv(bufferLength: 65536),
                                   let jsonString = String(data: data, encoding: .utf8) {
                                    print("Initial poll received data: \(jsonString.prefix(100))...")
                                    if socket === self.telemetrySocket {
                                        if let xmlMessage = self.convertTelemetryToXML(jsonString) {
                                            DispatchQueue.main.async {
                                                print("Converting to xml: \(jsonString)")
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
                    
                    // Start regular polling after initial poll
                    self.startPolling(onTelemetry: onTelemetry, onStatus: onStatus)
                    
                } catch {
                    print("Initial poll error: \(error)")
                    self.startPolling(onTelemetry: onTelemetry, onStatus: onStatus)
                }
            }
            
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
        try socket.setRecvTimeout(250) // longer timeout
        try socket.setImmediate(true)
        
        // Set TCP keep alive to detect connection issues
        try socket.setIntegerSocketOption(ZMQ_TCP_KEEPALIVE, 1)
        try socket.setIntegerSocketOption(ZMQ_TCP_KEEPALIVE_IDLE, 120)
        try socket.setIntegerSocketOption(ZMQ_TCP_KEEPALIVE_INTVL, 60)
    }
    
    private func startPolling(onTelemetry: @escaping MessageHandler, onStatus: @escaping MessageHandler) {
        pollingQueue?.async { [weak self] in
            guard let self = self else { return }
            
            while self.shouldContinueRunning {
                do {
                    if let items = try self.poller?.poll(timeout: 0.1) { // Reduce poll timeout
                        for (socket, events) in items {
                            if events.contains(.pollIn) {
                                if let data = try socket.recv(bufferLength: 65536),
                                   let jsonString = String(data: data, encoding: .utf8) {
                                    // Process immediately instead of dispatching
                                    if socket === self.telemetrySocket {
                                        if let xmlMessage = self.convertTelemetryToXML(jsonString) {
                                            print("Converting to xml: \(xmlMessage)")
                                            onTelemetry(xmlMessage)
                                        }
                                    } else if socket === self.statusSocket {
                                        if let xmlMessage = self.convertStatusToXML(jsonString) {
                                            onStatus(xmlMessage)
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
    
    //MARK: - Message Parsing & Conversion
    
    func convertTelemetryToXML(_ jsonString: String) -> String? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        print("Raw Message: ", jsonString)
        
        // Try to parse as array first
        if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            // Find the relevant messages in the array
            let basicId = jsonArray.first { $0["Basic ID"] != nil }?["Basic ID"] as? [String: Any]
            let location = jsonArray.first { $0["Location/Vector Message"] != nil }?["Location/Vector Message"] as? [String: Any]
            let operatorId = jsonArray.first { $0["Operator ID Message"] != nil }?["Operator ID Message"] as? [String: Any]
            
            if let basicId = basicId {
                let idType = basicId["id_type"] as? String ?? ""
                if idType.contains("CAA") {
                    print("SKIPPING THE CAA IN XML CONVERSION")
                    return nil
                }
                let droneId = basicId["id"] as? String ?? UUID().uuidString
                let mac = basicId["MAC"] as? String ?? ""
                let rssi = basicId["RSSI"] as? Int ?? 0
               
                
                // Parse location data, handling both string and numeric formats
                var lat = 0.0
                var lon = 0.0
                var alt = 0.0
                var speed = 0.0
                var vspeed = 0.0
                var height = 0.0
                
                if let location = location {
                    // Handle latitude
                    if let latStr = location["latitude"] as? String {
                        lat = Double(latStr) ?? 0.0
                    } else if let latNum = location["latitude"] as? Double {
                        lat = latNum
                    }
                    
                    // Handle longitude
                    if let lonStr = location["longitude"] as? String {
                        lon = Double(lonStr) ?? 0.0
                    } else if let lonNum = location["longitude"] as? Double {
                        lon = lonNum
                    }
                    
                    // Handle altitude
                    if let altStr = location["geodetic_altitude"] as? String {
                        alt = Double(altStr.replacingOccurrences(of: " m", with: "")) ?? 0.0
                    } else if let altNum = location["geodetic_altitude"] as? Double {
                        alt = altNum
                    }
                    
                    // Handle speed
                    if let speedStr = location["speed"] as? String {
                        speed = Double(speedStr.replacingOccurrences(of: " m/s", with: "")) ?? 0.0
                    } else if let speedNum = location["speed"] as? Double {
                        speed = speedNum
                    }
                    
                    // Handle vertical speed
                    if let vspeedStr = location["vert_speed"] as? String {
                        vspeed = Double(vspeedStr.replacingOccurrences(of: " m/s", with: "")) ?? 0.0
                    } else if let vspeedNum = location["vert_speed"] as? Double {
                        vspeed = vspeedNum
                    }
                    
                    // Handle height
                    if let heightStr = location["height_agl"] as? String {
                        height = Double(heightStr.replacingOccurrences(of: " m", with: "")) ?? 0.0
                    } else if let heightNum = location["height_agl"] as? Double {
                        height = heightNum
                    }
                }
                
                let now = ISO8601DateFormatter().string(from: Date())
                let stale = ISO8601DateFormatter().string(from: Date().addingTimeInterval(300))
                
                return """
                <event version="2.0" uid="drone-\(droneId)" type="a-f-G-U-C" time="\(now)" start="\(now)" stale="\(stale)" how="m-g">
                    <point lat="\(lat)" lon="\(lon)" hae="\(alt)" ce="9999999" le="999999"/>
                    <detail>
                        <remarks>MAC: \(mac), RSSI: \(rssi)dBm, Location/Vector: [Speed: \(speed) m/s, Vert Speed: \(vspeed) m/s, Geodetic Altitude: \(alt) m, Height AGL: \(height) m], Height Type: \(location?["height_type"] as? String ?? ""), Direction: \(location?["direction"] as? Int ?? 0), Timestamp: \(location?["timestamp"] as? String ?? "")]</remarks>
                        <contact endpoint="" phone="" callsign="drone-\(droneId)"/>
                        <precisionlocation geopointsrc="GPS" altsrc="GPS"/>
                        <color argb="-256"/>
                        <usericon iconsetpath="34ae1613-9645-4222-a9d2-e5f243dea2865/Military/UAV_quad.png"/>
                    </detail>
                </event>
                """
            }
        }
        
        print("Failed to parse message")
        return nil
    }
    
    private func getFieldValue(_ json: [String: Any], keys: [String], defaultValue: Any) -> Any {
        for key in keys {
            if let value = json[key], !(value is NSNull) {
                return value
            }
        }
        return defaultValue
    }
    
    func convertDJITelemetryToXML(_ json: [String: Any]) -> String? {
            let now = ISO8601DateFormatter().string(from: Date())
            let stale = ISO8601DateFormatter().string(from: Date().addingTimeInterval(60))
            
            // Handle field name variations
            let pilotLat: Double
            let pilotLon: Double
            if let system = json["System"] as? [String: Any],
               let pilotLocation = system["Pilot Location"] as? [String: Any] {
                pilotLat = getFieldValue(pilotLocation, keys: ["lat", "latitude"], defaultValue: 0.0) as! Double
                pilotLon = getFieldValue(pilotLocation, keys: ["lon", "longitude"], defaultValue: 0.0) as! Double
            } else {
                // Fallback to flat structure
                pilotLat = getFieldValue(json, keys: ["app_lat", "pilot_lat", "operator_lat"], defaultValue: 0.0) as! Double
                pilotLon = getFieldValue(json, keys: ["app_lon", "pilot_lon", "operator_lon"], defaultValue: 0.0) as! Double
            }
            let droneLat = getFieldValue(json, keys: ["drone_lat", "latitude", "lat"], defaultValue: 0.0) as! Double
            let droneLon = getFieldValue(json, keys: ["drone_lon", "longitude", "lon"], defaultValue: 0.0) as! Double
            let speed = getFieldValue(json, keys: ["horizontal_speed", "speed"], defaultValue: 0.0) as! Double
            let vertSpeed = getFieldValue(json, keys: ["vertical_speed", "vert_speed"], defaultValue: 0.0) as! Double
            let height = getFieldValue(json, keys: ["height_agl", "height"], defaultValue: 0.0) as! Double
            let altitude = getFieldValue(json, keys: ["geodetic_altitude", "altitude"], defaultValue: 0.0) as! Double
            let serialNumber = getFieldValue(json, keys: ["serial_number", "id"], defaultValue: "unknown") as! String
            let deviceType = getFieldValue(json, keys: ["device_type", "description"], defaultValue: "DJI Drone") as! String
            let rssi = getFieldValue(json, keys: ["rssi", "RSSI", "signal_strength"], defaultValue: 0) as! Int
            let mac = getFieldValue(json, keys: ["mac", "MAC"], defaultValue: "") as! String
            
            // UAType handling for both string and int formats
            let uaType: String
            if let typeInt = json["ua_type"] as? Int {
                uaType = String(typeInt)
            } else if let typeStr = json["ua_type"] as? String {
                uaType = typeStr == "Helicopter (or Multirotor)" ? "2" : "0"
            } else {
                uaType = "2"  // Default to helicopter
            }
            
            return """
            <event version="2.0" uid="drone-\(serialNumber)" type="a-f-G-U-C" time="\(now)" start="\(now)" stale="\(stale)" how="m-g">
                <point lat="\(droneLat)" lon="\(droneLon)" hae="\(altitude)" ce="9999999" le="999999"/>
                <detail>
                    <BasicID>
                        <DeviceID>drone-\((serialNumber.replacingOccurrences(of: "^drone-", with: "", options: .regularExpression)))</DeviceID>
                        <MAC>\(mac)</MAC>
                        <RSSI>\(rssi)</RSSI>
                        <Type>DJI</Type>
                        <UAType>\(uaType)</UAType>
                    </BasicID>
                    <LocationVector>
                        <Speed>\(speed)</Speed>
                        <VerticalSpeed>\(vertSpeed)</VerticalSpeed>
                        <Altitude>\(altitude)</Altitude>
                        <Height>\(height)</Height>
                    </LocationVector>
                    <System>
                        <Pilot Location>
                            <lat>\(pilotLat)</lat>
                            <lon>\(pilotLon)</lon>
                        </Pilot Location>
                    </System>
                    <SelfID>
                        <Description>\(deviceType)</Description>
                    </SelfID>
                    <color argb="-256"/>
                    <usericon iconsetpath="34ae1613-9645-4222-a9d2-e5f243dea2865/Military/UAV_quad.png"/>
                </detail>
            </event>
            """
        }
    
    func convertStatusToXML(_ jsonString: String) -> String? {
        guard let jsonData = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return nil
        }
        return createStatusXML(json)
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
    
    //MARK: - Services Manager
    
    func sendServiceCommand(_ command: [String: Any], completion: @escaping (Bool, Any?) -> Void) {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: command)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                if let statusSocket = statusSocket {
                    try statusSocket.send(string: jsonString)
                    
                    // Wait for response
                    if let response = try statusSocket.recv(bufferLength: 65536),
                       let responseString = String(data: response, encoding: .utf8),
                       let responseData = responseString.data(using: .utf8),
                       let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                       let cmdResponse = json["command_response"] as? [String: Any] {
                        
                        let success = cmdResponse["success"] as? Bool ?? false
                        completion(success, cmdResponse["data"])
                        return
                    }
                }
            }
            completion(false, "Failed to send command")
        } catch {
            completion(false, error.localizedDescription)
        }
    }
    
    func getServiceLogs(_ service: String, completion: @escaping (Result<String, Error>) -> Void) {
        let command: [String: Any] = [
            "command": [
                "type": "service_logs",
                "service": service,
                "timestamp": Date().timeIntervalSince1970
            ]
        ]
        
        sendServiceCommand(command) { success, response in
            if success, let logs = (response as? [String: Any])?["logs"] as? String {
                completion(.success(logs))
            } else {
                completion(.failure(NSError(domain: "", code: -1,
                                            userInfo: [NSLocalizedDescriptionKey: "Failed to get logs"])))
            }
        }
    }
    
    //MARK: - Cleanup
    
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

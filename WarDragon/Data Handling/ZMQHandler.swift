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
        try socket.setRecvTimeout(1000) // see if reducing to 100 from 1000 helps get all status messages
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
    
    func convertTelemetryToXML(_ message: String) -> String? {
        guard let data = message.data(using: .utf8),
              let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return nil
        }
        
        // Extract Basic ID with MAC and valid ID
        var basicID: [String: Any]?
        for message in jsonArray {
            if let bid = message["Basic ID"] as? [String: Any],
               let id = bid["id"] as? String,
               !id.isEmpty,
               bid["id_type"] as? String == "Serial Number (ANSI/CTA-2063-A)" {
                basicID = bid
                break
            }
        }
        
        guard let basicID = basicID,
              let id = basicID["id"] as? String,
              let mac = basicID["MAC"] as? String else {
            return nil
        }
        
        let now = ISO8601DateFormatter().string(from: Date())
        let stale = ISO8601DateFormatter().string(from: Date().addingTimeInterval(60))

        return """
        <event version="2.0" uid="drone-\(id)" type="a-f-G-U-C" time="\(now)" start="\(now)" stale="\(stale)" how="m-g">
          <point lat="0.0" lon="0.0" hae="0.0" ce="35.0" le="999999"/>
          <detail>
            <contact endpoint="" phone="" callsign="drone-\(id)"/>
            <MAC>\(mac)</MAC>
            <precisionlocation geopointsrc="gps" altsrc="gps"/>
            <remarks>Description: Drones ID test flight, Speed: 0.0 m/s, VSpeed: 0.0 m/s, Altitude: 0.0 m, Height: 0.0 m, Pilot Lat: 0.0, Pilot Lon: 0.0</remarks>
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
    
    private func createDroneXML(from messages: [[String: Any]]) -> String? {
        var droneInfo: [String: Any] = [:]
        
        for message in messages {
            
            if let auxAdvInd = message["AUX_ADV_IND"] as? [String: Any] {
                if let addr = auxAdvInd["addr"] as? String {
                    droneInfo["id"] = "drone-\(addr)"
                }
                droneInfo["rssi"] = auxAdvInd["rssi"] as? Int
                
                // Extract AdvA from aext if available
                if let aext = message["aext"] as? [String: Any],
                   let advA = aext["AdvA"] as? String {
                    // Parse "XX:XX:XX:XX:XX:XX (Public)" format from ZMQ
                    let macAddress = advA.components(separatedBy: " ")[0]
                    droneInfo["mac"] = macAddress
                }
            }
            
            // Process Basic ID from any source
            if let basicId = message["Basic ID"] as? [String: Any] {
                if droneInfo["id"] == nil {
                    let rawId = basicId["id"] as? String ?? UUID().uuidString
                    droneInfo["id"] = "drone-\(rawId == "NONE" ? UUID().uuidString : rawId)"
                }
                droneInfo["id_type"] = basicId["id_type"] as? String
                droneInfo["ua_type"] = basicId["ua_type"] as? Int
                droneInfo["MAC"] = basicId["MAC"] as? String
            }
            
            // Process Location data from any source
            if let location = message["Location/Vector Message"] as? [String: Any] {
                droneInfo["lat"] = location["latitude"] as? Double ?? 0.0
                droneInfo["lon"] = location["longitude"] as? Double ?? 0.0
                droneInfo["speed"] = location["speed"] as? Double ?? 0.0
                droneInfo["vspeed"] = location["vert_speed"] as? Double ?? 0.0
                droneInfo["alt"] = location["geodetic_altitude"] as? Double ?? 0.0
                droneInfo["height"] = location["height_agl"] as? Double ?? 0.0
                droneInfo["status"] = location["status"] as? Int ?? 0
                droneInfo["direction"] = location["direction"] as? Int ?? 0
                droneInfo["alt_pressure"] = location["alt_pressure"] as? Double ?? 0.0
                droneInfo["height_type"] = location["height_type"] as? Int ?? 0
                droneInfo["horiz_acc"] = location["horiz_acc"] as? Double ?? 0.0
                droneInfo["vert_acc"] = location["vert_acc"] as? Double ?? 0.0
                droneInfo["baro_acc"] = location["baro_acc"] as? Double ?? 0.0
                droneInfo["speed_acc"] = location["speed_acc"] as? Double ?? 0.0
            }
            
            // Process Self-ID from any source
            if let selfId = message["Self-ID Message"] as? [String: Any] {
                droneInfo["description"] = selfId["text"] as? String ?? selfId["description"] as? String
            }
            
            // Process System data from any source
            if let system = message["System Message"] as? [String: Any] {
                droneInfo["pilot_lat"] = system["operator_lat"] as? Double ?? system["latitude"] as? Double ?? 0.0
                droneInfo["pilot_lon"] = system["operator_lon"] as? Double ?? system["longitude"] as? Double ?? 0.0
                droneInfo["area_count"] = system["area_count"] as? Int ?? 0
                droneInfo["area_radius"] = system["area_radius"] as? Double ?? 0.0
                droneInfo["area_ceiling"] = system["area_ceiling"] as? Double ?? 0.0
                droneInfo["area_floor"] = system["area_floor"] as? Double ?? 0.0
                droneInfo["operator_alt_geo"] = system["operator_alt_geo"] as? Double ?? 0.0
                droneInfo["classification"] = system["classification"] as? Int ?? 0
            }
        }
        
        // Ensure valid ID exists
        let id = droneInfo["id"] as? String ?? "\(UUID().uuidString)"
        
        return """
        <event version="2.0" uid="\(id)" type="a-f-G-U-C">
            <point lat="\(droneInfo["lat"] as? Double ?? 0.0)" lon="\(droneInfo["lon"] as? Double ?? 0.0)" hae="\(droneInfo["alt"] as? Double ?? 0.0)" ce="9999999" le="999999"/>
            <detail>
                <contact endpoint="" phone="" callsign="\(id)"/>
                <precisionlocation geopointsrc="gps" altsrc="gps"/>
                <BasicID>
                    <DeviceID>\(id)</DeviceID>
                    <MAC>\(droneInfo["MAC"] as? String ?? droneInfo["mac"] as? String ?? "")</MAC>
                    <Type>\(droneInfo["id_type"] as? String ?? "Unknown")</Type>
                    <UAType>\(droneInfo["ua_type"] as? Int ?? 0)</UAType>
                </BasicID>
                <LocationVector>
                    <Speed>\(droneInfo["speed"] as? Double ?? 0.0)</Speed>
                    <VerticalSpeed>\(droneInfo["vspeed"] as? Double ?? 0.0)</VerticalSpeed>
                    <Altitude>\(droneInfo["alt"] as? Double ?? 0.0)</Altitude>
                    <Height>\(droneInfo["height"] as? Double ?? 0.0)</Height>
                </LocationVector>
                <System>
                    <PilotLocation>
                        <lat>\(droneInfo["pilot_lat"] as? Double ?? 0.0)</lat>
                        <lon>\(droneInfo["pilot_lon"] as? Double ?? 0.0)</lon>
                    </PilotLocation>
                </System>
                <SelfID>
                    <Description>\(droneInfo["description"] as? String ?? "")</Description>
                </SelfID>
                <color argb="-256"/>
                <usericon iconsetpath="34ae1613-9645-4222-a9d2-e5f243dea2865/Military/UAV_quad.png"/>
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

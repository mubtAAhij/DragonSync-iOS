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
        try socket.setRecvTimeout(100) // see if reducing to 100 from 1000 helps get all status messages
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
    
    //MARK: - Message Parsing & Conversion
    
    func convertTelemetryToXML(_ message: String) -> String? {
        guard let data = message.data(using: .utf8) else { return nil }
        
        // Try parsing as array first (typical for BT/OpenDroneID)
        if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            var droneInfo: [String: Any] = [:]
            
            // Process each message in array
            for message in jsonArray {
                
                // Basic ID Processing
                if let basicId = message["Basic ID"] as? [String: Any] {
                    if droneInfo["id"] == nil {
                        if let rawId = basicId["id"] as? String {
                            droneInfo["id"] = rawId.hasPrefix("drone-") ? rawId : "drone-\(rawId)"
                        }
                        droneInfo["id_type"] = basicId["id_type"]
                        droneInfo["ua_type"] = basicId["ua_type"]
                        droneInfo["mac"] = basicId["MAC"]
                        droneInfo["rssi"] = basicId["RSSI"]
                        droneInfo["protocol"] = basicId["protocol_version"]
                    }
                }
                
                // Location Data
                if let location = message["Location/Vector Message"] as? [String: Any] {
                    droneInfo["lat"] = location["latitude"]
                    droneInfo["lon"] = location["longitude"]
                    droneInfo["speed"] = location["speed"]
                    droneInfo["vspeed"] = location["vert_speed"]
                    droneInfo["alt"] = location["geodetic_altitude"]
                    droneInfo["height"] = location["height_agl"]
                    droneInfo["vertical_accuracy"] = location["vertical_accuracy"]
                    droneInfo["horizantal_accuracy"] = location["horizantal_accuracy"]
                    droneInfo["baro_accuracy"] = location["baro_accuracy"]
                    droneInfo["speed_accuracy"] = location["speed_accuracy"]
                    droneInfo["timestamp_accuracy"] = location["timestamp_accuracy"]
                    droneInfo["alt_pressure"] = location["alt_pressure"]
                    droneInfo["baro_acc"] = location["baro_acc"]
                    droneInfo["direction"] = location["direction"]
                    droneInfo["height_type"] = location["height_type"]
                    droneInfo["horiz_acc"] = location["horiz_acc"]
                    droneInfo["speed_acc"] = location["speed_acc"]
                    droneInfo["vert_acc"] = location["vert_acc"]
                    droneInfo["timestamp"] = location["timestamp"]
                    droneInfo["op_status"] = location["op_status"]
                    droneInfo["ew_dir_segment"] = location["ew_dir_segment"]
                    droneInfo["direction"] = location["direction"]
                    droneInfo["speed_multiplier"] = location["speed_multiplier"]
                }
                
                // Auth Message
                if let auth = message["Authentication Message"] as? [String: Any] {
                    droneInfo["auth_type"] = auth["auth_type"]
                    droneInfo["auth_data"] = auth["auth_data"]
                    droneInfo["auth_timestamp"] = auth["timestamp"]
                    droneInfo["auth_page"] = auth["page"]
                    droneInfo["auth_length"] = auth["length"]
                }
                
                // Self ID
                if let selfId = message["Self-ID Message"] as? [String: Any] {
                    droneInfo["text"] = selfId["text"]
                }
                
                // System Message
                if let system = message["System Message"] as? [String: Any] {
                    droneInfo["pilot_lon"] = system["longitude"]
                    droneInfo["pilot_lat"] = system["latitude"]
                    droneInfo["operator_location_type"] = system["operator_location_type"]
                    droneInfo["classification_type"] = system["classification_type"]
                    droneInfo["area_count"] = system["area_count"]
                    droneInfo["area_radius"] = system["area_radius"]
                    droneInfo["area_ceiling"] = system["area_ceiling"]
                    droneInfo["area_floor"] = system["area_floor"]
                    droneInfo["classification"] = system["classification"]
                    droneInfo["operator_alt_geo"] = system["operator_alt_geo"]
                    droneInfo["ua_classification_category_type"] = system["ua_classification_category_type"]
                    droneInfo["ua_classification_category_class"] = system["ua_classification_category_class"]
                    droneInfo["geodetic_altitude"] = system["geodetic_altitude"]
                    droneInfo["timestamp"] = system["timestamp"]
                }
                
                // Operator ID
                if let opId = message["Operator ID Message"] as? [String: Any] {
                    droneInfo["operator_id"] = opId["operator_id"]
                }
                
                // ZMQ Transmission specific data
                if let auxAdvInd = message["AUX_ADV_IND"] as? [String: Any] {
                    if droneInfo["rssi"] == nil {
                        droneInfo["rssi"] = auxAdvInd["rssi"]
                    }
                    droneInfo["channel"] = auxAdvInd["chan"]
                    droneInfo["phy"] = auxAdvInd["phy"]
                    if let aext = message["aext"] as? [String: Any] {
                        if droneInfo["mac"] == nil {
                            droneInfo["mac"] = (aext["AdvA"] as? String)?.components(separatedBy: " ")[0]
                        }
                        droneInfo["adv_mode"] = aext["AdvMode"]
                        if let dataInfo = aext["AdvDataInfo"] as? [String: Any] {
                            droneInfo["did"] = dataInfo["did"]
                            droneInfo["sid"] = dataInfo["sid"]
                        }
                    }
                }
            }
            
            // Build drone type string
            var droneType = "a-f-G-U"
            if let idType = droneInfo["id_type"] as? String {
                if idType == "Serial Number (ANSI/CTA-2063-A)" {
                    droneType += "-S"
                }
            }
            if let pilotLat = droneInfo["pilot_lat"] as? Double,
               let pilotLon = droneInfo["pilot_lon"] as? Double,
               pilotLat != 0 || pilotLon != 0 {
                droneType += "-O"
            }
            droneType += "-F"
            
            let now = ISO8601DateFormatter().string(from: Date())
            let stale = ISO8601DateFormatter().string(from: Date().addingTimeInterval(300))
            
            // Create XML with all available data
            return """
            <event version="2.0" uid="drone-\(droneInfo["id"] as? String ?? UUID().uuidString)" type="\(droneType)" time="\(now)" start="\(now)" stale="\(stale)" how="m-g">
                <point lat="\(droneInfo["lat"] as? Double ?? 0.0)" lon="\(droneInfo["lon"] as? Double ?? 0.0)" hae="\(droneInfo["alt"] as? Double ?? 0.0)" ce="9999999" le="9999999"/>
                <detail>
                    <BasicID>
                        <DeviceID>drone-\((droneInfo["id"] as? String)?.replacingOccurrences(of: "^drone-", with: "", options: .regularExpression) ?? "")</DeviceID>
                        <MAC>\(droneInfo["mac"] as? String ?? "")</MAC>
                        <RSSI>\(droneInfo["rssi"] as? Int ?? 0)</RSSI>
                        <Type>\(droneInfo["id_type"] as? String ?? "Unknown")</Type>
                        <UAType>\(droneInfo["ua_type"] as? String ?? "Helicopter (or Multirotor)")</UAType>
                    </BasicID>
                    <LocationVector>
                        <Speed>\(droneInfo["speed"] as? Double ?? 0.0)</Speed>
                        <VerticalSpeed>\(droneInfo["vspeed"] as? Double ?? 0.0)</VerticalSpeed>
                        <Altitude>\(droneInfo["alt"] as? Double ?? 0.0)</Altitude>
                        <Height>\(droneInfo["height"] as? Double ?? 0.0)</Height>
                        <TimeSpeed>\(droneInfo["timestamp"] as? String ?? "")</TimeSpeed>
                        <Direction>\(droneInfo["direction"] as? Int ?? 0)</Direction>
                        <AltPressure>\(droneInfo["alt_pressure"] as? Double ?? 0.0)</AltPressure>
                        <HeightType>\(droneInfo["height_type"] as? Int ?? 0)</HeightType>
                        <HorizAcc>\(droneInfo["horiz_acc"] as? Double ?? 0.0)</HorizAcc>
                        <VertAcc>\(droneInfo["vert_acc"] as? Double ?? 0.0)</VertAcc>
                        <SpeedAcc>\(droneInfo["speed_acc"] as? Double ?? 0.0)</SpeedAcc>
                        <BaroAcc>\(droneInfo["baro_acc"] as? Double ?? 0.0)</BaroAcc>
                    </LocationVector>
                    <System>
                        <PilotLocation>
                            <lat>\(droneInfo["pilot_lat"] as? Double ?? 0.0)</lat>
                            <lon>\(droneInfo["pilot_lon"] as? Double ?? 0.0)</lon>
                        </PilotLocation>
                        <OperatorAltGeo>\(droneInfo["operator_alt_geo"] as? Double ?? 0.0)</OperatorAltGeo>
                        <AreaCount>\(droneInfo["area_count"] as? Int ?? 0)</AreaCount>
                        <AreaRadius>\(droneInfo["area_radius"] as? Double ?? 0.0)</AreaRadius>
                        <AreaCeiling>\(droneInfo["area_ceiling"] as? Double ?? 0.0)</AreaCeiling>
                        <AreaFloor>\(droneInfo["area_floor"] as? Double ?? 0.0)</AreaFloor>
                        <Classification>\(droneInfo["classification"] as? Int ?? 0)</Classification>
                    </System>
                    <SelfID>
                        <Description>\(droneInfo["description"] as? String ?? "")</Description>
                        <DescriptionType>\(droneInfo["description_type"] as? Int ?? 0)</DescriptionType>
                    </SelfID>
                    <Authentication>
                        <AuthType>\(droneInfo["auth_type"] as? Int ?? 0)</AuthType>
                        <AuthData>\(droneInfo["auth_data"] as? String ?? "")</AuthData>
                        <AuthTimestamp>\(droneInfo["auth_timestamp"] as? String ?? "")</AuthTimestamp>
                        <AuthPage>\(droneInfo["auth_page"] as? Int ?? 0)</AuthPage>
                        <AuthLength>\(droneInfo["auth_length"] as? Int ?? 0)</AuthLength>
                    </Authentication>
                    <TransmissionData>
                        <Channel>\(droneInfo["channel"] as? Int ?? 0)</Channel>
                        <PHY>\(droneInfo["phy"] as? Int ?? 0)</PHY>
                        <AdvMode>\(droneInfo["adv_mode"] as? String ?? "")</AdvMode>
                        <DID>\(droneInfo["did"] as? Int ?? 0)</DID>
                        <SID>\(droneInfo["sid"] as? Int ?? 0)</SID>
                    </TransmissionData>
                    <color argb="-256"/>
                    <usericon iconsetpath="34ae1613-9645-4222-a9d2-e5f243dea2865/Military/UAV_quad.png"/>
                </detail>
            </event>
            """
        }
        
        // Handle single object messages
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // Wrap single message in array and reuse array processing
            return createDroneXML(from: [json])
        }
        
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
    
    private func createDroneXML(from messages: [[String: Any]]) -> String {
        var droneInfo: [String: Any] = [:]
        
        for message in messages {
            // Process Basic ID from any source (keep original field name)
            if let basicId = message["Basic ID"] as? [String: Any] {
                if droneInfo["id"] == nil {
                    let rawId = getFieldValue(basicId, keys: ["id", "serial_number"], defaultValue: UUID().uuidString) as! String
                    droneInfo["id"] = "\(rawId == "NONE" ? UUID().uuidString : rawId)"
                }
                droneInfo["id_type"] = basicId["id_type"]
                droneInfo["ua_type"] = basicId["ua_type"]
                if droneInfo["mac"] == nil {
                    droneInfo["mac"] = basicId["MAC"] ?? basicId["mac"]
                }
                if droneInfo["rssi"] == nil {
                    droneInfo["rssi"] = basicId["RSSI"] ?? basicId["rssi"]
                }
            }
            
            // Get the RSSI and MAC from AUX_ADV_IND if ZMQ
            if let auxAdvInd = message["AUX_ADV_IND"] as? [String: Any] {
                if droneInfo["rssi"] == nil {
                    droneInfo["rssi"] = auxAdvInd["rssi"]
                }
                if let aext = message["aext"] as? [String: Any],
                   let advA = aext["AdvA"] as? String {
                    droneInfo["mac"] = advA.components(separatedBy: " ")[0]
                }
            }
            
            // Process Location data (keep original field name)
            if let location = message["Location/Vector Message"] as? [String: Any] {
                droneInfo["lat"] = location["latitude"] ?? 0.0
                droneInfo["lon"] = location["longitude"] ?? 0.0
                droneInfo["speed"] = location["speed"] ?? 0.0
                droneInfo["vspeed"] = location["vert_speed"] ?? 0.0
                droneInfo["alt"] = location["geodetic_altitude"] ?? 0.0
                droneInfo["height"] = location["height_agl"] ?? 0.0
                // Add additional location fields
                droneInfo["alt_pressure"] = location["alt_pressure"]
                droneInfo["baro_acc"] = location["baro_acc"]
                droneInfo["direction"] = location["direction"]
                droneInfo["height_type"] = location["height_type"]
                droneInfo["horiz_acc"] = location["horiz_acc"]
                droneInfo["speed_acc"] = location["speed_acc"]
                droneInfo["vert_acc"] = location["vert_acc"]
                droneInfo["status"] = location["status"]
                droneInfo["timestamp"] = location["timestamp"]
            }
            
            // Process System data (keep original field name)
            if let system = message["System"] as? [String: Any] {
                droneInfo["pilot_lat"] = system["latitude"]
                droneInfo["pilot_lat"] = system["longitude"]
                droneInfo["area_count"] = system["area_count"]
                droneInfo["area_ceiling"] = system["area_ceiling"]
                droneInfo["area_floor"] = system["area_floor"]
                droneInfo["area_radius"] = system["area_radius"]
                droneInfo["classification"] = system["classification"]
                droneInfo["operator_alt_geo"] = system["operator_alt_geo"]
            }
            
            // Process Self ID (keep original field name)
            if let selfId = message["Self-ID Message"] as? [String: Any] {
                droneInfo["description"] = selfId["text"] ?? ""
                droneInfo["description_type"] = selfId["description_type"]
            } else if let selfId = message["SelfID"] as? [String: Any] {
                droneInfo["description"] = selfId["Description"] ?? ""
            }
            
            // Process Auth Message
            if let auth = message["Auth Message"] as? [String: Any] {
                droneInfo["auth_type"] = auth["type"]
                droneInfo["auth_data"] = auth["data"]
                droneInfo["auth_timestamp"] = auth["timestamp"]
                droneInfo["auth_page"] = auth["page"]
                droneInfo["auth_length"] = auth["length"]
            }
        }
        
        // UAType handling (keep original logic)
        let uaType: String
        if let typeInt = droneInfo["ua_type"] as? Int {
            uaType = String(typeInt)
        } else if let typeStr = droneInfo["ua_type"] as? String {
            uaType = typeStr == "Helicopter (or Multirotor)" ? "2" : "0"
        } else {
            uaType = "2"  // Default to helicopter
        }
        
        return """
        <event version="2.0" uid="drone-\(droneInfo["id"] as? String ?? UUID().uuidString)" type="a-f-G-U-C">
            <point lat="\(droneInfo["lat"] as? Double ?? 0.0)" lon="\(droneInfo["lon"] as? Double ?? 0.0)" hae="\(droneInfo["alt"] as? Double ?? 0.0)" ce="9999999" le="999999"/>
            <detail>
                <BasicID>
                   <DeviceID>drone-\((droneInfo["id"] as? String)?.replacingOccurrences(of: "^drone-", with: "", options: .regularExpression) ?? "")</DeviceID>
                    <MAC>\(droneInfo["mac"] as? String ?? "")</MAC>
                    <RSSI>\(droneInfo["rssi"] as? Int ?? 0)</RSSI>
                    <Type>\(droneInfo["id_type"] as? String ?? "Unknown")</Type>
                    <UAType>\(uaType)</UAType>
                </BasicID>
                <LocationVector>
                    <Speed>\(droneInfo["speed"] as? Double ?? 0.0)</Speed>
                    <VerticalSpeed>\(droneInfo["vspeed"] as? Double ?? 0.0)</VerticalSpeed>
                    <Altitude>\(droneInfo["alt"] as? Double ?? 0.0)</Altitude>
                    <Height>\(droneInfo["height"] as? Double ?? 0.0)</Height>
                    <AltPressure>\(droneInfo["alt_pressure"] as? Double ?? -1000.0)</AltPressure>
                    <BaroAcc>\(droneInfo["baro_acc"] as? Double ?? 0.0)</BaroAcc>
                    <Direction>\(droneInfo["direction"] as? Int ?? 361)</Direction>
                    <HeightType>\(droneInfo["height_type"] as? Int ?? 0)</HeightType>
                    <HorizAcc>\(droneInfo["horiz_acc"] as? Double ?? 0.0)</HorizAcc>
                    <SpeedAcc>\(droneInfo["speed_acc"] as? Double ?? 0.0)</SpeedAcc>
                    <VertAcc>\(droneInfo["vert_acc"] as? Double ?? 0.0)</VertAcc>
                    <Status>\(droneInfo["status"] as? Int ?? 0)</Status>
                    <TimeSpeed>\(droneInfo["timestamp"] as? Int ?? 0)</TimeSpeed>
                </LocationVector>
                <System>
                    <PilotLocation>
                        <lat>\(droneInfo["pilot_lat"] as? Double ?? 0.0)</lat>
                        <lon>\(droneInfo["pilot_lon"] as? Double ?? 0.0)</lon>
                    </PilotLocation>
                    <AreaCount>\(droneInfo["area_count"] as? Int ?? 1)</AreaCount>
                    <AreaCeiling>\(droneInfo["area_ceiling"] as? Double ?? -1000.0)</AreaCeiling>
                    <AreaFloor>\(droneInfo["area_floor"] as? Double ?? -1000.0)</AreaFloor>
                    <AreaRadius>\(droneInfo["area_radius"] as? Double ?? 0.0)</AreaRadius>
                    <Classification>\(droneInfo["classification"] as? Int ?? 0)</Classification>
                    <OperatorAltGeo>\(droneInfo["operator_alt_geo"] as? Double ?? -1000.0)</OperatorAltGeo>
                </System>
                <SelfID>
                    <Description>\(droneInfo["description"] as? String ?? "")</Description>
                    <DescriptionType>\(droneInfo["description_type"] as? Int ?? 0)</DescriptionType>
                </SelfID>
                <Authentication>
                    <AuthType>\(droneInfo["auth_type"] as? Int ?? 0)</AuthType>
                    <AuthData>\(droneInfo["auth_data"] as? String ?? "")</AuthData>
                    <AuthTimestamp>\(droneInfo["auth_timestamp"] as? Int ?? 0)</AuthTimestamp>
                    <AuthPage>\(droneInfo["auth_page"] as? Int ?? 0)</AuthPage>
                    <AuthLength>\(droneInfo["auth_length"] as? Int ?? 0)</AuthLength>
                </Authentication>
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

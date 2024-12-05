//
//  ZMQMessageProcessor.swift
//  WarDragon
//
//  Created by Luke on 12/4/24.
//

import Foundation

class ZMQMessageProcessor {
    private let parser = MessageParser()
    
    enum MessageFormat {
        case bt45
        case esp32
        case wifi
        case status
        case unknown
    }
    
    
    func processTelemetryMessage(_ message: String) -> String? {
        guard let data = message.data(using: .utf8) else { return nil }
        
        do {
            // Handle JSON
            if message.trimmingCharacters(in: .whitespacesAndNewlines).starts(with: "{"),
               let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                
                switch detectFormat(json) {
                case .bt45:
                    return processBT45Message(message)
                case .esp32:
                    return processESP32Message(message)
                case .wifi:
                    return processWiFiMessage(message)
                case .status:
                    return processStatusMessage(message)
                case .unknown:
                    print("Unknown message format")
                    return nil
                }
            }
            // Handle XML/CoT format
            else if message.trimmingCharacters(in: .whitespacesAndNewlines).starts(with: "<") {
                return message // Already in CoT format
            }
            
            return nil
        } catch {
            print("Message Processing Error: \(error)")
            return nil
        }
    }
    
    func processStatusMessage(_ message: String) -> String? {
        return parser.parseStatusMessage(message)
    }
    
    private func detectFormat(_ json: [String: Any]) -> MessageFormat {
        if json["AUX_ADV_IND"] != nil {
            return .bt45
        }
        if json["Basic ID"] != nil {
            return .esp32
        }
        if json["DroneID"] != nil {
            return .wifi
        }
        if json["system_stats"] != nil {
            return .status
        }
        return .unknown
    }
    
    private func processBT45Message(_ message: String) -> String? {
        return parser.parseBT45Message(message)
    }
    
    private func processESP32Message(_ message: String) -> String? {
        return parser.parseESP32Message(message)
    }
    
    private func processWiFiMessage(_ message: String) -> String? {
        return parser.parseWiFiMessage(message)
    }
}

//MARK - Message Parsing

class MessageParser {
    private let signatureGenerator = DroneSignatureGenerator()
    private var lastSignatures: [String: DroneSignature] = [:]
    
    private func parseRuntimeInfo(_ data: [String: Any]) -> (Int, Int)? {
        guard let runtime = data["runtime"] as? Int,
              let index = data["index"] as? Int else {
            return nil
        }
        return (runtime, index)
    }
    
    // Enhanced message validation
    private func validateMessageData(_ data: [String: Any]) -> Bool {
        // Check for valid coordinate data
        if let location = data["Location/Vector Message"] as? [String: Any] {
            let lat = location["latitude"] as? Double ?? 0
            let lon = location["longitude"] as? Double ?? 0
            return lat != 0 && lon != 0
        }
        return false
    }
    
    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
    
    func parseStatusMessage(_ message: String) -> String? {
        if message.contains("type=\"b-m-p-s-m\"") {
            return message
        }
        
        guard let data = message.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        return createStatusCoT(from: json)
    }
    
    private func parseBasicIDMessage(_ data: Data) -> [String: Any]? {
        guard data.count >= 20 else { return nil }
        
        let idTypes = ["None", "Serial Number (ANSI/CTA-2063-A)", "CAA Registration ID", "UTM (USS) Assigned ID"]
        let uaTypes = ["None", "Aeroplane", "Helicopter/Multirotor", "Gyroplane", "Hybrid Lift",
                       "Ornithopter", "Glider", "Kite", "Free Balloon", "Captive Balloon", "Airship",
                       "Free Fall/Parachute", "Rocket", "Tethered Powered Aircraft", "Ground Obstacle", "Other"]
        
        let idType = Int(data[0] & 0xF)
        let uaType = Int(data[0] >> 4)
        
        // Extract ID string (remove trailing nulls)
        let id = String(bytes: data.suffix(from: 1).prefix(while: { $0 != 0 }), encoding: .utf8) ?? ""
        
        return [
            "id_type": idTypes[min(idType, idTypes.count - 1)],
            "ua_type": uaTypes[min(uaType, uaTypes.count - 1)],
            "id": id
        ]
    }
    
    private func parseLocationMessage(_ data: Data) -> [String: Any]? {
        guard data.count >= 16 else { return nil }
        
        let status = data[0]
        let flags = data[1]
        
        // Extract encoded values
        let latitude = Double(Int32(bigEndian: data.subdata(in: 2..<6).withUnsafeBytes { $0.load(as: Int32.self) })) / 1e7
        let longitude = Double(Int32(bigEndian: data.subdata(in: 6..<10).withUnsafeBytes { $0.load(as: Int32.self) })) / 1e7
        let altitude = Double(Int16(bigEndian: data.subdata(in: 10..<12).withUnsafeBytes { $0.load(as: Int16.self) })) / 1e1
        let heightAGL = Double(Int16(bigEndian: data.subdata(in: 12..<14).withUnsafeBytes { $0.load(as: Int16.self) })) / 1e1
        let speed = Double(Int16(bigEndian: data.subdata(in: 14..<16).withUnsafeBytes { $0.load(as: Int16.self) })) / 1e2
        
        return [
            "status": status,
            "flags": flags,
            "latitude": latitude,
            "longitude": longitude,
            "geodetic_altitude": altitude,
            "height_agl": heightAGL,
            "speed": speed
        ]
    }
    
    private func parseAuthenticationMessage(_ data: Data) -> [String: Any]? {
        guard data.count >= 17 else { return nil }
        
        let authType = data[0]
        let timestamp = UInt32(bigEndian: data.subdata(in: 1..<5).withUnsafeBytes { $0.load(as: UInt32.self) })
        let authData = data.suffix(from: 5)
        
        return [
            "auth_type": authType,
            "timestamp": timestamp,
            "auth_data": authData.base64EncodedString()
        ]
    }
    
    private func parseSelfIDMessage(_ data: Data) -> [String: Any]? {
        guard data.count >= 1 else { return nil }
        
        let descriptionType = data[0]
        let text = String(bytes: data.suffix(from: 1), encoding: .utf8) ?? ""
        
        return [
            "description_type": descriptionType,
            "text": text
        ]
    }
    
    private func parseSystemMessage(_ data: Data) -> [String: Any]? {
        guard data.count >= 18 else { return nil }
        
        let flags = data[0]
        let operatorLatitude = Double(Int32(bigEndian: data.subdata(in: 1..<5).withUnsafeBytes { $0.load(as: Int32.self) })) / 1e7
        let operatorLongitude = Double(Int32(bigEndian: data.subdata(in: 5..<9).withUnsafeBytes { $0.load(as: Int32.self) })) / 1e7
        let areaCount = data[9]
        let areaRadius = data[10]
        let areaCeiling = Double(Int16(bigEndian: data.subdata(in: 11..<13).withUnsafeBytes { $0.load(as: Int16.self) })) / 1e1
        let areaFloor = Double(Int16(bigEndian: data.subdata(in: 13..<15).withUnsafeBytes { $0.load(as: Int16.self) })) / 1e1
        
        return [
            "flags": flags,
            "latitude": operatorLatitude,
            "longitude": operatorLongitude,
            "area_count": areaCount,
            "area_radius": areaRadius,
            "area_ceiling": areaCeiling,
            "area_floor": areaFloor
        ]
    }
    
    private func parseOperatorIDMessage(_ data: Data) -> [String: Any]? {
        guard data.count >= 1 else { return nil }
        
        let operatorIdType = data[0]
        let operatorId = String(bytes: data.suffix(from: 1), encoding: .utf8) ?? ""
        
        return [
            "operator_id_type": operatorIdType,
            "operator_id": operatorId
        ]
    }
    
    private func parseOpenDroneIDPayload(_ payload: Data) -> [String: Any]? {
        var result: [String: Any] = [:]
        var currentIndex = payload.startIndex
        
        while currentIndex < payload.endIndex {
            guard currentIndex + 2 < payload.endIndex else { break }
            
            let messageType = payload[currentIndex]
            let length = Int(payload[currentIndex + 1])
            
            guard currentIndex + 2 + length <= payload.endIndex else { break }
            
            let messageData = payload.subdata(in: (currentIndex + 2)..<(currentIndex + 2 + length))
            
            switch messageType {
            case 0x0: // Basic ID
                if let basicId = parseBasicIDMessage(messageData) {
                    result["Basic ID"] = basicId
                }
            case 0x1: // Location
                if let location = parseLocationMessage(messageData) {
                    result["Location/Vector Message"] = location
                }
            case 0x2: // Authentication
                if let auth = parseAuthenticationMessage(messageData) {
                    result["Authentication"] = auth
                }
            case 0x3: // Self ID
                if let selfId = parseSelfIDMessage(messageData) {
                    result["Self-ID Message"] = selfId
                }
            case 0x4: // System
                if let system = parseSystemMessage(messageData) {
                    result["System Message"] = system
                }
            case 0x5: // Operator ID
                if let operatorId = parseOperatorIDMessage(messageData) {
                    result["Operator ID"] = operatorId
                }
            default:
                break
            }
            
            currentIndex += 2 + length
        }
        
        return result.isEmpty ? nil : result
    }
    
    func parseBT45Message(_ message: String) -> String? {
        guard let data = message.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let advInfo = json["AUX_ADV_IND"] as? [String: Any],
              let advData = json["AdvData"] as? String,
              advInfo["aa"] as? Int == 0x8e89bed6 else {
            return nil
        }
        
        let signature = signatureGenerator.createSignature(from: json)
        
        var bestMatchId: String?
        var bestMatchScore = 0.0
        
        for (id, existingSignature) in lastSignatures {
            let score = signatureGenerator.matchSignatures(signature, existingSignature)
            if score > bestMatchScore && score > 0.7 {
                bestMatchScore = score
                bestMatchId = id
            }
        }
        
        let droneId = bestMatchId ?? "drone-\(UUID().uuidString)"
        lastSignatures[droneId] = signature // Update signature cache
        
        return createDroneCoT(droneId: droneId, json: json)
    }
    
    func parseESP32Message(_ message: String) -> String? {
           guard let data = message.data(using: .utf8),
                 let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
               return nil
           }

           // Generate signature even for messages with no ID/"NONE" ID
           let signature = signatureGenerator.createSignature(from: json)
           
           // Try to match with existing signatures
           var bestMatchId: String?
           var bestMatchScore = 0.0
           
           for (id, existingSignature) in lastSignatures {
               let score = signatureGenerator.matchSignatures(signature, existingSignature)
               if score > bestMatchScore && score > 0.7 { // Threshold for match
                   bestMatchScore = score
                   bestMatchId = id
               }
           }

           // Use matched ID or generate new one
           let droneId = bestMatchId ?? "drone-\(UUID().uuidString)"
           lastSignatures[droneId] = signature // Update signature cache
           
           return createDroneCoT(droneId: droneId, json: json)
       }
    
    func parseWiFiMessage(_ message: String) -> String? {
        guard let data = message.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let droneId = json["DroneID"] as? [String: Any] else {
            return nil
        }
        
        for (mac, field) in droneId {
            guard let fieldData = field as? [String: Any] else { continue }
            
            let id = "WIFI-\(mac)"
            
            // For WiFi messages with AdvData - parse raw OpenDroneID payload
            if let advData = fieldData["AdvData"] as? String,
               let decodedData = Data(hexString: advData),
               let parsedJson = parseOpenDroneIDPayload(decodedData) {
                return createDroneCoT(droneId: id, json: parsedJson)
            }
            
            // For WiFi messages with direct fields - use as is
            if fieldData["Location/Vector Message"] != nil {
                return createDroneCoT(droneId: id, json: fieldData)
            }
        }
        
        return nil
    }
    
    private func createStatusCoT(from json: [String: Any]) -> String {
        let timestamp = dateFormatter.string(from: Date())
        let serialNumber = json["serial_number"] as? String ?? UUID().uuidString
        let gpsData = json["gps_data"] as? [String: Any] ?? [:]
        let stats = json["system_stats"] as? [String: Any] ?? [:]
        let memory = stats["memory"] as? [String: Any] ?? [:]
        let disk = stats["disk"] as? [String: Any] ?? [:]
        
        let lat = gpsData["latitude"] as? Double ?? 0.0
        let lon = gpsData["longitude"] as? Double ?? 0.0
        let alt = gpsData["altitude"] as? Double ?? 0.0
        let speed = gpsData["speed"] as? Double ?? 0.0
        
        let cpuUsage = stats["cpu_usage"] as? Double ?? 0.0
        let temperature = stats["temperature"] as? Double ?? 0.0
        let uptime = stats["uptime"] as? Double ?? 0.0
        
        let memTotal = Int64((memory["total"] as? Double ?? 0.0) / (1024 * 1024))
        let memAvail = Int64((memory["available"] as? Double ?? 0.0) / (1024 * 1024))
        let diskTotal = Int64((disk["total"] as? Double ?? 0.0) / (1024 * 1024))
        let diskUsed = Int64((disk["used"] as? Double ?? 0.0) / (1024 * 1024))
        
        return """
        <event version="2.0" uid="\(serialNumber)" type="b-m-p-s-m" time="\(timestamp)" start="\(timestamp)" stale="\(timestamp)" how="m-g">
            <point lat="\(lat)" lon="\(lon)" hae="\(alt)" ce="9999999" le="9999999"/>
            <detail>
                <contact callsign="\(serialNumber)"/>
                <precisionlocation altsrc="GPS"/>
                <status readiness="true"/>
                <takv platform="WarDragon" version="1.0"/>
                <track speed="\(speed)"/>
                <remarks>CPU Usage: \(cpuUsage)%, Memory Total: \(memTotal) MB, Memory Available: \(memAvail) MB, Disk Total: \(diskTotal) MB, Disk Used: \(diskUsed) MB, Temperature: \(temperature)°C, Uptime: \(Int(uptime)) seconds</remarks>
            </detail>
        </event>
        """
    }
    
    private func createDroneCoT(droneId: String, json: [String: Any]) -> String {
        let timestamp = dateFormatter.string(from: Date())
        let location = json["Location/Vector Message"] as? [String: Any] ?? [:]
        let basicId = json["Basic ID"] as? [String: Any] ?? [:]
        
        var droneType = "a-f-G-U"
        if let idType = basicId["id_type"] as? String {
            switch idType {
            case "Serial Number (ANSI/CTA-2063-A)": droneType += "-S-F"
            case "CAA Registration ID": droneType += "-R-F"
            case "UTM (USS) Assigned ID": droneType += "-U-F"
            default: droneType += "-U-F"
            }
        }
        
        if let system = json["System Message"] as? [String: Any],
           let pilotLat = system["latitude"] as? Double,
           let pilotLon = system["longitude"] as? Double,
           pilotLat != 0.0, pilotLon != 0.0 {
            droneType += "-O"
        }
        
        let lat = location["latitude"] as? Double ?? 0.0
        let lon = location["longitude"] as? Double ?? 0.0
        let alt = location["geodetic_altitude"] as? Double ?? 0.0
        let height = location["height_agl"] as? Double ?? 0.0
        let speed = location["speed"] as? Double ?? 0.0
        let vspeed = location["vert_speed"] as? Double ?? 0.0
        
        let selfId = json["Self-ID Message"] as? [String: Any] ?? [:]
        let description = selfId["text"] as? String ?? ""
        
        let pilotLocationTag = if let system = json["System Message"] as? [String: Any],
                                  let pilotLat = system["latitude"] as? Double,
                                  let pilotLon = system["longitude"] as? Double,
                                  pilotLat != 0.0, pilotLon != 0.0 {
            """
            <pilot_location>
                <lat>\(pilotLat)</lat>
                <lon>\(pilotLon)</lon>
            </pilot_location>
            """
        } else { "" }
        
        return """
        <event version="2.0" uid="\(droneId)" type="\(droneType)" time="\(timestamp)" start="\(timestamp)" stale="\(timestamp)" how="m-g">
            <point lat="\(lat)" lon="\(lon)" hae="\(alt)" ce="9999999" le="9999999"/>
            <detail>
                <track speed="\(speed)" course="0"/>
                <contact callsign="\(description.isEmpty ? droneId : description)"/>
                <precisionlocation altsrc="GPS"/>
                <DroneMetadata>
                    <height>\(height)</height>
                    <vspeed>\(vspeed)</vspeed>
                    \(pilotLocationTag)
                </DroneMetadata>
            </detail>
        </event>
        """
    }
}

extension Data {
    init?(hexString: String) {
        let len = hexString.count / 2
        var data = Data(capacity: len)
        var i = hexString.startIndex
        for _ in 0..<len {
            let j = hexString.index(i, offsetBy: 2)
            let bytes = hexString[i..<j]
            if var num = UInt8(bytes, radix: 16) {
                data.append(&num, count: 1)
            } else {
                return nil
            }
            i = j
        }
        self = data
    }
}

//
//  ZMQMessageProcessor.swift
//  WarDragon
//
//  Created by Luke on 12/4/24.
//

import Foundation

class ZMQMessageProcessor {
    private let signatureGenerator = DroneSignatureGenerator()
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
            // Handle JSON formats
            if message.trimmingCharacters(in: .whitespacesAndNewlines).starts(with: "{"),
               let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                
                switch detectFormat(json) {
                case .bt45:
                    return processBT45Message(message) // Pass original message
                case .esp32:
                    return processESP32Message(message) // Pass original message
                case .wifi:
                    return processWiFiMessage(message) // Pass original message
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
    
    // Modified to use parser helper class
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

// Helper class for message parsing
class MessageParser {
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
    
    
    func parseBT45Message(_ message: String) -> String? {
        // Add BT4/5 specific parsing
        return nil
    }
    
    func parseESP32Message(_ message: String) -> String? {
        guard let data = message.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let basicId = json["Basic ID"] as? [String: Any],
              let location = json["Location/Vector Message"] as? [String: Any],
              let latitude = location["latitude"] as? Double,
              let longitude = location["longitude"] as? Double else {
            return nil
        }
        
        // Validate location data
        if latitude == 0.0 && longitude == 0.0 {
            return nil  // Skip invalid locations
        }
        
        let droneId = "drone-\(basicId["id"] as? String ?? UUID().uuidString)"
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
            
            // For WiFi messages with AdvData
            if let advData = fieldData["AdvData"] as? String,
               let decodedData = Data(hexString: advData) {
                let id = "WIFI-\(mac)"
                return createDroneCoT(droneId: id, json: fieldData)
            }
            
            // For WiFi messages with direct fields
            if let location = fieldData["Location/Vector Message"] as? [String: Any] {
                let id = "WIFI-\(mac)"
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

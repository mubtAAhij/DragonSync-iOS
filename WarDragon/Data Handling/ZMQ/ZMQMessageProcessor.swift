//
//  ZMQMessageProcessor.swift
//  WarDragon
//
//  Created by Luke on 12/6/24.
//

import Foundation

// MARK: - ZMQ Message Processor
final class ZMQMessageProcessor {
    // MARK: - Properties
    private let signatureGenerator = DroneSignatureGenerator()
    
    // MARK: - Message Processing
    func processTelemetryMessage(_ message: String) -> String? {
        guard let data = message.data(using: .utf8) else { return nil }
        
        // Handle JSON messages
        if message.trimmingCharacters(in: .whitespacesAndNewlines).starts(with: "{"),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            
            // Check for BT4/5 messages
            if let advInfo = json["AUX_ADV_IND"] as? [String: Any] {
                return processBT45Message(json, advInfo)
            }
            
            // Check for WiFi messages
            if let droneId = json["DroneID"] as? [String: Any] {
                return processWiFiMessage(json, droneId)
            }
            
            // ESP32 Message check by looking for protocol_version
            if let basicID = json["Basic ID"] as? [String: Any],
               basicID["protocol_version"] == nil,
               let _ = json["Location/Vector Message"] {
                return processESP32Message(json)
            }
            
            // Regular Message (rich structure)
            if let _ = json["Basic ID"],
               let _ = json["Location/Vector Message"] {
                return processRegularMessage(json)
            }
            
            // Unrecognized message format
            print("⚠️ Unrecognized telemetry message format: \(message)")
            return nil
        }
        return nil
    }
    
    
    private func processRegularMessage(_ json: [String: Any]) -> String? {
        guard json["Basic ID"] != nil,  // Check existence of "Basic ID"
              let id = (json["Basic ID"] as? [String: Any])?["id"] as? String,
              let location = json["Location/Vector Message"] as? [String: Any],
              let _ = location["latitude"] as? Double,
              let _ = location["longitude"] as? Double else {
            return nil
        }
        
        // Create a unique drone ID for regular messages
        let droneId: String = "REGULAR-\(id)"
        
        let signature = signatureGenerator.createSignature(from: json)
        return createCoTMessage(signature: signature, droneId: droneId)
    }
    
    func processStatusMessage(_ message: String) -> String? {
        if message.contains("type=\"b-m-p-s-m\"") && message.contains("<remarks>CPU Usage:") {
            return message // Already in correct XML format
        }
        return nil
    }
    
    // MARK: - Private Message Handlers
    private func processBT45Message(_ json: [String: Any], _ advInfo: [String: Any]) -> String? {
        guard let advData = json["AdvData"] as? String,
              let decodedData = Data(hexString: advData),
              advInfo["aa"] as? Int == 0x8e89bed6,
              decodedData.count > 5,
              decodedData[1] == 0x16,
              Int(decodedData[2]) | (Int(decodedData[3]) << 8) == 0xFFFA,
              decodedData[4] == 0x0D else {
            return nil
        }
        
        let droneId: String
        if let btAddr = json["btAddr"] as? String, !btAddr.isEmpty {
            droneId = "BT-\(btAddr)"
        } else if let addr = advInfo["addr"] as? String, !addr.isEmpty {
            droneId = "BT-\(addr)"
        } else {
            droneId = "BT-\(generateFingerprint(from: json))"
        }
        
        let signature = signatureGenerator.createSignature(from: json)
        return createCoTMessage(signature: signature, droneId: droneId)
    }
    
    private func processWiFiMessage(_ json: [String: Any], _ droneId: [String: Any]) -> String? {
        for (mac, field) in droneId {
            guard let fieldData = field as? [String: Any] else { continue }
            
            let droneId: String
            if let fieldMac = fieldData["MAC"] as? String, !fieldMac.isEmpty {
                droneId = "WIFI-\(fieldMac)"
            } else if !mac.isEmpty {
                droneId = "WIFI-\(mac)"
            } else {
                droneId = "WIFI-\(generateFingerprint(from: fieldData))"
            }
            
            if fieldData["Location/Vector Message"] is [String: Any] {
                let signature = signatureGenerator.createSignature(from: ["DroneID": [mac: fieldData]])
                return createCoTMessage(signature: signature, droneId: droneId)
            }
        }
        return nil
    }
    
    
    private func processESP32Message(_ json: [String: Any]) -> String? {
        guard let basicId = json["Basic ID"] as? [String: Any],
              let id = basicId["id"] as? String,
              let location = json["Location/Vector Message"] as? [String: Any],
              let lat = location["latitude"] as? Double,
              let lon = location["longitude"] as? Double else {
            return nil
        }
        
        // Skip invalid locations
        if lat == 0.0 && lon == 0.0 {
            return nil
        }
        
        let droneId: String
        if id != "NONE" && !id.isEmpty {
            droneId = "ESP32-\(id)"
        } else if let hwId = basicId["hw_id"] as? String, !hwId.isEmpty {
            droneId = hwId  // hw_id already includes ESP32- prefix
        } else {
            droneId = "ESP32-\(generateFingerprint(from: json))"
        }
        
        let signature = signatureGenerator.createSignature(from: json)
        return createCoTMessage(signature: signature, droneId: droneId)
    }
    
    // MARK: - Helper Methods
    private func generateFingerprint(from data: [String: Any]) -> String {
        var hasher = Hasher()
        hasher.combine(data.description)
        return String(format: "%08x", abs(hasher.finalize()))
    }
    
    private func createCoTMessage(signature: DroneSignature, droneId: String) -> String {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        var droneType = "a-f-G-U"
        if signature.position.operatorLocation != nil {
            droneType += "-O"
        }
        droneType += "-F"
        
        let pilotLocation = if let opLoc = signature.position.operatorLocation {
            """
            <DroneMetadata>
                <PilotLocation>
                    <lat>\(opLoc.latitude)</lat>
                    <lon>\(opLoc.longitude)</lon>
                </PilotLocation>
                <Speed>\(signature.movement.groundSpeed)</Speed>
                <VerticalSpeed>\(signature.movement.verticalSpeed)</VerticalSpeed>
                <Height>\(signature.heightInfo.heightAboveGround)</Height>
            </DroneMetadata>
            """
        } else { "" }
        
        return """
        <event version="2.0" uid="\(droneId)" type="\(droneType)" time="\(timestamp)" start="\(timestamp)" stale="\(timestamp)" how="m-g">
            <point lat="\(signature.position.coordinate.latitude)" lon="\(signature.position.coordinate.longitude)" hae="\(signature.position.altitude)" ce="9999999" le="9999999"/>
            <detail>
                <contact callsign="\(signature.operatorId ?? droneId)"/>
                <precisionlocation altsrc="GPS"/>
                \(pilotLocation)
            </detail>
        </event>
        """
    }
}

// MARK: - Data Extension
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

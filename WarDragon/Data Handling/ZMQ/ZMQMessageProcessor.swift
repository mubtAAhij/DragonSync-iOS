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
        guard let data = message.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let _ = json["Basic ID"],
              let location = json["Location/Vector Message"] as? [String: Any],
              let _ = location["latitude"] as? Double,
              let _ = location["longitude"] as? Double else {
            return nil
        }

        let signature = signatureGenerator.createSignature(from: json)
        return createCoTMessage(signature: signature, droneId: signature.primaryId.id)
    }
    
    func processStatusMessage(_ message: String) -> String? {
        if message.contains("type=\"b-m-p-s-m\"") && message.contains("<remarks>CPU Usage:") {
            return message // Already in correct XML format
        }
        return nil
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

//
//  XMLParserDelegate.swift
//  WarDragon
//
//  Created by Luke on 11/18/24.
//

import Foundation

class CoTMessageParser: NSObject, XMLParserDelegate {
    // MARK: - Properties
    private var rawMessage: [String: Any]?
    private var currentElement = ""
    private var parentElement = ""
    private var elementStack: [String] = []
    private var eventAttributes: [String: String] = [:]
    private var pointAttributes: [String: String] = [:]
    private var speed = "0.0"
    private var vspeed = "0.0"
    private var alt = "0.0"
    private var height = "0.0"
    private var pilotLat = "0.0"
    private var pilotLon = "0.0"
    private var droneDescription = ""
    private var currentValue = ""
    private var messageContent = ""
    private var remarks = ""
    private var cpuUsage: Double = 0.0
    private var bleData: [String: Any]?
    private var auxAdvInd: [String: Any]?
    private var adType: [String: Any]?
    private var aext: [String: Any]?
    
    private var memoryTotal: Double = 0.0
    private var memoryAvailable: Double = 0.0
    private var memoryUsed: Double = 0.0
    private var memoryFree: Double = 0.0
    private var memoryActive: Double = 0.0
    private var memoryInactive: Double = 0.0
    private var memoryPercent: Double = 0.0
    private var memoryBuffers: Double = 0.0
    private var memoryShared: Double = 0.0
    private var memorySlab: Double = 0.0
    private var memoryCached: Double = 0.0
    
    private var diskTotal: Double = 0.0
    private var diskUsed: Double = 0.0
    private var diskPercent: Double = 0.0
    private var diskFree: Double = 0.0
    
    private var temperature: Double = 0.0
    private var uptime: Double = 0.0
    
    var cotMessage: CoTViewModel.CoTMessage?
    var statusMessage: StatusViewModel.StatusMessage?
    private var isStatusMessage = false
    
    // MARK: - XMLParserDelegate
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String : String] = [:]) {
        currentElement = elementName
        currentValue = ""
        messageContent = ""
        
        elementStack.append(elementName)
        
        if elementName == "event" {
            eventAttributes = attributes
            remarks = ""
        } else if elementName == "point" {
            pointAttributes = attributes
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if currentElement == "message" {
            messageContent += string
        } else if currentElement == "remarks" {
            remarks += string
        } else {
            currentValue += string.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        let parent = elementStack.dropLast().last ?? ""
        
        if elementName == "remarks" {
            isStatusMessage = remarks.contains("CPU Usage:")
        }
        
        // Route to appropriate handler based on message type
        if isStatusMessage {
            handleStatusMessage(elementName)
        } else {
            handleDroneMessage(elementName, parent)
        }
        
        // Clean up the element stack
        elementStack.removeLast()
    }
    
    
    // MARK: - Status Message Handler
    private func handleStatusMessage(_ elementName: String) {
        switch elementName {
        case "remarks":
            parseRemarks(remarks)
        case "event":
            let uid = eventAttributes["uid"] ?? "unknown"
            let serialNumber = eventAttributes["uid"] ?? "unknown"
            let lat = Double(pointAttributes["lat"] ?? "0.0") ?? 0.0
            let lon = Double(pointAttributes["lon"] ?? "0.0") ?? 0.0
            let altitude = Double(pointAttributes["hae"] ?? "0.0") ?? 0.0
            
            statusMessage = StatusViewModel.StatusMessage(
                uid: uid,
                serialNumber: serialNumber,
                timestamp: uptime,
                gpsData: .init(
                    latitude: lat,
                    longitude: lon,
                    altitude: altitude,
                    speed: 0.0
                ),
                systemStats: .init(
                    cpuUsage: cpuUsage,
                    memory: .init(
                        total: Int64(memoryTotal * 1024 * 1024),
                        available: Int64(memoryAvailable * 1024 * 1024),
                        percent: memoryPercent,
                        used: Int64(memoryUsed * 1024 * 1024),
                        free: Int64(memoryFree * 1024 * 1024),
                        active: Int64(memoryActive * 0.6 * 1024 * 1024),
                        inactive: Int64(memoryInactive * 0.4 * 1024 * 1024),
                        buffers: Int64(memoryBuffers * 0.1 * 1024 * 1024),
                        cached: Int64(memoryCached * 0.3 * 1024 * 1024),
                        shared: Int64(memoryShared * 0.2 * 1024 * 1024),
                        slab: Int64(memorySlab * 0.1 * 1024 * 1024)
                    ),
                    disk: .init(
                        total: Int64(diskTotal * 1024 * 1024),
                        used: Int64(diskUsed * 1024 * 1024),
                        free: Int64((diskTotal - diskUsed) * 1024 * 1024),
                        percent: diskPercent
                    ),
                    temperature: temperature,
                    uptime: uptime
                )
            )
        default:
            break
        }
    }
    
    private func parseDroneRemarks(_ remarks: String) -> (String?, Int?, String?) {
        var mac: String?
        var rssi: Int?
        var description: String?
        
        let components = remarks.components(separatedBy: ", ")
        for component in components {
            let trimmed = component.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("MAC:") {
                mac = trimmed.replacingOccurrences(of: "MAC: ", with: "")
            } else if trimmed.hasPrefix("RSSI:") {
                let rssiString = trimmed.replacingOccurrences(of: "RSSI: ", with: "")
                                      .replacingOccurrences(of: "dBm", with: "")
                rssi = Int(rssiString)
            } else if trimmed.hasPrefix("Self-ID:") {
                description = trimmed.replacingOccurrences(of: "Self-ID: ", with: "")
            }
        }
        
        return (mac, rssi, description)
    }
    
    private func parseRemarks(_ remarks: String) {
        let components = remarks.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        for component in components {
//            print("Processing component: \(component)")
            if component.hasPrefix("CPU Usage:") {
                cpuUsage = Double(component.replacingOccurrences(of: "CPU Usage: ", with: "").replacingOccurrences(of: "%", with: "")) ?? 0.0
            } else if component.hasPrefix("Memory Total:") {
                memoryTotal = Double(component.replacingOccurrences(of: "Memory Total: ", with: "").replacingOccurrences(of: " MB", with: "")) ?? 0.0
            } else if component.hasPrefix("Memory Available:") {
                memoryAvailable = Double(component.replacingOccurrences(of: "Memory Available: ", with: "").replacingOccurrences(of: " MB", with: "")) ?? 0.0
            } else if component.hasPrefix("Disk Total:") {
                diskTotal = Double(component.replacingOccurrences(of: "Disk Total: ", with: "").replacingOccurrences(of: " MB", with: "")) ?? 0.0
            } else if component.hasPrefix("Disk Used:") {
                diskUsed = Double(component.replacingOccurrences(of: "Disk Used: ", with: "").replacingOccurrences(of: " MB", with: "")) ?? 0.0
            } else if component.hasPrefix("Temperature:") {
                temperature = Double(component.replacingOccurrences(of: "Temperature: ", with: "").replacingOccurrences(of: "°C", with: "")) ?? 0.0
            } else if component.hasPrefix("Uptime:") {
                uptime = Double(component.replacingOccurrences(of: "Uptime: ", with: "").replacingOccurrences(of: " seconds", with: "")) ?? 0.0
            } else if component.hasPrefix("Memory Used:") {
                memoryUsed = Double(component.replacingOccurrences(of: "Memory Used: ", with: "").replacingOccurrences(of: " MB", with: "")) ?? 0.0
            } else if component.hasPrefix("Memory Free:") {
                memoryFree = Double(component.replacingOccurrences(of: "Memory Free: ", with: "").replacingOccurrences(of: " MB", with: "")) ?? 0.0
            } else if component.hasPrefix("Memory Active:") {
                memoryActive = Double(component.replacingOccurrences(of: "Memory Active: ", with: "").replacingOccurrences(of: " MB", with: "")) ?? 0.0
            } else if component.hasPrefix("Memory Inactive:") {
                memoryInactive = Double(component.replacingOccurrences(of: "Memory Inactive: ", with: "").replacingOccurrences(of: " MB", with: "")) ?? 0.0
            } else if component.hasPrefix("Memory Buffers:") {
                memoryBuffers = Double(component.replacingOccurrences(of: "Memory Buffers: ", with: "").replacingOccurrences(of: " MB", with: "")) ?? 0.0
            } else if component.hasPrefix("Memory Shared:") {
                memoryShared = Double(component.replacingOccurrences(of: "Memory Shared: ", with: "").replacingOccurrences(of: " MB", with: "")) ?? 0.0
            } else if component.hasPrefix("Memory Cached:") {
                memoryCached = Double(component.replacingOccurrences(of: "Memory Cached: ", with: "").replacingOccurrences(of: " MB", with: "")) ?? 0.0
            } else if component.hasPrefix("Memory Slab:") {
                memorySlab = Double(component.replacingOccurrences(of: "Memory Slab: ", with: "").replacingOccurrences(of: " MB", with: "")) ?? 0.0
            } else if component.hasPrefix("Memory Percent:") {
                memoryPercent = Double(component.replacingOccurrences(of: "Memory Percent: ", with: "").replacingOccurrences(of: " percent", with: "")) ?? 0.0
            } else if component.hasPrefix("Disk Percent:") {
                diskPercent = Double(component.replacingOccurrences(of: "Disk Percent: ", with: "").replacingOccurrences(of: " percent", with: "")) ?? 0.0
            }
            
        }
    }
    
    // MARK: - Message Handler
    private func handleDroneMessage(_ elementName: String, _ parent: String) {
        switch elementName {
        case "remarks":
            let (mac, rssi, desc) = parseDroneRemarks(remarks)
            
//            print("DEBUG - Parsing Remarks: MAC = \(mac ?? "nil"), RSSI = \(rssi != nil ? "\(rssi!)" : "nil"), Description = \(desc ?? "nil")")
            
            if cotMessage == nil {
                cotMessage = CoTViewModel.CoTMessage(
                    uid: eventAttributes["uid"] ?? "",
                    type: eventAttributes["type"] ?? "",
                    lat: pointAttributes["lat"] ?? "0.0",
                    lon: pointAttributes["lon"] ?? "0.0",
                    speed: speed,
                    vspeed: vspeed,
                    alt: alt,
                    height: height,
                    pilotLat: pilotLat,
                    pilotLon: pilotLon,
                    description: desc ?? "",
                    uaType: .helicopter,
                    idType: ((eventAttributes["type"]?.contains("-S")) != nil) ? "Serial Number (ANSI/CTA-2063-A)" :
                        ((eventAttributes["type"]?.contains("-R")) != nil) ? "CAA Registration ID" : "None",
                    mac: mac,
                    rssi: rssi,
                    rawMessage: [
                        "mac": mac ?? "",
                        "rssi": rssi ?? 0
                    ]
                )
            } else {
                cotMessage?.mac = mac
                cotMessage?.rssi = rssi
                cotMessage?.description = desc ?? cotMessage?.description ?? ""
            }
        case "message":
            if let jsonData = messageContent.data(using: .utf8) {
                // Try to parse as array first
                if let jsonArray = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] {
                    // Store complete array for signature generation
                    rawMessage = ["messages": jsonArray]
                    
                    // Store BLE data if present
                    if let firstMessage = jsonArray.first {
                        if let aux = firstMessage["AUX_ADV_IND"] as? [String: Any] {
                            auxAdvInd = aux
                            rawMessage?["AUX_ADV_IND"] = aux
                        }
                        if let adtype = firstMessage["adtype"] as? [String: Any] {
                            adType = adtype
                            rawMessage?["adtype"] = adtype
                        }
                        if let aextData = firstMessage["aext"] as? [String: Any] {
                            aext = aextData
                            rawMessage?["aext"] = aextData
                        }
                    }
                    
                    // Define what to grab
                    var droneId: String?
                    var droneMAC: String?
                    var description = ""
                    var location: [String: Any]?
                    var system: [String: Any]?
                    var droneType = "a-f-G-U"
                    var idType = "Unknown"
                    var uaType: DroneSignature.IdInfo.UAType = .helicopter
                    
                    // First pass - collect Basic ID info
                    for message in jsonArray {
                        if let basicId = message["Basic ID"] as? [String: Any],
                           let id = basicId["id"] as? String,
                           !id.isEmpty {
                            droneId = id
                            droneMAC = basicId["MAC"] as? String ??
                            (aext?["AdvA"] as? String)?.components(separatedBy: " ").first
                            idType = basicId["id_type"] as? String ?? "Unknown"
                            if let uaTypeStr = basicId["ua_type"] as? String {
                                uaType = mapUAType(uaTypeStr)
                            }
                            
                            if idType == "Serial Number (ANSI/CTA-2063-A)" {
                                droneType += "-S"
                            } else if idType == "CAA Registration ID" {
                                droneType += "-R"
                            } else {
                                droneType += "-U"
                            }
                            break
                        }
                    }
                    
                    // Second pass - collect additional data
                    for message in jsonArray {
                        if let locMsg = message["Location/Vector Message"] as? [String: Any] {
                            location = locMsg
                        } else if let sysMsg = message["System Message"] as? [String: Any] {
                            system = sysMsg
                            if system?["operator_lat"] != nil || system?["operator_lon"] != nil {
                                droneType += "-O"
                            }
                        } else if let selfId = message["Self-ID Message"] as? [String: Any] {
                            description = selfId["text"] as? String ?? ""
                        }
                    }
                    
                    droneType += "-F"
                    
                    if let droneId = droneId {
                        // Create message with all available data
                        cotMessage = CoTViewModel.CoTMessage(
                            uid: droneId,
                            type: droneType,
                            lat: String(describing: location?["latitude"] ?? "0.0"),
                            lon: String(describing: location?["longitude"] ?? "0.0"),
                            speed: String(describing: location?["speed"] ?? "0.0"),
                            vspeed: String(describing: location?["vert_speed"] ?? "0.0"),
                            alt: String(describing: location?["geodetic_altitude"] ?? "0.0"),
                            height: String(describing: location?["height_agl"] ?? "0.0"),
                            pilotLat: String(describing: system?["operator_lat"] ?? "0.0"),
                            pilotLon: String(describing: system?["operator_lon"] ?? "0.0"),
                            description: description,
                            uaType: uaType,
                            idType: idType,
                            mac: droneMAC ?? "",
                            // Include all BLE/transmission data
                            rawMessage: [
                                "messages": jsonArray,
                                "AUX_ADV_IND": auxAdvInd as Any,
                                "adtype": adType as Any,
                                "aext": aext as Any
                            ]
                        )
                    }
                }
                // Single object parsing
                else if let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                    rawMessage = json
                    print("Found single objects.. \(String(describing: rawMessage))")
                    if let basicId = json["Basic ID"] as? [String: Any],
                       let id = basicId["id"] as? String {
                        let droneType = buildDroneType(json)
                        let location = json["Location/Vector Message"] as? [String: Any]
                        let system = json["System Message"] as? [String: Any]
                        let selfId = json["Self-ID Message"] as? [String: Any]
                        
                        cotMessage = CoTViewModel.CoTMessage(
                            uid: id,
                            type: droneType,
                            lat: String(describing: location?["latitude"] ?? "0.0"),
                            lon: String(describing: location?["longitude"] ?? "0.0"),
                            speed: String(describing: location?["speed"] ?? "0.0"),
                            vspeed: String(describing: location?["vert_speed"] ?? "0.0"),
                            alt: String(describing: location?["geodetic_altitude"] ?? "0.0"),
                            height: String(describing: location?["height_agl"] ?? "0.0"),
                            pilotLat: String(describing: system?["latitude"] ?? "0.0"),
                            pilotLon: String(describing: system?["longitude"] ?? "0.0"),
                            description: selfId?["text"] as? String ?? "",
                            uaType: mapUAType(basicId["ua_type"] as? String),
                            idType: basicId["id_type"] as? String ?? "Unknown",
                            mac: basicId["MAC"] as? String ?? "",
                            rssi: basicId["RSSI"] as? Int ?? 0,
                            rawMessage: json
                        )
                    }
                }
            }
        case "event":
            if cotMessage == nil {
                let jsonFormat: [String: Any] = [
                    "Basic ID": [
                        "id": eventAttributes["uid"] ?? "",
                        "mac": eventAttributes["MAC"] ?? "",
                        "rssi": eventAttributes["RSSI"] ?? "",
                        "id_type": ((eventAttributes["type"]?.contains("-S")) != nil) ? "Serial Number (ANSI/CTA-2063-A)" :
                            ((eventAttributes["type"]?.contains("-R")) != nil) ? "CAA Registration ID" : "None",
                        "ua_type": "Helicopter (or Multirotor)"
                    ],
                    "Location/Vector Message": [
                        "latitude": pointAttributes["lat"] ?? "0.0",
                        "longitude": pointAttributes["lon"] ?? "0.0",
                        "speed": speed,
                        "vert_speed": vspeed,
                        "geodetic_altitude": alt,
                        "height_agl": height
                    ],
                    "System Message": [
                        "latitude": pilotLat,
                        "longitude": pilotLon
                    ],
                    "Self-ID Message": [
                        "text": droneDescription
                    ],
                    "AUX_ADV_IND": auxAdvInd ?? [:],
                    "adtype": adType ?? [:],
                    "aext": aext ?? [:]
                    
                ]
                rawMessage = jsonFormat
                
                cotMessage = CoTViewModel.CoTMessage(
                    uid: eventAttributes["uid"] ?? "",
                    type: eventAttributes["type"] ?? "",
                    lat: pointAttributes["lat"] ?? "0.0",
                    lon: pointAttributes["lon"] ?? "0.0",
                    speed: speed,
                    vspeed: vspeed,
                    alt: alt,
                    height: height,
                    pilotLat: pilotLat,
                    pilotLon: pilotLon,
                    description: droneDescription,
                    uaType: .helicopter,
                    idType: ((eventAttributes["type"]?.contains("-S")) != nil) ? "Serial Number (ANSI/CTA-2063-A)" :
                        ((eventAttributes["type"]?.contains("-R")) != nil) ? "CAA Registration ID" : "None",
                    mac: eventAttributes["MAC"] ?? "",
                    rssi: Int(eventAttributes["RSSI"] ?? "") ?? 0,
                    rawMessage: jsonFormat
                )
            }
        case "Speed":
            speed = currentValue
        case "VerticalSpeed":
            vspeed = currentValue
        case "Altitude":
            alt = currentValue
        case "Height":
            height = currentValue
        case "Description":
            droneDescription = currentValue
        case "lat":
            if parent == "PilotLocation" {
                pilotLat = currentValue
            }
        case "lon":
            if parent == "PilotLocation" {
                pilotLon = currentValue
            }
        case "TimeSpeed":
            cotMessage?.timeSpeed = currentValue
        case "status":
            cotMessage?.status = currentValue
        case "direction":
            cotMessage?.direction = currentValue
        case "altPressure":
            cotMessage?.altPressure = currentValue
        case "heightType":
            cotMessage?.heightType = currentValue
        case "horizAcc":
            cotMessage?.horizAcc = currentValue
        case "vertAcc":
            cotMessage?.vertAcc = currentValue
        case "baroAcc":
            cotMessage?.baroAcc = currentValue
        case "speedAcc":
            cotMessage?.speedAcc = currentValue
        case "timestamp":
            cotMessage?.timestamp = currentValue
        case "operatorAltGeo":
            cotMessage?.operatorAltGeo = currentValue
        case "areaCount":
            cotMessage?.areaCount = currentValue
        case "areaRadius":
            cotMessage?.areaRadius = currentValue
        case "areaCeiling":
            cotMessage?.areaCeiling = currentValue
        case "areaFloor":
            cotMessage?.areaFloor = currentValue
        case "classification":
            cotMessage?.classification = currentValue
        case "selfIdType":
            cotMessage?.selfIdType = currentValue
        case "authType":
            cotMessage?.authType = currentValue
        case "authPage":
            cotMessage?.authPage = currentValue
        case "authLength":
            cotMessage?.authLength = currentValue
        case "authTimestamp":
            cotMessage?.authTimestamp = currentValue
        case "authData":
            cotMessage?.authData = currentValue
        default:
            break
        }
    }
    
    func parseESP32Message(_ jsonData: [String: Any]) -> CoTViewModel.CoTMessage? {
        print("Starting ESP32 parsing")
        var droneType = "a-f-G-U"
        
        if let basicID = jsonData["Basic ID"] as? [String: Any] {
            let rawId = basicID["id"] as? String ?? UUID().uuidString
            let droneId = rawId == "NONE" ? "\(UUID().uuidString)" : "\(rawId)"
            let mac = basicID["MAC"] as? String ?? ""
            let rssi = basicID["rssi"] as? Int ?? 0
            let idType = basicID["id_type"] as? String ?? "Unknown"
            if idType == "Serial Number (ANSI/CTA-2063-A)" {
                droneType += "-S"
            } else if idType == "CAA Assigned Registration ID" {
                droneType += "-R"
            } else {
                droneType += "-U"
            }
            
            var lat = "0.0", lon = "0.0"
            var speed = "0.0", vspeed = "0.0"
            var alt = "0.0", height = "0.0"
            if let location = jsonData["Location/Vector Message"] as? [String: Any] {
                lat = String(describing: location["latitude"] ?? "0.0")
                lon = String(describing: location["longitude"] ?? "0.0")
                
                speed = String(describing: location["speed"] ?? "0.0")
                vspeed = String(describing: location["vert_speed"] ?? "0.0")
                alt = String(describing: location["geodetic_altitude"] ?? "0.0")
                height = String(describing: location["height_agl"] ?? "0.0")
            }
            
            var pilotLat = "0.0", pilotLon = "0.0"
            if let system = jsonData["System Message"] as? [String: Any] {
                pilotLat = String(describing: system["operator_lat"] ?? "0.0")
                pilotLon = String(describing: system["operator_lon"] ?? "0.0")
                if pilotLat != "0.0" && pilotLon != "0.0" {
                    droneType += "-O"
                }
            }
            
            var description = ""
            if let selfID = jsonData["Self-ID Message"] as? [String: Any] {
                description = selfID["text"] as? String ?? ""
            }
            
            droneType += "-F"
            
            return CoTViewModel.CoTMessage(
                uid: droneId,
                type: droneType,
                lat: lat,
                lon: lon,
                speed: speed,
                vspeed: vspeed,
                alt: alt,
                height: height,
                pilotLat: pilotLat,
                pilotLon: pilotLon,
                description: description,
                uaType: mapUAType(basicID["ua_type"] as? Int ?? 0),
                idType: idType,
                mac: mac,
                rssi: rssi,
                rawMessage: jsonData
            )
        }
        
        return nil
    }
    
    
    private func buildDroneType(_ json: [String: Any]) -> String {
        var droneType = "a-f-G-U"
        if let basicId = json["Basic ID"] as? [String: Any],
           let idType = basicId["id_type"] as? String {
            if idType == "Serial Number (ANSI/CTA-2063-A)" {
                droneType += "-S"
            } else if idType == "CAA Assigned Registration ID" {
                droneType += "-R"
            } else {
                droneType += "-U"
            }
        }
        if let system = json["System Message"] as? [String: Any],
           let lat = system["latitude"] as? Double,
           let lon = system["longitude"] as? Double,
           lat != 0.0 && lon != 0.0 {
            droneType += "-O"
        }
        droneType += "-F"
        return droneType
    }
    
    private func mapUAType(_ typeStr: String?) -> DroneSignature.IdInfo.UAType {
        guard let typeStr = typeStr else { return .helicopter }
        switch typeStr {
        case "Helicopter (or Multirotor)": return .helicopter
        case "Aeroplane", "Airplane": return .aeroplane
        case "Gyroplane": return .gyroplane
        case "Hybrid Lift": return .hybridLift
        case "Ornithopter": return .ornithopter
        case "Glider": return .glider
        case "Kite": return .kite
        case "Free Balloon": return .freeballoon
        case "Captive Balloon": return .captive
        case "Airship": return .airship
        case "Free Fall/Parachute": return .freeFall
        case "Rocket": return .rocket
        case "Tethered Powered Aircraft": return .tethered
        case "Ground Obstacle": return .groundObstacle
        default: return .helicopter
        }
    }
    
    private func mapUAType(_ typeInt: Int) -> DroneSignature.IdInfo.UAType {
        switch typeInt {
        case 0: return .none
        case 1: return .aeroplane
        case 2: return .helicopter
        case 3: return .gyroplane
        case 4: return .hybridLift
        case 5: return .ornithopter
        case 6: return .glider
        case 7: return .kite
        case 8: return .freeballoon
        case 9: return .captive
        case 10: return .airship
        case 11: return .freeFall
        case 12: return .rocket
        case 13: return .tethered
        case 14: return .groundObstacle
        default: return .helicopter
        }
    }
}

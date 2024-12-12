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
        
        if let type = eventAttributes["type"], type == "b-m-p-s-m" {
            handleStatusMessage(elementName)
        } else {
            handleDroneMessage(elementName, parent)
        }
        
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
    
    private func parseRemarks(_ remarks: String) {
        let components = remarks.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        for component in components {
            print("Processing component: \(component)")
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
        case "message":
            if let jsonData = messageContent.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                rawMessage = json
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
                        rawMessage: json
                    )
                }
            }
        case "event":
            if cotMessage == nil {
                let jsonFormat: [String: Any] = [
                    "Basic ID": [
                        "id": eventAttributes["uid"] ?? "",
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
                    ]
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
        default:
            break
        }
    }
    
    func parseESP32Message(_ jsonData: [String: Any]) -> CoTViewModel.CoTMessage? {
        print("Starting ESP32 parsing")
        var droneType = "a-f-G-U"
        
        if let basicID = jsonData["Basic ID"] as? [String: Any],
           let id = basicID["id"] as? String {
            let droneId = "ESP32-\(id)"
            
            if let idType = basicID["id_type"] as? String {
                if idType == "Serial Number (ANSI/CTA-2063-A)" {
                    droneType += "-S"
                } else if idType == "CAA Assigned Registration ID" {
                    droneType += "-R"
                } else {
                    droneType += "-U"
                }
            }
            
            var lat = "0.0", lon = "0.0"
            var speed = "0.0", vspeed = "0.0"
            var alt = "0.0", height = "0.0"
            if let location = jsonData["Location/Vector Message"] as? [String: Any] {
                lat = String(describing: location["latitude"] ?? "0.0")
                lon = String(describing: location["longitude"] ?? "0.0")
                
                // Ditch messages with zero location
                if lat == "0.0" || lon == "0.0" {
                    print("Discarding XML drone message with zero coordinates")
                    return nil
                }
                
                speed = String(describing: location["speed"] ?? "0.0")
                vspeed = String(describing: location["vert_speed"] ?? "0.0")
                alt = String(describing: location["geodetic_altitude"] ?? "0.0")
                height = String(describing: location["height_agl"] ?? "0.0")
            }
            
            var pilotLat = "0.0", pilotLon = "0.0"
            if let system = jsonData["System Message"] as? [String: Any] {
                pilotLat = String(describing: system["latitude"] ?? "0.0")
                pilotLon = String(describing: system["longitude"] ?? "0.0")
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
                rawMessage: rawMessage ?? [:]
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
}

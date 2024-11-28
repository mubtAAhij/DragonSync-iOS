//
//  XMLParserDelegate.swift
//  WarDragon
//
//  Created by Luke on 11/18/24.
//

import Foundation

class CoTMessageParser: NSObject, XMLParserDelegate {
    // MARK: - Properties
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
    private var memoryPercent: Double = 0.0
    private var diskTotal: Double = 0.0
    private var diskUsed: Double = 0.0
    private var diskPercent: Double = 0.0
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
        
        // Handle message type based on event type attribute
        if let type = eventAttributes["type"], type == "b-m-p-s-m" {
            handleStatusMessage(elementName)
        } else {
            handleDroneMessage(elementName, parent)
        }
        
        elementStack.removeLast()
    }
    
    // MARK: - Message Handlers
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
                        free: Int64(memoryAvailable * 1024 * 1024),
                        active: Int64(memoryUsed * 0.6 * 1024 * 1024),
                        inactive: Int64(memoryUsed * 0.4 * 1024 * 1024),
                        buffers: Int64(memoryAvailable * 0.1 * 1024 * 1024),
                        cached: Int64(memoryAvailable * 0.3 * 1024 * 1024),
                        shared: Int64(memoryUsed * 0.2 * 1024 * 1024),
                        slab: Int64(memoryUsed * 0.1 * 1024 * 1024)
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
        //print("Parsing remarks: \(remarks)")
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
            }
        }
        print("Parsed CPU Usage: \(cpuUsage), Memory Total: \(memoryTotal), Memory Available: \(memoryAvailable), Disk Total: \(diskTotal), Disk Used: \(diskUsed), Temperature: \(temperature), Uptime: \(uptime)")
    }

    private func handleDroneMessage(_ elementName: String, _ parent: String) {
        switch elementName {
        case "message":
            if let jsonData = messageContent.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                print("Found ESP32 JSON message")
                cotMessage = parseESP32Message(json)
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
        case "event":
            if cotMessage == nil {
                let lat = pointAttributes["lat"] ?? "0.0"
                let lon = pointAttributes["lon"] ?? "0.0"
                
                // Validate location before alerting
                if lat == "0.0" || lon == "0.0" {
                    print("Discarding XML drone message with zero coordinates")
                    return
                }

                cotMessage = CoTViewModel.CoTMessage(
                    uid: eventAttributes["uid"] ?? "",
                    type: eventAttributes["type"] ?? "",
                    lat: lat,
                    lon: lon,
                    speed: speed,
                    vspeed: vspeed,
                    alt: alt,
                    height: height,
                    pilotLat: pilotLat,
                    pilotLon: pilotLon,
                    description: droneDescription
                )
            }
        default:
            break
        }
    }
    
    // MARK: - ESP32 Message Parser
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
                description: description
            )
        }
        
        return nil
    }
}

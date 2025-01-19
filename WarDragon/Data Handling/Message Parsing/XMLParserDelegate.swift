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
    private var currentIdType: String = "Unknown"
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
    private var location_protocol: String?
    private var op_status: String?
    private var height_type: String?
    private var ew_dir_segment: String?
    private var speed_multiplier: String?
    private var vertical_accuracy: String?
    private var horizontal_accuracy: String?
    private var baro_accuracy: String?
    private var speed_accuracy: String?
    private var timestamp: String?
    private var timestamp_accuracy: String?
    private var operator_id: String?
    private var operator_id_type: String?
    private var aux_rssi: Int?
    private var channel: Int?
    private var phy: Int?
    private var aa: Int?
    private var adv_mode: String?
    private var adv_mac: String?
    private var did: Int?
    private var sid: Int?
    
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
    
    private var plutoTemp: Double = 0.0
    private var zynqTemp: Double = 0.0
    
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
            // For multicast message altitude is in hae
            if let haeAlt = attributes["hae"] {
                alt = haeAlt  // Set alt for multicast messages
            }
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if currentElement == "message" {
            messageContent += string
            if let jsonData = string.data(using: .utf8) {
                // Try array format first
                if let jsonArray = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] {
                    processJSONArray(jsonArray)
                }
                // Then try single object
                else if let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                    processSingleJSON(jsonObject)
                }
            }
        } else if currentElement == "remarks" {
            remarks += string
        } else {
            currentValue += string.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    
    private func processJSONArray(_ messages: [[String: Any]]) {
        var droneData: [String: Any] = [:]
        
        for message in messages {
            if let basicId = message["Basic ID"] as? [String: Any] {
                droneData["id"] = basicId["id"]
                droneData["id_type"] = basicId["id_type"]
                droneData["mac"] = basicId["MAC"]
                droneData["rssi"] = basicId["RSSI"]
                droneData["protocol_version"] = basicId["protocol_version"]
            }
            
            if let location = message["Location/Vector Message"] as? [String: Any] {
                droneData["latitude"] = location["latitude"]
                droneData["longitude"] = location["longitude"]
                droneData["speed"] = location["speed"]
                droneData["vert_speed"] = location["vert_speed"]
                droneData["geodetic_altitude"] = location["geodetic_altitude"]
                droneData["height_agl"] = location["height_agl"]
                droneData["direction"] = location["direction"]
                droneData["op_status"] = location["op_status"]
                droneData["height_type"] = location["height_type"]
                droneData["vertical_accuracy"] = location["vertical_accuracy"]
                droneData["horizontal_accuracy"] = location["horizontal_accuracy"]
                droneData["baro_accuracy"] = location["baro_accuracy"]
                droneData["speed_accuracy"] = location["speed_accuracy"]
                droneData["timestamp"] = location["timestamp"]
            }
            
            if let system = message["System Message"] as? [String: Any] {
                droneData["pilot_lat"] = system["operator_lat"] ?? system["latitude"]
                droneData["pilot_lon"] = system["operator_lon"] ?? system["longitude"]
                droneData["area_count"] = system["area_count"]
                droneData["area_radius"] = system["area_radius"]
                droneData["area_ceiling"] = system["area_ceiling"]
                droneData["area_floor"] = system["area_floor"]
                droneData["operator_alt_geo"] = system["operator_alt_geo"]
                droneData["classification"] = system["classification"]
            }
            
            if let selfId = message["Self-ID Message"] as? [String: Any] {
                droneData["description"] = selfId["text"]
            }
        }
        
        if let basicId = droneData["id"] as? String {
            cotMessage = CoTViewModel.CoTMessage(
                uid: basicId,
                type: buildDroneType(droneData),
                lat: String(describing: droneData["latitude"] ?? "0.0"),
                lon: String(describing: droneData["longitude"] ?? "0.0"),
                speed: String(describing: droneData["speed"] ?? "0.0"),
                vspeed: String(describing: droneData["vert_speed"] ?? "0.0"),
                alt: String(describing: droneData["geodetic_altitude"] ?? "0.0"),
                height: String(describing: droneData["height_agl"] ?? "0.0"),
                pilotLat: String(describing: droneData["pilot_lat"] ?? "0.0"),
                pilotLon: String(describing: droneData["pilot_lon"] ?? "0.0"),
                description: droneData["description"] as? String ?? "",
                uaType: mapUAType(droneData["ua_type"]),
                idType: droneData["id_type"] as? String ?? "Unknown",
                mac: droneData["mac"] as? String,
                rssi: droneData["rssi"] as? Int,
                location_protocol: droneData["protocol_version"] as? String,
                op_status: droneData["op_status"] as? String,
                height_type: droneData["height_type"] as? String,
                ew_dir_segment: droneData["ew_dir_segment"] as? String,
                speed_multiplier: droneData["speed_multiplier"] as? String,
                direction: droneData["direction"] as? String,
                vertical_accuracy: droneData["vertical_accuracy"] as? String,
                horizontal_accuracy: droneData["horizontal_accuracy"] as? String,
                baro_accuracy: droneData["baro_accuracy"] as? String,
                speed_accuracy: droneData["speed_accuracy"] as? String,
                timestamp: droneData["timestamp"] as? String,
                timestamp_accuracy: droneData["timestamp_accuracy"] as? String,
                operator_id: droneData["operator_id"] as? String,
                operator_id_type: droneData["operator_id_type"] as? String,
                rawMessage: droneData
            )
        }
    }
    
    private func processSingleJSON(_ json: [String: Any]) {
        if let message = parseESP32Message(json) {
            cotMessage = message
        }
    }
    
    func parseESP32Message(_ jsonData: [String: Any]) -> CoTViewModel.CoTMessage? {
        if let basicId = jsonData["Basic ID"] as? [String: Any] {
            let droneId = basicId["id"] as? String ?? UUID().uuidString
            let droneType = buildDroneType(jsonData)
            
            let location = jsonData["Location/Vector Message"] as? [String: Any]
            let system = jsonData["System Message"] as? [String: Any]
            let selfId = jsonData["Self-ID Message"] as? [String: Any]
            
            return CoTViewModel.CoTMessage(
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
                description: selfId?["text"] as? String ?? "",
                uaType: mapUAType(basicId["ua_type"]),
                idType: basicId["id_type"] as? String ?? "Unknown",
                mac: basicId["MAC"] as? String,
                rssi: basicId["RSSI"] as? Int,
                location_protocol: location?["protocol_version"] as? String,
                op_status: location?["op_status"] as? String,
                height_type: location?["height_type"] as? String,
                ew_dir_segment: location?["ew_dir_segment"] as? String,
                speed_multiplier: location?["speed_multiplier"] as? String,
                direction: location?["direction"] as? String,
                vertical_accuracy: location?["vertical_accuracy"] as? String,
                horizontal_accuracy: location?["horizontal_accuracy"] as? String,
                baro_accuracy: location?["baro_accuracy"] as? String,
                speed_accuracy: location?["speed_accuracy"] as? String,
                timestamp: location?["timestamp"] as? String,
                timestamp_accuracy: location?["timestamp_accuracy"] as? String,
                operator_id: (jsonData["Operator ID Message"] as? [String: Any])?["operator_id"] as? String,
                operator_id_type: (jsonData["Operator ID Message"] as? [String: Any])?["operator_id_type"] as? String,
                rawMessage: jsonData
            )
        }
        return nil
    }
    
    private func buildDroneType(_ json: [String: Any]) -> String {
        var droneType = "a-f-G-U"
        
        if let basicId = json["Basic ID"] as? [String: Any] {
            let idType = basicId["id_type"] as? String
            if idType == "Serial Number (ANSI/CTA-2063-A)" {
                droneType += "-S"
            } else if idType == "CAA Assigned Registration ID" {
                droneType += "-R"
            } else {
                droneType += "-U"
            }
        }
        
        if let system = json["System Message"] as? [String: Any],
           let operatorLat = system["operator_lat"] as? Double,
           let operatorLon = system["operator_lon"] as? Double,
           operatorLat != 0.0 && operatorLon != 0.0 {
            droneType += "-O"
        }
        
        droneType += "-F"
        return droneType
    }
    
    
    private func mapUAType(_ value: Any?) -> DroneSignature.IdInfo.UAType {
        if let intValue = value as? Int {
            switch intValue {
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
            default: return .other
            }
        } else if let strValue = value as? String {
            switch strValue {
            case "None": return .none
            case "Aeroplane", "Airplane": return .aeroplane
            case "Helicopter (or Multirotor)": return .helicopter
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
        return .helicopter
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
            // Ensure uid has "wardragon-" prefix
            let fullUid = uid.hasPrefix("wardragon-") ? uid : "wardragon-" + uid
            let serialNumber = eventAttributes["uid"] ?? "unknown"
            let fullSerialNumber = serialNumber.hasPrefix("wardragon-") ? serialNumber: "wardragon-" + serialNumber
            let lat = Double(pointAttributes["lat"] ?? "0.0") ?? 0.0
            let lon = Double(pointAttributes["lon"] ?? "0.0") ?? 0.0
            let altitude = Double(pointAttributes["hae"] ?? "0.0") ?? 0.0
            
            statusMessage = StatusViewModel.StatusMessage(
                uid: fullUid,
                serialNumber: fullSerialNumber,
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
                ),
                antStats: .init(
                    plutoTemp: plutoTemp,
                    zynqTemp: zynqTemp
                )
            )
        default:
            break
        }
    }
    
    private func parseDroneRemarks(_ remarks: String) -> (
        mac: String?,
        rssi: Int?,
        protocolVersion: String?,
        description: String?,
        speed: Double?,
        vspeed: Double?,
        alt: Double?,
        heightAGL: Double?,
        heightType: String?,
        pressureAltitude: Double?,
        ewDirSegment: String?,
        speedMultiplier: Double?,
        opStatus: String?,
        direction: Double?,
        timestamp: String?,
        runtime: String?,
        index: String?,
        status: String?,
        altPressure: Double?,
        horizAcc: Int?,
        vertAcc: String?,
        baroAcc: Int?,
        speedAcc: Int?,
        selfIDtext: String?,
        selfIDDesc: String?,
        operatorID: String?,
        uaType: String?,
        operatorLat: Double?,
        operatorLon: Double?,
        operatorAltGeo: Double?,
        classification: Int?
    ) {
        var mac: String?
        var rssi: Int?
        var protocolVersion: String?
        var description: String?
        var speed: Double?
        var vspeed: Double?
        var alt: Double?
        var heightAGL: Double?
        var heightType: String?
        var pressureAltitude: Double?
        var ewDirSegment: String?
        var speedMultiplier: Double?
        var opStatus: String?
        var direction: Double?
        var timestamp: String?
        var runtime: String?
        var index: String?
        var status: String?
        var altPressure: Double?
        var horizAcc: Int?
        var vertAcc: String?
        var baroAcc: Int?
        var speedAcc: Int?
        var selfIDtext: String?
        var selfIDDesc: String?
        var operatorID: String?
        var uaType: String?
        var operatorLat: Double?
        var operatorLon: Double?
        var operatorAltGeo: Double?
        var classification: Int?
        
        let components = remarks.components(separatedBy: ", ")
        
        for component in components {
            let trimmed = component.trimmingCharacters(in: .whitespaces)
            
            if trimmed.hasPrefix("MAC:") {
                mac = trimmed.dropFirst(4).trimmingCharacters(in: .whitespaces).components(separatedBy: " ").first
            } else if trimmed.hasPrefix("RSSI:") {
                rssi = Int(trimmed.dropFirst(5).replacingOccurrences(of: "dBm", with: "").trimmingCharacters(in: .whitespaces))
            } else if trimmed.hasPrefix("Protocol Version:") {
                protocolVersion = trimmed.dropFirst(17).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Description:") {
                description = trimmed.dropFirst(12).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Speed:") {
                speed = Double(trimmed.dropFirst(6).replacingOccurrences(of: "m/s", with: "").trimmingCharacters(in: .whitespaces))
            } else if trimmed.hasPrefix("Vert Speed:") {
                vspeed = Double(trimmed.dropFirst(11).replacingOccurrences(of: "m/s", with: "").trimmingCharacters(in: .whitespaces))
            } else if trimmed.hasPrefix("Geodetic Altitude:") {
                alt = Double(trimmed.dropFirst(18).replacingOccurrences(of: "m", with: "").trimmingCharacters(in: .whitespaces))
            } else if trimmed.hasPrefix("Height AGL:") {
                heightAGL = Double(trimmed.dropFirst(11).replacingOccurrences(of: "m", with: "").trimmingCharacters(in: .whitespaces))
            } else if trimmed.hasPrefix("Height Type:") {
                heightType = trimmed.dropFirst(12).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Pressure Altitude:") {
                pressureAltitude = Double(trimmed.dropFirst(18).replacingOccurrences(of: "m", with: "").trimmingCharacters(in: .whitespaces))
            } else if trimmed.hasPrefix("EW Direction Segment:") {
                ewDirSegment = trimmed.dropFirst(21).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Speed Multiplier:") {
                speedMultiplier = Double(trimmed.dropFirst(17).trimmingCharacters(in: .whitespaces))
            } else if trimmed.hasPrefix("Operational Status:") {
                opStatus = trimmed.dropFirst(19).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Direction:") {
                direction = Double(trimmed.dropFirst(10).trimmingCharacters(in: .whitespaces))
            } else if trimmed.hasPrefix("Timestamp:") {
                timestamp = trimmed.dropFirst(10).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Runtime:") {
                runtime = trimmed.dropFirst(8).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Index:") {
                index = trimmed.dropFirst(6).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Status:") {
                status = trimmed.dropFirst(7).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Alt Pressure:") {
                altPressure = Double(trimmed.dropFirst(13).replacingOccurrences(of: "m", with: "").trimmingCharacters(in: .whitespaces))
            } else if trimmed.hasPrefix("Horizontal Accuracy:") {
                horizAcc = Int(trimmed.dropFirst(20).trimmingCharacters(in: .whitespaces))
            } else if trimmed.hasPrefix("Vertical Accuracy:") {
                vertAcc = trimmed.dropFirst(18).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Baro Accuracy:") {
                baroAcc = Int(trimmed.dropFirst(14).trimmingCharacters(in: .whitespaces))
            } else if trimmed.hasPrefix("Speed Accuracy:") {
                speedAcc = Int(trimmed.dropFirst(15).trimmingCharacters(in: .whitespaces))
            } else if trimmed.hasPrefix("Self-ID Message: Text:") {
                selfIDtext = trimmed.dropFirst(22).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Self-ID Message: Description:") {
                selfIDDesc = trimmed.dropFirst(30).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Operator ID:") {
                operatorID = trimmed.dropFirst(12).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("UA Type:") {
                uaType = trimmed.dropFirst(8).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Operator Location: Lat") {
                operatorLat = Double(trimmed.dropFirst(22).components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? "")
            } else if trimmed.hasPrefix("Lon") {
                operatorLon = Double(trimmed.dropFirst(3).components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? "")
            } else if trimmed.hasPrefix("Altitude") {
                operatorAltGeo = Double(trimmed.dropFirst(8).replacingOccurrences(of: "m", with: "").trimmingCharacters(in: .whitespaces))
            } else if trimmed.hasPrefix("Classification:") {
                classification = Int(trimmed.dropFirst(15).trimmingCharacters(in: .whitespaces))
            }
        }
        
        return (mac, rssi, protocolVersion, description, speed, vspeed, alt, heightAGL, heightType, pressureAltitude, ewDirSegment, speedMultiplier, opStatus, direction, timestamp, runtime, index, status, altPressure, horizAcc, vertAcc, baroAcc, speedAcc, selfIDtext, selfIDDesc, operatorID, uaType, operatorLat, operatorLon, operatorAltGeo, classification)
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
            } else if component.hasPrefix("Pluto Temp:") {
                plutoTemp = Double(component.replacingOccurrences(of: "Pluto Temp: ", with: "").replacingOccurrences(of: "°C", with: "")) ?? 0.0
            } else if component.hasPrefix("Zynq Temp:") {
                zynqTemp = Double(component.replacingOccurrences(of: "Zynq Temp: ", with: "").replacingOccurrences(of: "°C", with: "")) ?? 0.0
            }
            
        }
    }
    
    // MARK: - Message Handler
    private func handleDroneMessage(_ elementName: String, _ parent: String) {
        switch elementName {
        case "remarks":
            // Parse remarks field
            let (mac, rssi, protocolVersion, description, speed, vspeed, alt, heightAGL, heightType, pressureAltitude, ewDirSegment, speedMultiplier, opStatus, direction, timestamp, runtime, index, status, altPressure, horizAcc, vertAcc, baroAcc, speedAcc, selfIDtext, selfIDDesc, operatorID, uaType, operatorLat, operatorLon, operatorAltGeo, classification) = parseDroneRemarks(remarks)
            
            if cotMessage == nil {
                cotMessage = CoTViewModel.CoTMessage(
                    uid: eventAttributes["uid"] ?? "",
                    type: eventAttributes["type"] ?? "",
                    lat: pointAttributes["lat"] ?? "0.0",
                    lon: pointAttributes["lon"] ?? "0.0",
                    speed: speed?.description ?? "0.0",
                    vspeed: vspeed?.description ?? "0.0",
                    alt: alt?.description ?? "0.0",
                    height: heightAGL?.description ?? "0.0",
                    pilotLat: operatorLat?.description ?? "0.0",
                    pilotLon: operatorLon?.description ?? "0.0",
                    description: description ?? "",
                    uaType: mapUAType(uaType),
                    idType: buildIdType(),
                    protocolVersion: protocolVersion,
                    mac: mac,
                    rssi: rssi,
                    location_protocol: location_protocol,
                    op_status: opStatus,
                    height_type: heightType,
                    ew_dir_segment: ewDirSegment,
                    speed_multiplier: speedMultiplier?.description,
                    direction: direction?.description,
                    vertical_accuracy: vertAcc,
                    horizontal_accuracy: horizAcc?.description,
                    baro_accuracy: baroAcc?.description,
                    speed_accuracy: speedAcc?.description,
                    timestamp: timestamp,
                    timestamp_accuracy: timestamp_accuracy,
                    time: nil,
                    start: nil,
                    stale: nil,
                    how: nil,
                    ce: nil,
                    le: nil,
                    hae: nil,
                    aux_rssi: aux_rssi,
                    channel: channel,
                    phy: phy,
                    aa: aa,
                    adv_mode: adv_mode,
                    adv_mac: adv_mac,
                    did: did,
                    sid: sid,
                    timeSpeed: nil,
                    status: nil,
                    opStatus: opStatus,
                    altPressure: altPressure?.description,
                    heightType: heightType,
                    horizAcc: horizAcc?.description,
                    vertAcc: vertAcc,
                    baroAcc: baroAcc?.description,
                    speedAcc: speedAcc?.description,
                    timestampAccuracy: timestamp_accuracy,
                    operator_id: operatorID,
                    operator_id_type: nil,
                    classification_type: nil,
                    operator_location_type: nil,
                    area_count: nil,
                    area_radius: nil,
                    area_ceiling: nil,
                    area_floor: nil,
                    advMode: nil,
                    txAdd: nil,
                    rxAdd: nil,
                    adLength: nil,
                    accessAddress: nil,
                    operatorAltGeo: operatorAltGeo?.description,
                    areaCount: nil,
                    areaRadius: nil,
                    areaCeiling: nil,
                    areaFloor: nil,
                    classification: classification?.description,
                    selfIdType: nil,
                    selfIdId: nil,
                    authType: nil,
                    authPage: nil,
                    authLength: nil,
                    authTimestamp: nil,
                    authData: nil,
                    isSpoofed: false,
                    spoofingDetails: nil,
                    rawMessage: buildRawMessage(mac, rssi, description)
                )
            }
        case "location_protocol", "op_status", "height_type", "ew_dir_segment",
            "speed_multiplier", "vertical_accuracy", "horizontal_accuracy",
            "baro_accuracy", "speed_accuracy", "timestamp", "timestamp_accuracy":
            handleLocationFields(elementName)
        case "operator_id", "operator_id_type", "aux_rssi", "channel", "phy",
            "aa", "adv_mode", "adv_mac", "did", "sid":
            handleTransmissionFields(elementName)
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
                    var droneRSSI: Int?
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
                            idType = basicId["id_type"] as? String ?? "Unknown"
                            droneId = id
                            droneMAC = basicId["MAC"] as? String ??
                            (aext?["AdvA"] as? String)?.components(separatedBy: " ").first
                            idType = basicId["id_type"] as? String ?? "Unknown"
                            if let uaTypeStr = basicId["ua_type"] as? String {
                                uaType = mapUAType(uaTypeStr)
                            }
                            droneRSSI = basicId["RSSI"] as? Int
                            
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
                            if let pilotLocation = system?["PilotLocation"] as? [String: Any] {
                                let pilotLat = pilotLocation["lat"] as? Double ?? 0.0
                                let pilotLon = pilotLocation["lon"] as? Double ?? 0.0
                                // Add pilot location to the message
                                cotMessage?.pilotLat = String(pilotLat)
                                cotMessage?.pilotLon = String(pilotLon)
                            }
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
                            alt: String(describing: pointAttributes["hae"] ?? "0.0"),
                            height: String(describing: location?["height_agl"] ?? "0.0"),
                            pilotLat: String(describing: system?["operator_lat"] ?? "0.0"),
                            pilotLon: String(describing: system?["operator_lon"] ?? "0.0"),
                            description: description,
                            uaType: uaType,
                            idType: idType,
                            mac: droneMAC ?? "",
                            rssi: droneRSSI,
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
                        let idType = basicId["id_type"] as? String ?? "Unknown"
                        let droneType = buildDroneType(json)
                        let location = json["Location/Vector Message"] as? [String: Any]
                        let system = json["System Message"] as? [String: Any]
                        let pilotLocation = system?["PilotLocation"] as? [String: Any]
                        let selfId = json["Self-ID Message"] as? [String: Any]
                        let pilotLat = String(describing: pilotLocation?["lat"] ?? "Unknown")
                        let pilotLon = String(describing: pilotLocation?["lon"] ?? "Unknown")
                        
                        // Skip if CAA Registration ID
                        guard idType != "CAA Assigned Registration ID" && idType != "None" else {
                            print("Skipping message with ID type: \(idType)")
                            return
                        }
                        
                        cotMessage = CoTViewModel.CoTMessage(
                            uid: id,
                            type: droneType,
                            lat: String(describing: location?["latitude"] ?? "0.0"),
                            lon: String(describing: location?["longitude"] ?? "0.0"),
                            speed: String(describing: location?["speed"] ?? "0.0"),
                            vspeed: String(describing: location?["vert_speed"] ?? "0.0"),
                            alt: String(describing: pointAttributes["hae"] ?? "0.0"),
                            height: String(describing: location?["height_agl"] ?? "0.0"),
                            pilotLat: pilotLat,
                            pilotLon: pilotLon,
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
                        "id_type": eventAttributes["id_type"] ?? "",
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
                    alt: pointAttributes["hae"] ?? "0.0",
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
        case "Speed", "VerticalSpeed", "Altitude", "Height":
            if parentElement == "LocationVector" {
                switch elementName {
                case "Speed":
                    cotMessage?.speed = currentValue
                case "VerticalSpeed":
                    cotMessage?.vspeed = currentValue
                case "Altitude":
                    cotMessage?.alt = currentValue
                case "Height":
                    cotMessage?.height = currentValue
                case _:
                    break
                }
            } else {
                switch elementName {
                case "Speed":
                    speed = currentValue
                case "VerticalSpeed":
                    vspeed = currentValue
                case "Altitude":
                    alt = currentValue
                case "Height":
                    height = currentValue
                case _:
                    break
                }
            }
        case "TimeSpeed", "status", "direction", "altPressure", "heightType",
            "horizAcc", "vertAcc", "baroAcc", "speedAcc":
            if parentElement == "LocationVector" {
                switch elementName {
                case "TimeSpeed":
                    cotMessage?.timeSpeed = currentValue
                case "status":
                    cotMessage?.status = currentValue
                case "direction":
                    cotMessage?.direction = currentValue
                case "ew_dir_segment":
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
                case _:
                    break
                }
            }
        case "Description":
            droneDescription = currentValue
        case "lat":
            switch parent {
            case "PilotLocation":
                pilotLat = currentValue
            default:
                break
            }
        case "lon":
            switch parent {
            case "PilotLocation":
                pilotLon = currentValue
            default:
                break
            }
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
        case "DeviceID":
            if cotMessage == nil {
                cotMessage = CoTViewModel.CoTMessage(
                    uid: currentValue,
                    type: eventAttributes["type"] ?? "",
                    lat: pointAttributes["lat"] ?? "0.0",
                    lon: pointAttributes["lon"] ?? "0.0",
                    speed: speed,
                    vspeed: vspeed,
                    alt: String(describing: pointAttributes["hae"] ?? "0.0"),
                    height: height,
                    pilotLat: pilotLat,
                    pilotLon: pilotLon,
                    description: droneDescription,
                    uaType: .helicopter,
                    idType: ((eventAttributes["type"]?.contains("-S")) != nil) ? "Serial Number (ANSI/CTA-2063-A)" :
                        ((eventAttributes["type"]?.contains("-R")) != nil) ? "CAA Registration ID" : "None",
                    mac: eventAttributes["MAC"],
                    rssi: 0,
                    rawMessage: [:]
                )
            } else {
                cotMessage?.uid = currentValue
            }
            
        case "MAC":
            if parent == "BasicID" {
                cotMessage?.mac = currentValue
                if var rawMessage = cotMessage?.rawMessage {
                    rawMessage["MAC"] = currentValue
                    cotMessage?.rawMessage = rawMessage
                }
            }
            
        case "RSSI":
            if parent == "BasicID" {
                cotMessage?.rssi = Int(currentValue)
                if var rawMessage = cotMessage?.rawMessage {
                    rawMessage["RSSI"] = currentValue
                    cotMessage?.rawMessage = rawMessage
                }
            }
        default:
            break
        }
    }
    
    private func parseTransmissionDetails(_ elementName: String) {
        switch elementName {
        case "Channel": cotMessage?.channel = Int(currentValue)
        case "PHY": cotMessage?.phy = Int(currentValue)
        case "AdvMode": cotMessage?.advMode = currentValue
        case "DID": cotMessage?.did = Int(currentValue)
        case "SID": cotMessage?.sid = Int(currentValue)
        case "TxAdd": cotMessage?.txAdd = Int(currentValue)
        case "RxAdd": cotMessage?.rxAdd = Int(currentValue)
        case "AdLength": cotMessage?.adLength = Int(currentValue)
        default: break
        }
    }
    
    private func handleLocationFields(_ elementName: String) {
        switch elementName {
        case "location_protocol": location_protocol = currentValue
        case "op_status": op_status = currentValue
        case "height_type": height_type = currentValue
        case "ew_dir_segment": ew_dir_segment = currentValue
        case "speed_multiplier": speed_multiplier = currentValue
        case "vertical_accuracy": vertical_accuracy = currentValue
        case "horizontal_accuracy": horizontal_accuracy = currentValue
        case "baro_accuracy": baro_accuracy = currentValue
        case "speed_accuracy": speed_accuracy = currentValue
        case "timestamp": timestamp = currentValue
        case "timestamp_accuracy": timestamp_accuracy = currentValue
        default: break
        }
    }
    
    private func handleTransmissionFields(_ elementName: String) {
        switch elementName {
        case "operator_id": operator_id = currentValue
        case "operator_id_type": operator_id_type = currentValue
        case "aux_rssi": aux_rssi = Int(currentValue)
        case "channel": channel = Int(currentValue)
        case "phy": phy = Int(currentValue)
        case "aa": aa = Int(currentValue)
        case "adv_mode": adv_mode = currentValue
        case "adv_mac": adv_mac = currentValue
        case "did": did = Int(currentValue)
        case "sid": sid = Int(currentValue)
        default: break
        }
    }
    
    private func buildRawMessage(_ mac: String?, _ rssi: Int?, _ desc: String?) -> [String: Any] {
        let raw: [String: Any] = [
            "mac": mac ?? "",
            "rssi": rssi ?? 0,
            "location_protocol": location_protocol ?? "",
            "op_status": op_status ?? "",
            "height_type": height_type ?? "",
            "ew_dir_segment": ew_dir_segment ?? "",
            "speed_multiplier": speed_multiplier ?? "",
            "vertical_accuracy": vertical_accuracy ?? "",
            "horizontal_accuracy": horizontal_accuracy ?? "",
            "baro_accuracy": baro_accuracy ?? "",
            "speed_accuracy": speed_accuracy ?? "",
            "timestamp": timestamp ?? "",
            "timestamp_accuracy": timestamp_accuracy ?? "",
            "operator_id": operator_id ?? "",
            "operator_id_type": operator_id_type ?? "",
            "aux_rssi": aux_rssi ?? 0,
            "channel": channel ?? 0,
            "phy": phy ?? 0,
            "aa": aa ?? 0,
            "adv_mode": adv_mode ?? "",
            "adv_mac": adv_mac ?? "",
            "did": did ?? 0,
            "sid": sid ?? 0
        ]
        return raw
    }
    
    private func buildIdType() -> String {
        if eventAttributes["type"]?.contains("-S") == true {
            return "Serial Number (ANSI/CTA-2063-A)"
        } else if eventAttributes["type"]?.contains("-R") == true {
            return "CAA Assigned Registration ID"
        }
        return "None"
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

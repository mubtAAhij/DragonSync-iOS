//
//  XMLParserDelegate.swift
//  WarDragon
//
//  Created by Luke on 11/18/24.
//

import Foundation

class CoTMessageParser: NSObject, XMLParserDelegate {
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
    
    var cotMessage: CoTViewModel.CoTMessage?
    
    func parseESP32Message(_ jsonData: [String: Any]) -> CoTViewModel.CoTMessage? {
        print("Starting ESP32 parsing")
        var droneType = "a-f-G-U"  // Base type
        
        // Process Basic ID and set type
        if let basicID = jsonData["Basic ID"] as? [String: Any],
           let id = basicID["id"] as? String {
            let droneId = "ESP32-\(id)" // TODO change back from ESP32 after tests
            
            // Set type based on ID type
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
                    droneType += "-O"  // Add operator location modifier
                }
            }
            
            var description = ""
            if let selfID = jsonData["Self-ID Message"] as? [String: Any] {
                description = selfID["text"] as? String ?? ""
            }
            
            // Add friendly designation
            droneType += "-F"
            
            print("Parsed ESP32 message - Type: \(droneType)")
            print("Location: \(lat), \(lon)")
            print("Speed: \(speed), VSpeed: \(vspeed)")
            print("Alt: \(alt), Height: \(height)")
            print("Pilot Location: \(pilotLat), \(pilotLon)")
            print("Description: \(description)")
            
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
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String : String] = [:]) {
        currentElement = elementName
        currentValue = ""
        messageContent = ""  // Reset message content for new elements
        
        elementStack.append(elementName)
        
        if elementName == "event" {
            eventAttributes = attributes
        } else if elementName == "point" {
            pointAttributes = attributes
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if currentElement == "message" {
            messageContent += string  // Preserve formatting for JSON
        } else {
            currentValue += string.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        let parent = elementStack.dropLast().last ?? ""
        
        switch elementName {
        case "message":
            // Try to parse ESP32 JSON message
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
                print("Found pilot lat: \(currentValue)")
            }
        case "lon":
            if parent == "PilotLocation" {
                pilotLon = currentValue
                print("Found pilot lon: \(currentValue)")
            }
        case "event":
            if cotMessage == nil {  // Only create if not already created from ESP32 format
                let lat = pointAttributes["lat"] ?? "0.0"
                let lon = pointAttributes["lon"] ?? "0.0"
                
                print("Creating standard format message with:")
                print("lat: \(lat), lon: \(lon)")
                print("speed: \(speed), vspeed: \(vspeed)")
                print("alt: \(alt), height: \(height)")
                print("pilotLat: \(pilotLat), pilotLon: \(pilotLon)")
                print("description: \(droneDescription)")
                
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
        
        elementStack.removeLast()
    }
}

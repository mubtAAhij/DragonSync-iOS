//
//  CoTViewModel.swift
//  WarDragon
//
//  Created by Luke on 11/18/24.
//

import Foundation
import Network
import UserNotifications
import CoreLocation


class CoTViewModel: ObservableObject {
    @Published var parsedMessages: [CoTMessage] = []
    @Published var droneSignatures: [DroneSignature] = []
    @Published var randomMacIdHistory: [String: Set<String>] = [:]
    private let signatureGenerator = DroneSignatureGenerator()
    private var spectrumViewModel: SpectrumData.SpectrumViewModel?
    private var zmqHandler: ZMQHandler?
    private var cotListener: NWListener?
    private var statusListener: NWListener?
    private var multicastConnection: NWConnection?
    private let multicastGroup = Settings.shared.multicastHost
    private let cotPortMC = UInt16(Settings.shared.multicastPort)
    private let statusPortZMQ = UInt16(Settings.shared.zmqStatusPort)
    private let listenerQueue = DispatchQueue(label: "CoTListenerQueue")
    private var statusViewModel = StatusViewModel()
    public var isListeningCot = false
    public var macIdHistory: [String: Set<String>] = [:]
    public var macProcessing: [String: Bool] = [:]
    private var lastNotificationTime: Date?
    private var macToCAA: [String: String] = [:]
    private var macToHomeLoc: [String: (lat: Double, lon: Double)] = [:]

    
    struct CoTMessage: Identifiable, Equatable {
        var id: String { uid }
        var caaRegistration: String?
        var uid: String
        var type: String
        
        // Basic location and movement
        var lat: String
        var lon: String
        var homeLat: String
        var homeLon: String
        var speed: String
        var vspeed: String
        var alt: String
        var height: String?
        var pilotLat: String
        var pilotLon: String
        var description: String
        var selfIDText: String
        var uaType: DroneSignature.IdInfo.UAType
        
        // Basic ID fields with protocol info
        var idType: String
        var protocolVersion: String?
        var mac: String?
        var rssi: Int?
        var manufacturer: String?
        
        // Location/Vector Message fields
        var location_protocol: String?
        var op_status: String?
        var height_type: String?
        var ew_dir_segment: String?
        var speed_multiplier: String?
        var direction: String?
        var geodetic_altitude: Double?
        var vertical_accuracy: String?
        var horizontal_accuracy: String?
        var baro_accuracy: String?
        var speed_accuracy: String?
        var timestamp: String?
        var timestamp_accuracy: String?
        
        // Multicast CoT specific fields
        var time: String?
        var start: String?
        var stale: String?
        var how: String?
        var ce: String?  // Circular error
        var le: String?  // Linear error
        var hae: String? // Height above ellipsoid
        
        // BT/WiFi transmission fields from ZMQ
        var aux_rssi: Int?
        var channel: Int?
        var phy: Int?
        var aa: Int?
        var adv_mode: String?
        var adv_mac: String?
        var did: Int?
        var sid: Int?
        
        // Extended Location fields
        var timeSpeed: String?
        var status: String?
        var opStatus: String?
        var altPressure: String?
        var heightType: String?
        var horizAcc: String?
        var vertAcc: String?
        var baroAcc: String?
        var speedAcc: String?
        var timestampAccuracy: String?
        
        
        // ZMQ Operator & System fields
        var operator_id: String?
        var operator_id_type: String?
        var classification_type: String?
        var operator_location_type: String?
        var area_count: String?
        var area_radius: String?
        var area_ceiling: String?
        var area_floor: String?
        var advMode: String?
        var txAdd: Int?
        var rxAdd: Int?
        var adLength: Int?
        var accessAddress: Int?
        
        // System Message fields
        var operatorAltGeo: String?
        var areaCount: String?
        var areaRadius: String?
        var areaCeiling: String?
        var areaFloor: String?
        var classification: String?
        
        // Self-ID fields
        var selfIdType: String?
        var selfIdId: String?
        
        // Auth Message fields
        var authType: String?
        var authPage: String?
        var authLength: String?
        var authTimestamp: String?
        var authData: String?
        
        // Spoof detection
        var isSpoofed: Bool = false
        var spoofingDetails: DroneSignatureGenerator.SpoofDetectionResult?
        
        // Data store
        func saveToStorage() {
            DroneStorageManager.shared.saveEncounter(self)
        }
        
        var formattedAltitude: String? {
            if let altValue = Double(alt), altValue != 0 {
                return String(format: "%.1f m MSL", altValue)
            }
            return nil
        }
        
        var formattedHeight: String? {
            if let heightValue = Double(height ?? ""), heightValue != 0 {
                return String(format: "%.1f m AGL", heightValue)
            }
            return nil
        }
        
        var rawMessage: [String: Any]
        
        static func == (lhs: CoTViewModel.CoTMessage, rhs: CoTViewModel.CoTMessage) -> Bool {
            return lhs.uid == rhs.uid &&
            lhs.caaRegistration == rhs.caaRegistration &&
            lhs.type == rhs.type &&
            lhs.lat == rhs.lat &&
            lhs.lon == rhs.lon &&
            lhs.speed == rhs.speed &&
            lhs.vspeed == rhs.vspeed &&
            lhs.alt == rhs.alt &&
            lhs.height == rhs.height &&
            lhs.pilotLat == rhs.pilotLat &&
            lhs.pilotLon == rhs.pilotLon &&
            lhs.description == rhs.description &&
            lhs.uaType == rhs.uaType &&
            lhs.idType == rhs.idType &&
            lhs.mac == rhs.mac &&
            lhs.rssi == rhs.rssi &&
            lhs.location_protocol == rhs.location_protocol &&
            lhs.op_status == rhs.op_status &&
            lhs.height_type == rhs.height_type &&
            lhs.speed_multiplier == rhs.speed_multiplier &&
            lhs.direction == rhs.direction &&
            lhs.vertical_accuracy == rhs.vertical_accuracy &&
            lhs.horizontal_accuracy == rhs.horizontal_accuracy &&
            lhs.baro_accuracy == rhs.baro_accuracy &&
            lhs.speed_accuracy == rhs.speed_accuracy &&
            lhs.timestamp == rhs.timestamp &&
            lhs.timestamp_accuracy == rhs.timestamp_accuracy &&
            lhs.operator_id == rhs.operator_id &&
            lhs.operator_id_type == rhs.operator_id_type &&
            lhs.aux_rssi == rhs.aux_rssi &&
            lhs.channel == rhs.channel &&
            lhs.phy == rhs.phy &&
            lhs.aa == rhs.aa &&
            lhs.adv_mode == rhs.adv_mode &&
            lhs.adv_mac == rhs.adv_mac &&
            lhs.did == rhs.did &&
            lhs.sid == rhs.sid &&
            lhs.type == rhs.type &&
            lhs.timeSpeed == rhs.timeSpeed &&
            lhs.status == rhs.status &&
            lhs.altPressure == rhs.altPressure &&
            lhs.heightType == rhs.heightType &&
            lhs.horizAcc == rhs.horizAcc &&
            lhs.vertAcc == rhs.vertAcc &&
            lhs.baroAcc == rhs.baroAcc &&
            lhs.speedAcc == rhs.speedAcc &&
            lhs.operatorAltGeo == rhs.operatorAltGeo &&
            lhs.areaCount == rhs.areaCount &&
            lhs.areaRadius == rhs.areaRadius &&
            lhs.areaCeiling == rhs.areaCeiling &&
            lhs.areaFloor == rhs.areaFloor &&
            lhs.classification == rhs.classification &&
            lhs.selfIdType == rhs.selfIdType &&
            lhs.selfIdId == rhs.selfIdId &&
            lhs.authType == rhs.authType &&
            lhs.authPage == rhs.authPage &&
            lhs.authLength == rhs.authLength &&
            lhs.authTimestamp == rhs.authTimestamp &&
            lhs.authData == rhs.authData &&
            lhs.isSpoofed == rhs.isSpoofed &&
            lhs.spoofingDetails?.isSpoofed == rhs.spoofingDetails?.isSpoofed &&
            lhs.spoofingDetails?.confidence == rhs.spoofingDetails?.confidence &&
            lhs.accessAddress == rhs.accessAddress &&
            lhs.mac == rhs.mac &&
            lhs.rssi == rhs.rssi &&
            lhs.lat == rhs.lat &&
            lhs.lon == rhs.lon &&
            lhs.speed == rhs.speed &&
            lhs.vspeed == rhs.vspeed &&
            lhs.alt == rhs.alt &&
            lhs.height == rhs.height &&
            lhs.op_status == rhs.op_status &&
            lhs.height_type == rhs.height_type &&
            lhs.direction == rhs.direction &&
            lhs.geodetic_altitude == rhs.geodetic_altitude
        }
        
        var coordinate: CLLocationCoordinate2D? {
            guard let latDouble = Double(lat),
                  let lonDouble = Double(lon) else {
                print("Failed to convert lat: \(lat) or lon: \(lon) to Double")
                return nil
            }
            return CLLocationCoordinate2D(latitude: latDouble, longitude: lonDouble)
        }
        
        func toDictionary() -> [String: Any] {
            var dict: [String: Any] = [
                "uid": self.uid,
                "id": self.id,
                "type": self.type,
                "lat": self.lat,
                "lon": self.lon,
                "latitude": self.lon,
                "longitude": self.lon,
                "speed": self.speed,
                "vspeed": self.vspeed,
                "alt": self.alt,
                "pilotLat": self.pilotLat,
                "pilotLon": self.pilotLon,
                "description": self.description,
                "selfIDText": self.selfIDText,
                "uaType": self.uaType, // Assuming `UAType` is an enum
                "idType": self.idType,
                "isSpoofed": self.isSpoofed,
                "rssi": self.rssi ?? 0.0,
                "mac": self.mac ?? "",
                "manufacturer": self.manufacturer ?? "",
                "op_status": self.op_status ?? "",
                "ew_dir_segment": self.ew_dir_segment ?? "",
                "direction": self.direction ?? "",
                "geodetic_altitude": self.geodetic_altitude ?? 0.0
            ]
            
            // Include optional fields if they exist
            dict["id"] = self.id
            dict["uid"] = self.uid
            dict["height"] = self.height
            dict["protocolVersion"] = self.protocolVersion
            dict["geodetic_altitude"] = self.geodetic_altitude
            dict["mac"] = self.mac
            dict["rssi"] = self.rssi
            dict["rssi"] = self.rssi
            dict["manufacturer"] = self.manufacturer
            dict["op_status"] = self.op_status
            dict["direction"] = self.direction
            dict["ew_dir_segment"] = self.ew_dir_segment
            dict["location_protocol"] = self.location_protocol
            dict["op_status"] = self.op_status
            dict["height_type"] = self.height_type
            dict["direction"] = self.direction
            dict["time"] = self.time
            dict["start"] = self.start
            dict["stale"] = self.stale
            dict["how"] = self.how
            dict["ce"] = self.ce
            dict["le"] = self.le
            dict["hae"] = self.hae
            dict["aux_rssi"] = self.aux_rssi
            dict["channel"] = self.channel
            dict["phy"] = self.phy
            dict["aa"] = self.aa
            dict["adv_mode"] = self.adv_mode
            dict["adv_mac"] = self.adv_mac
            dict["operator_id"] = self.operator_id
            dict["classification_type"] = self.classification_type
            dict["area_radius"] = self.area_radius
            dict["area_ceiling"] = self.area_ceiling
            dict["area_floor"] = self.area_floor
            
            return dict
        }
    }
    
    init(statusViewModel: StatusViewModel, spectrumViewModel: SpectrumData.SpectrumViewModel? = nil) {        self.statusViewModel = statusViewModel
        self.spectrumViewModel = spectrumViewModel
        self.checkPermissions()
    }
    
    private func checkPermissions() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            if settings.authorizationStatus != .authorized {
                self?.requestNotificationPermission()
            }
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            print("Notification permission granted: \(granted)")
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }
    
    func startListening() {
        // Prevent multiple starts
        guard !isListeningCot else { return }
        
        stopListening()  // Clean up any existing connections
        isListeningCot = true
        
        switch Settings.shared.connectionMode {
        case .multicast:
            startMulticastListening()
        case .zmq:
            startZMQListening()
        }
    }
    
    private func startMulticastListening() {
        let parameters = NWParameters.udp
        parameters.allowLocalEndpointReuse = true
        parameters.prohibitedInterfaceTypes = [.cellular]
        parameters.requiredInterfaceType = .wifi
        
        do {
            cotListener = try NWListener(using: parameters, on: NWEndpoint.Port(integerLiteral: cotPortMC))
            cotListener?.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    print("Multicast listener ready.")
                case .failed(let error):
                    print("Multicast listener failed: \(error)")
                case .cancelled:
                    print("Multicast listener cancelled.")
                default:
                    break
                }
            }
            
            cotListener?.newConnectionHandler = { [weak self] connection in
                connection.start(queue: self?.listenerQueue ?? .main)
                self?.receiveMessages(from: connection)
            }
            
            cotListener?.start(queue: listenerQueue)
        } catch {
            print("Failed to create multicast listener: \(error)")
        }
    }
    
    private func startZMQListening() {
        zmqHandler = ZMQHandler()
        
        zmqHandler?.connect(
            host: Settings.shared.zmqHost,
            zmqTelemetryPort: UInt16(Settings.shared.zmqTelemetryPort),
            zmqStatusPort: UInt16(Settings.shared.zmqStatusPort),
            onTelemetry: { [weak self] message in
                if let data = message.data(using: .utf8) {
                    self?.processIncomingMessage(data)
                }
            },
            onStatus: { [weak self] message in
                if let data = message.data(using: .utf8) {
                    self?.processIncomingMessage(data)
                }
            }
        )
    }
    
    private func processIncomingMessage(_ data: Data) {
        guard let message = String(data: data, encoding: .utf8) else { return }
        
        // Incoming Message (JSON/XML) - Determine type and convert if needed
        let xmlData: Data
        if message.trimmingCharacters(in: .whitespacesAndNewlines).starts(with: "{") {
            // Handle JSON input
            if message.contains("system_stats") {
                // Status JSON
                guard let statusXML = self.zmqHandler?.convertStatusToXML(message),
                      let convertedData = statusXML.data(using: String.Encoding.utf8) else { return }
                xmlData = convertedData
            } else if let jsonData = message.data(using: .utf8),
                      let parsedJson = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                      parsedJson["Basic ID"] != nil {
                // Drone JSON
                guard let droneXML = self.zmqHandler?.convertTelemetryToXML(message),
                      let convertedData = droneXML.data(using: String.Encoding.utf8) else { return }
                xmlData = convertedData
            } else {
                print("Unrecognized JSON format")
                return
            }
        } else {
            // Already XML
            xmlData = data
        }
        
        // Parse XML and create appropriate message
        let parser = CoTMessageParser()
        let xmlParser = XMLParser(data: xmlData)
        xmlParser.delegate = parser
        
        guard xmlParser.parse() else {
            print("Failed to parse XML: \(xmlData)")
            return
        }
        
        // Update UI with appropriate message type
        DispatchQueue.main.async {
            if message.contains("<remarks>CPU Usage:"),
               let statusMessage = parser.statusMessage {
                // Status message path
                self.updateStatusMessage(statusMessage)
            } else if let cotMessage = parser.cotMessage {
                // Drone message path
                self.updateMessage(cotMessage)
            }
        }
    }
    
    private func receiveMessages(from connection: NWConnection, isZMQ: Bool = false) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            
            defer {
                if !isComplete && (isZMQ ? self.zmqHandler?.isConnected == true : self.isListeningCot) {
                    self.receiveMessages(from: connection, isZMQ: isZMQ)
                } else {
                    connection.cancel()
                }
            }
            
            if let error = error {
                print("Error receiving data: \(error.localizedDescription)")
                return
            }
            
            guard let data = data, !data.isEmpty else {
                print("No data received.")
                return
            }
            
            if let message = String(data: data, encoding: .utf8) {
                //                print("DEBUG - Received data: \(message)")
                
                // Check for Status message first (has both status code type and remarks with CPU Usage)
                if message.contains("<remarks>CPU Usage:") {
                    print("Processing Status XML message")
                    let parser = XMLParser(data: data)
                    let cotParserDelegate = CoTMessageParser()
                    parser.delegate = cotParserDelegate
                    
                    if parser.parse(), let statusMessage = cotParserDelegate.statusMessage {
                        self.updateStatusMessage(statusMessage) // Use deduplication logic here
                    } else {
                        print("Failed to parse Status XML message.")
                    }
                    return
                }
                
                // If not a status message, check for JSON
                if message.trimmingCharacters(in: .whitespacesAndNewlines).starts(with: "{"),
                   let jsonData = message.data(using: .utf8),
                   let parsedJson = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                   parsedJson["Basic ID"] != nil {
                    print("Processing json message: \(message)")
                    let parser = CoTMessageParser()
                    if let parsedMessage = parser.parseESP32Message(parsedJson) {
                        DispatchQueue.main.async {
                            self.updateMessage(parsedMessage)
                        }
                    }
                    return
                }
                
                // Finally check for regular XML drone message
                if message.trimmingCharacters(in: .whitespacesAndNewlines).starts(with: "<") {
                    print("Processing XML Drone message: \(message)")
                    let parser = XMLParser(data: data)
                    let cotParserDelegate = CoTMessageParser()
                    parser.delegate = cotParserDelegate
                    
                    if parser.parse(), let cotMessage = cotParserDelegate.cotMessage {
                        DispatchQueue.main.async {
                            self.updateMessage(cotMessage)
                        }
                    } else {
                        print("Failed to parse Drone XML message.")
                    }
                    return
                }
                
                print("Unrecognized message format.")
            }
        }
    }
    //MARK: - Message Handling
    
    private func updateStatusMessage(_ message: StatusViewModel.StatusMessage) {
        DispatchQueue.main.async {
            if let index = self.statusViewModel.statusMessages.firstIndex(where: { $0.uid == message.uid }) {
                // Update existing status message
                self.statusViewModel.statusMessages[index] = message
                print("Updated existing status message: \(message)")
            } else {
                // Add new status message
                self.statusViewModel.statusMessages.append(message)
                self.sendStatusNotification(for: message)
            }
        }
    }
    
    private func updateMessage(_ message: CoTMessage) {
        DispatchQueue.main.async {
            let droneId = message.uid.hasPrefix("drone-") ? message.uid : "drone-\(message.uid)"
            let mac = message.mac ??
            (message.rawMessage["Basic ID"] as? [String: Any])?["MAC"] as? String ??
            (message.rawMessage["AUX_ADV_IND"] as? [String: Any])?["addr"] as? String
            
            // Skip NONE IDs
            if droneId.contains("NONE") {
                return
            }
            
            // Prepare updated message
            var updatedMessage = message
            updatedMessage.uid = droneId
            updatedMessage.mac = mac
            
            // Store CAA registration if present
            if let mac = mac, message.idType.contains("CAA") {
                self.macToCAA[mac] = message.id
            }
            
            // Store home location if valid
            if let mac = mac,
               let homeLat = Double(message.homeLat),
               let homeLon = Double(message.homeLon),
               homeLat != 0 && homeLon != 0 {
                self.macToHomeLoc[mac] = (lat: homeLat, lon: homeLon)
            }
            
            // Add stored home location if current message doesn't have one
            if let mac = mac,
               (Double(updatedMessage.homeLat) == 0 || Double(updatedMessage.homeLon) == 0),
               let homeLoc = self.macToHomeLoc[mac] {
                updatedMessage.homeLat = String(homeLoc.lat)
                updatedMessage.homeLon = String(homeLoc.lon)
            }
            
            // Generate signature (handle potential nil return)
            guard let signature = self.signatureGenerator.createSignature(from: updatedMessage.toDictionary()) else {
                // For CAA messages, we might want to do something different
                if message.idType.contains("CAA") {
                    // Special handling for CAA messages
                    self.handleCAAMessage(updatedMessage)
                }
                return
            }
            
            // Update signatures and encounters
            self.updateDroneSignaturesAndEncounters(signature, message: updatedMessage)
            
            // Track MAC history for this drone ID
            self.updateMACHistory(droneId: droneId, mac: mac)
            
            // Spoof detection
            self.performSpoofDetection(signature: signature, updatedMessage: &updatedMessage)
            
            // Core message update logic
            self.updateParsedMessages(updatedMessage: updatedMessage, signature: signature)
        }
    }

    private func updateDroneSignaturesAndEncounters(_ signature: DroneSignature, message: CoTMessage) {
        // Update drone signatures
        if let index = self.droneSignatures.firstIndex(where: { $0.primaryId.id == signature.primaryId.id }) {
            self.droneSignatures[index] = signature
            print("Updating existing signature")
        } else {
            print("Added new signature")
            self.droneSignatures.append(signature)
        }
        
        // Update encounters
        let encounters = DroneStorageManager.shared.encounters
        if encounters[signature.primaryId.id] != nil {
            let existing = encounters[signature.primaryId.id]!
            let hasNewPosition = existing.flightPath.last?.latitude != signature.position.coordinate.latitude ||
            existing.flightPath.last?.longitude != signature.position.coordinate.longitude ||
            existing.flightPath.last?.altitude != signature.position.altitude
            
            if hasNewPosition {
                DroneStorageManager.shared.saveEncounter(message)
                print("Updated existing encounter with new position")
            }
        } else {
            DroneStorageManager.shared.saveEncounter(message)
            print("Added new encounter to storage")
        }
    }

    private func updateMACHistory(droneId: String, mac: String?) {
        guard let mac = mac, !mac.isEmpty else { return }
        
        var macs = self.macIdHistory[droneId] ?? Set<String>()
        macs.insert(mac)
        if macs.count > 10 {
            macs.remove(macs.first!) // Remove oldest MAC
        }
        self.macIdHistory[droneId] = macs
    }

    private func performSpoofDetection(signature: DroneSignature, updatedMessage: inout CoTMessage) {
        guard Settings.shared.spoofDetectionEnabled,
              let monitorStatus = self.statusViewModel.statusMessages.last,
              let spoofResult = self.signatureGenerator.detectSpoof(signature, fromMonitor: monitorStatus) else {
            return
        }
        
        updatedMessage.isSpoofed = spoofResult.isSpoofed
        updatedMessage.spoofingDetails = spoofResult
        
        if let status = self.statusViewModel.statusMessages.last {
            let monitorLoc = CLLocation(
                latitude: status.gpsData.latitude,
                longitude: status.gpsData.longitude
            )
            self.signatureGenerator.updateMonitorLocation(monitorLoc)
        }
    }

    private func updateParsedMessages(updatedMessage: CoTMessage, signature: DroneSignature) {
        // Find existing message index by either ID or UID
        if let index = self.parsedMessages.firstIndex(where: { $0.id == updatedMessage.id || $0.uid == updatedMessage.uid }) {
            let existing = self.parsedMessages[index]
            
            // Determine if the message has meaningful changes
            let hasSignificantChanges = existing.rssi != updatedMessage.rssi ||
                existing.lat != updatedMessage.lat ||
                existing.lon != updatedMessage.lon ||
                existing.speed != updatedMessage.speed ||
                existing.vspeed != updatedMessage.vspeed ||
                existing.alt != updatedMessage.alt ||
                existing.height != updatedMessage.height ||
                existing.op_status != updatedMessage.op_status ||
                existing.height_type != updatedMessage.height_type ||
                existing.direction != updatedMessage.direction
            
            // Decide update strategy
            if existing.mac == updatedMessage.mac || updatedMessage.idType.contains("CAA") {
                // Update if same MAC or CAA message
                self.parsedMessages[index] = updatedMessage
                print("Updated existing drone: \(updatedMessage.uid)")
                self.objectWillChange.send()
            } else if existing.uid == updatedMessage.uid {
                // Preserve original MAC for same drone
                var finalMessage = updatedMessage
                finalMessage.mac = existing.mac
                self.parsedMessages[index] = finalMessage
                print("Updated drone preserving original MAC: \(updatedMessage.uid)")
                self.objectWillChange.send()
            }
        } else {
            // No existing message found - add new entry
            if !updatedMessage.idType.contains("CAA") {
                self.parsedMessages.append(updatedMessage)
                self.sendNotification(for: updatedMessage)
                print("Added new drone: \(updatedMessage.uid)")
            } else {
                print("Skipping CAA drone addition: \(updatedMessage.uid)")
            }
        }
    }

    private func handleCAAMessage(_ message: CoTMessage) {
        // Special handling for CAA messages that don't generate a signature
        if let mac = message.mac {
            // Update MAC to CAA mapping
            self.macToCAA[mac] = message.id
            
            // Find and update existing message with same MAC
            if let index = self.parsedMessages.firstIndex(where: { $0.mac == mac }) {
                var existingMessage = self.parsedMessages[index]
                existingMessage.caaRegistration = message.caaRegistration
                self.parsedMessages[index] = existingMessage
                print("Updated CAA registration for existing drone")
            }
        }
    }
    
    
    private func sendNotification(for message: CoTViewModel.CoTMessage) {
        guard Settings.shared.notificationsEnabled else { return }
        
        // Only send notification if more than 5 seconds have passed
        if let lastTime = lastNotificationTime,
           Date().timeIntervalSince(lastTime) < 5 {
            return
        }
        
        // Create and send notification
        let content = UNMutableNotificationContent()
        print("Attempting to send notification for drone: \(message.uid)")
        content.title = "Drone Detected"
        content.body = "From: \(message.uid)\nMAC: \(message.mac ?? "")"
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            } else {
                print("Successfully scheduled notification")
            }
        }
        
        lastNotificationTime = Date()
    }
    
    private func sendStatusNotification(for message: StatusViewModel.StatusMessage) {
        guard Settings.shared.notificationsEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = "System Status"
        let memAvail = message.systemStats.memory.available
        let memTotal = message.systemStats.memory.total
        let memoryUsed = memTotal - memAvail
        let percentageUsed = (Double(memoryUsed) / Double(memTotal)) * 100
        content.body = "CPU: \(String(format: "%.0f", message.systemStats.cpuUsage))%\nMemory: \(String(format: "%.0f", percentageUsed))%\nTemp: \(message.systemStats.temperature)°C"
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    func stopListening() {
        guard isListeningCot else { return }
        
        isListeningCot = false
        
        // Clean up multicast if using it
        multicastConnection?.cancel()
        multicastConnection = nil
        cotListener?.cancel()
        statusListener?.cancel()
        cotListener = nil
        statusListener = nil
        
        // Properly disconnect ZMQ if using it
        if let zmqHandler = zmqHandler {
            zmqHandler.disconnect()
            self.zmqHandler = nil
        }
        
        print("All listeners stopped and connections cleaned up.")
    }
    
}

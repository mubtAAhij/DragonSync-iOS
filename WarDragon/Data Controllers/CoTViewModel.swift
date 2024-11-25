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
    private var cotListener: NWListener?
    private var statusListener: NWListener?
    private let cotPortMC: UInt16 = 6969
    private let statusPortZMQ: UInt16 = 4225
    private let listenerQueue = DispatchQueue(label: "CoTListenerQueue")
    private var statusViewModel = StatusViewModel()
    public var isListeningCot = false
    
    struct CoTMessage: Identifiable, Equatable {
        var id: String { uid }
        var uid: String
        var type: String
        var lat: String
        var lon: String
        var speed: String
        var vspeed: String
        var alt: String
        var height: String
        var pilotLat: String
        var pilotLon: String
        var description: String
        
        var coordinate: CLLocationCoordinate2D? {
            guard let latDouble = Double(lat),
                  let lonDouble = Double(lon) else {
                print("Failed to convert lat: \(lat) or lon: \(lon) to Double")
                return nil
            }
            return CLLocationCoordinate2D(latitude: latDouble, longitude: lonDouble)
        }
    }
    
    init(statusViewModel: StatusViewModel) {
        self.statusViewModel = statusViewModel
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
        stopListening()
        isListeningCot = true
        
        let parameters = NWParameters.udp
        parameters.allowLocalEndpointReuse = true
        parameters.prohibitedInterfaceTypes = [.cellular]
        parameters.requiredInterfaceType = .wifi
        
        // Start CoT multicast listener
        if let nwPort = NWEndpoint.Port(rawValue: cotPortMC) {
            do {
                let listener = try NWListener(using: parameters, on: nwPort)
                setupListener(listener, port: cotPortMC)
            } catch let error {
                print("Failed to create listener on port \(cotPortMC): \(error.localizedDescription)")
            }
        }
    }
    
    private func setupListener(_ listener: NWListener?, port: UInt16) {
        listener?.stateUpdateHandler = { state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    print("Listener ready on port \(port)")
                case .failed(let error):
                    print("Listener failed on port \(port) with error: \(error.localizedDescription)")
                case .cancelled:
                    print("Listener cancelled on port \(port)")
                default:
                    break
                }
            }
        }
        
        listener?.newConnectionHandler = { [weak self] connection in
            connection.start(queue: self?.listenerQueue ?? .main)
            self?.receiveMessages(from: connection)  // Removed type parameter
        }
        
        listener?.start(queue: self.listenerQueue)
    }
    
    private func receiveMessages(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }

            defer {
                if !isComplete && self.isListeningCot {
                    self.receiveMessages(from: connection)
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
                print("Received data: \(message)")
                
                // 1. Check for XML Status message first
                if message.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("Received data: <?xml") &&
                   message.contains("<remarks>CPU Usage:") {
                    print("Processing Status XML message")
                    let rawXML = message.replacingOccurrences(of: "Received data: ", with: "")
                                      .trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if let xmlData = rawXML.data(using: .utf8) {
                        let parser = XMLParser(data: xmlData)
                        let cotParserDelegate = CoTMessageParser()
                        parser.delegate = cotParserDelegate
                        
                        if parser.parse(), let statusMessage = cotParserDelegate.statusMessage {
                            DispatchQueue.main.async {
                                self.statusViewModel.statusMessages.append(statusMessage)
                            }
                        } else {
                            print("Failed to parse Status XML message.")
                        }
                    }
                    return
                }
                
                // 2. Check for ESP32 JSON Drone message
                if message.trimmingCharacters(in: .whitespacesAndNewlines).starts(with: "{"),
                   let jsonData = message.data(using: .utf8),
                   let parsedJson = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                   parsedJson["Basic ID"] != nil {
                    print("Processing ESP32 Drone message")
                    let parser = CoTMessageParser()
                    if let parsedMessage = parser.parseESP32Message(parsedJson) {
                        DispatchQueue.main.async {
                            self.updateMessage(parsedMessage)
                        }
                    }
                    return
                }
                
                // 3. Check for XML Drone message
                if message.trimmingCharacters(in: .whitespacesAndNewlines).starts(with: "<") {
                    print("Processing XML Drone message")
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

    
    private func updateMessage(_ message: CoTMessage) {
        DispatchQueue.main.async {
            if let index = self.parsedMessages.firstIndex(where: { $0.uid == message.uid }) {
                // Update existing message
                self.parsedMessages[index] = message
                print("Updated existing drone: \(message.uid)")
            } else {
                // Add new message
                self.parsedMessages.append(message)
                print("Added new drone: \(message.uid)")
                self.sendNotification(for: message)
            }
        }
    }
    
    private func sendNotification(for message: CoTViewModel.CoTMessage) {
        let content = UNMutableNotificationContent()
        content.title = "New CoT Message"
        content.body = "From: \(message.uid)\nType: \(message.type)\nLocation: \(message.lat), \(message.lon)"
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    func stopListening() {
        isListeningCot = false
        cotListener?.cancel()
        statusListener?.cancel()
        cotListener = nil
        statusListener = nil
        print("Listeners stopped and ports released.")
    }
    
    func resetListener() {
        stopListening()
        parsedMessages.removeAll()
        startListening()
    }
}

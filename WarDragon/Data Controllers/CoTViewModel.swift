//
//  CoTViewModel.swift
//  WarDragon
//
//  Created by Luke on 11/18/24.
//
import Foundation
import Network
import UserNotifications
import Foundation
import Network
import UserNotifications
import CoreLocation

class CoTViewModel: ObservableObject {
    @Published var parsedMessages: [CoTMessage] = []
    private var listener: NWListener?
    private let port: UInt16 = 4225

    init() {
        checkPermissions()
    }
    
    private func checkPermissions() {
        // Check notification permission
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            if settings.authorizationStatus != .authorized {
                self?.requestNotificationPermission()
            }
        }
        
        // Check network permission
        let listener = try? NWListener(using: .udp)
        if listener == nil {
            requestLocalNetworkPermission()
        }
    }
    
    private func requestLocalNetworkPermission() {
        let listener = try? NWListener(using: .udp)
        listener?.start(queue: .main)
        listener?.cancel()
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            print("Notification permission granted: \(granted)")
        }
    }

    // Define CoTMessage struct within CoTViewModel
    struct CoTMessage: Identifiable, Equatable {
        let id = UUID()
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
        
        // Add a computed property for debugging
        var coordinate: CLLocationCoordinate2D? {
            guard let latDouble = Double(lat),
                  let lonDouble = Double(lon) else {
                print("Failed to convert lat: \(lat) or lon: \(lon) to Double") // Debug print
                return nil
            }
            return CLLocationCoordinate2D(latitude: latDouble, longitude: lonDouble)
        }
    }

    private let listenerQueue = DispatchQueue(label: "CoTListenerQueue")

    func startListening() {
        stopListening()

        let parameters = NWParameters.udp
        parameters.allowLocalEndpointReuse = true
        parameters.prohibitedInterfaceTypes = [.cellular]
        parameters.requiredInterfaceType = .wifi

        guard let port = NWEndpoint.Port(rawValue: self.port) else { return }

        do {
            self.listener = try NWListener(using: parameters, on: port)
        } catch let error {
            print("Failed to create listener: \(error.localizedDescription)")
            return
        }

        self.listener?.stateUpdateHandler = { state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    print("Listener ready on port \(self.port)")
                case .failed(let error):
                    print("Listener failed with error: \(error.localizedDescription)")
                case .cancelled:
                    print("Listener cancelled")
                default:
                    break
                }
            }
        }

        // Handle new connections
        self.listener?.newConnectionHandler = { connection in
            connection.start(queue: self.listenerQueue)
            self.receiveMessages(from: connection)
        }

        self.listener?.start(queue: self.listenerQueue)
    }

    private func receiveMessages(from connection: NWConnection) {
       connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
           guard let self = self else { return }
           
           if let error = error {
               print("Error receiving data: \(error.localizedDescription)")
               self.receiveMessages(from: connection)
               return
           }

           if let data = data, !data.isEmpty {
               if let jsonString = String(data: data, encoding: .utf8) {
                   print("Received data: \(jsonString)")
                   
                   do {
                       if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                           print("Successfully parsed JSON array")
                           
                           for jsonData in jsonArray {
                               if jsonData["Basic ID"] != nil {
                                   print("Processing ESP32 message from array")
                                   let parser = CoTMessageParser()
                                   if let parsedMessage = parser.parseESP32Message(jsonData) {
                                       DispatchQueue.main.async {
                                           print("Adding ESP32 message to parsed messages")
                                           self.parsedMessages.append(parsedMessage)
                                           self.sendNotification(for: parsedMessage)
                                       }
                                   }
                               }
                           }
                       } else if let jsonData = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                           print("Successfully parsed JSON object")
                           
                           if jsonData["Basic ID"] != nil {
                               print("Processing ESP32 message from object")
                               let parser = CoTMessageParser()
                               if let parsedMessage = parser.parseESP32Message(jsonData) {
                                   DispatchQueue.main.async {
                                       print("Adding ESP32 message to parsed messages")
                                       self.parsedMessages.append(parsedMessage)
                                       self.sendNotification(for: parsedMessage)
                                   }
                               }
                           }
                       }
                   } catch {
                       print("JSON parsing failed, trying XML: \(error)")
                       let parser = XMLParser(data: data)
                       let cotParserDelegate = CoTMessageParser()
                       parser.delegate = cotParserDelegate
                       
                       if parser.parse(), let parsedMessage = cotParserDelegate.cotMessage {
                           DispatchQueue.main.async {
                               self.parsedMessages.append(parsedMessage)
                               self.sendNotification(for: parsedMessage)
                           }
                       }
                   }
               }
           }
           
           if !isComplete {
               self.receiveMessages(from: connection) // Continue receiving messages for incomplete state
           } else {
               connection.cancel() // Properly close the connection for complete state
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

    private func parseCoTMessage(_ message: String) {
        // Check if message starts with '<' to identify XML
        if message.trimmingCharacters(in: .whitespacesAndNewlines).starts(with: "<") {
            // Skip JSON parsing attempt for XML messages
            let xmlData = message.data(using: .utf8)!
            let parser = XMLParser(data: xmlData)
            let cotParserDelegate = CoTMessageParser()
            parser.delegate = cotParserDelegate
            
            if parser.parse(), let parsedMessage = cotParserDelegate.cotMessage {
                DispatchQueue.main.async {
                    self.parsedMessages.append(parsedMessage)
                    // Add notification
                    let content = UNMutableNotificationContent()
                    content.title = "New CoT Message"
                    content.body = "From: \(parsedMessage.uid)\nType: \(parsedMessage.type)\nLocation: \(parsedMessage.lat), \(parsedMessage.lon)"
                    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                    UNUserNotificationCenter.current().add(request)
                }
            }
            return
        }
        
        // Try JSON parsing only for non-XML messages
        if let jsonData = message.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            
            // If we have Basic ID and Location fields, it's probably ESP32 format
            if dict["Basic ID"] != nil && dict["Location/Vector Message"] != nil {
                let parser = CoTMessageParser()
                if let parsedMessage = parser.parseESP32Message(dict) {
                    DispatchQueue.main.async {
                        self.parsedMessages.append(parsedMessage)
                        // Add notification
                        let content = UNMutableNotificationContent()
                        content.title = "New CoT Message"
                        content.body = "From: \(parsedMessage.uid)\nType: \(parsedMessage.type)\nLocation: \(parsedMessage.lat), \(parsedMessage.lon)"
                        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                        UNUserNotificationCenter.current().add(request)
                    }
                }
            }
        } else if let jsonData = message.data(using: .utf8),
                  let array = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] {
            // Handle array of messages
            for dict in array {
                if dict["Basic ID"] != nil && dict["Location/Vector Message"] != nil {
                    let parser = CoTMessageParser()
                    if let parsedMessage = parser.parseESP32Message(dict) {
                        DispatchQueue.main.async {
                            self.parsedMessages.append(parsedMessage)
                            // Add notification
                            let content = UNMutableNotificationContent()
                            content.title = "New CoT Message"
                            content.body = "From: \(parsedMessage.uid)\nType: \(parsedMessage.type)\nLocation: \(parsedMessage.lat), \(parsedMessage.lon)"
                            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                            UNUserNotificationCenter.current().add(request)
                        }
                    }
                }
            }
        }
    }
    
    private func setupListenerHandlers() {
        listener?.newConnectionHandler = { [weak self] connection in
            connection.start(queue: self?.listenerQueue ?? .main)
            self?.receiveMessages(from: connection)
        }
        
        listener?.stateUpdateHandler = { [weak self] state in
            if case .failed(let error) = state {
                print("Listener failed: \(error)")
                self?.resetListener()
            }
        }
    }

    func stopListening() {
        listener?.cancel()
        listener = nil
    }

    func resetListener() {
        stopListening()
        parsedMessages.removeAll()
        startListening()
    }
}

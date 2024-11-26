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
    private var zmqHandler: ZMQHandler?
    private var cotListener: NWListener?
    private var statusListener: NWListener?
    private var multicastConnection: NWConnection?
    private let multicastGroup = Settings.shared.multicastHost
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

        switch Settings.shared.connectionMode {
        case .multicast:
            startMulticastListening()
        case .zmq:
            startZMQListening()
        case .both:
            startMulticastListening()
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
        let zmqHost = Settings.shared.zmqHost
        let telemetryPort = UInt16(Settings.shared.zmqTelemetryPort)
        let statusPort = UInt16(Settings.shared.statusPort)

        zmqHandler?.connect(
            host: zmqHost,
            zmqTelemetryPort: telemetryPort,
            statusPort: statusPort,
            onTelemetry: { message in
                print("Received telemetry message: \(message)")
                // Process telemetry messages
            },
            onStatus: { message in
                print("Received status message: \(message)")
                // Process status messages
            }
        )
        print("ZMQ listeners started.")
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
                
                // Check for Status message first (has both status code type and remarks with CPU Usage)
                if message.contains("type=\"b-m-p-s-m\"") && message.contains("<remarks>CPU Usage:") {
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
                
                // If not a status message, check for ESP32 JSON
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
                
                // Finally check for regular XML drone message
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
    
    private func updateStatusMessage(_ message: StatusViewModel.StatusMessage) {
        DispatchQueue.main.async {
            if let index = self.statusViewModel.statusMessages.firstIndex(where: { $0.uid == message.uid }) {
                // Update existing status message
                self.statusViewModel.statusMessages[index] = message
                print("Updated existing status message: \(message.uid)")
            } else {
                // Add new status message
                self.statusViewModel.statusMessages.append(message)
                print("Added new status message: \(message.uid)")
            }
        }
    }
    
    private func updateMessage(_ message: CoTMessage) {
        DispatchQueue.main.async {
            if let index = self.parsedMessages.firstIndex(where: { $0.uid == message.uid }) {
                // Update existing message
                self.parsedMessages[index] = message
                print("Updated existing: \(message.uid)")
            } else {
                // Add new message
                self.parsedMessages.append(message)
                print("Added new: \(message.uid)")
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
        multicastConnection?.cancel()
        multicastConnection = nil
        cotListener?.cancel()
        statusListener?.cancel()
        cotListener = nil
        statusListener = nil
        zmqHandler?.disconnect()
        zmqHandler = nil
        print("Listeners stopped and ZMQ disconnected.")
    }
    
    func resetListener() {
        stopListening()
        parsedMessages.removeAll()
        startListening()
    }
}

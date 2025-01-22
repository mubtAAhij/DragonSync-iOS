//
//  DroneStorage.swift
//  WarDragon
//
//  Created by Luke on 1/21/25.
//

import Foundation
import CoreLocation

// Models
struct DroneEncounter: Codable, Identifiable, Hashable {
    let id: String
    let firstSeen: Date
    var lastSeen: Date
    var flightPath: [FlightPathPoint]
    var signatures: [SignatureData]
    var metadata: [String: String]
    
    var maxAltitude: Double {
        flightPath.map { $0.altitude }.max() ?? 0
    }
    
    var maxSpeed: Double {
        signatures.map { $0.speed }.max() ?? 0
    }
    
    var averageRSSI: Double {
        guard !signatures.isEmpty else { return 0 }
        return signatures.map { $0.rssi }.reduce(0, +) / Double(signatures.count)
    }
    
    var totalFlightTime: TimeInterval {
        lastSeen.timeIntervalSince(firstSeen)
    }
    
    static func == (lhs: DroneEncounter, rhs: DroneEncounter) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct FlightPathPoint: Codable, Hashable {
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let timestamp: TimeInterval
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct SignatureData: Codable, Hashable {
    let timestamp: TimeInterval
    let rssi: Double
    let speed: Double
    let height: Double
}

// Manager
class DroneStorageManager: ObservableObject {
    static let shared = DroneStorageManager()
    
    @Published private(set) var encounters: [String: DroneEncounter] = [:]
    
    init() {
        loadFromStorage()
    }
    
    func saveEncounter(_ signature: DroneSignature) {
        let droneId = signature.primaryId.id
        
        // Get or create encounter
        var encounter = encounters[droneId] ?? DroneEncounter(
            id: droneId,
            firstSeen: Date(),
            lastSeen: Date(),
            flightPath: [],
            signatures: [],
            metadata: [:]
        )
        
        // Update data
        encounter.lastSeen = Date()
        
        let point = FlightPathPoint(
            latitude: signature.position.coordinate.latitude,
            longitude: signature.position.coordinate.longitude,
            altitude: signature.position.altitude,
            timestamp: signature.timestamp
        )
        encounter.flightPath.append(point)
        
        let sig = SignatureData(
            timestamp: signature.timestamp,
            rssi: signature.transmissionInfo.signalStrength ?? 0,
            speed: signature.movement.groundSpeed,
            height: signature.heightInfo.heightAboveGround
        )
        encounter.signatures.append(sig)
        
        encounters[droneId] = encounter
        saveToStorage()
    }
    
    func deleteEncounter(id: String) {
        encounters.removeValue(forKey: id)
        UserDefaults.standard.set(try? JSONEncoder().encode(encounters), forKey: "DroneEncounters")
        saveToStorage()
    }
    
    func deleteAllEncounters() {
        encounters.removeAll()
        UserDefaults.standard.removeObject(forKey: "DroneEncounters")
        saveToStorage() // Optional, but ensures clean state
    }
    
    func saveToStorage() {
        if let data = try? JSONEncoder().encode(encounters) {
            UserDefaults.standard.set(data, forKey: "DroneEncounters")
        }
    }
    
    func loadFromStorage() {
        if let data = UserDefaults.standard.data(forKey: "DroneEncounters"),
           let loaded = try? JSONDecoder().decode([String: DroneEncounter].self, from: data) {
            encounters = loaded
        }
    }
}

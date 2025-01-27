//
//  DroneStorage.swift
//  WarDragon
//
//  Created by Luke on 1/21/25.
//

import Foundation
import CoreLocation
import UIKit


// Models
struct DroneEncounter: Codable, Identifiable, Hashable {
    let id: String
    let firstSeen: Date
    var lastSeen: Date
    var signatures: [SignatureData]
    var metadata: [String: String]
    private var _flightPath: [FlightPathPoint]
    
    // Computed property for flight path
    var flightPath: [FlightPathPoint] {
        get {
            return _flightPath
        }
        set {
            _flightPath = newValue
        }
    }
    
    // Initialize with private flight path
    init(id: String, firstSeen: Date, lastSeen: Date, flightPath: [FlightPathPoint], signatures: [SignatureData], metadata: [String: String]) {
        self.id = id
        self.firstSeen = firstSeen
        self.lastSeen = lastSeen
        self._flightPath = flightPath
        self.signatures = signatures
        self.metadata = metadata
    }
    
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

extension DroneEncounter {
    static func csvHeaders() -> String {
        return "First Seen,First Seen Latitude,First Seen Longitude,First Seen Altitude (m)," +
               "Last Seen,Last Seen Latitude,Last Seen Longitude,Last Seen Altitude (m)," +
               "ID,CAA Registration,MAC,Flight Path Points," +
               "Max Altitude (m),Max Speed (m/s),Average RSSI (dBm)," +
               "Flight Duration (HH:MM:SS),Height (m),Manufacturer"
    }
    
    func toCSVRow() -> String {
        var row = [String]()
        
        let formatter = ISO8601DateFormatter()
        
        // First seen data
        row.append(formatter.string(from: firstSeen))
        if let firstPoint = flightPath.first {
            row.append(String(format: "%.6f", firstPoint.latitude))
            row.append(String(format: "%.6f", firstPoint.longitude))
            row.append(String(format: "%.1f", firstPoint.altitude))
        } else {
            row.append(contentsOf: ["","",""])
        }
        
        // Last seen data
        row.append(formatter.string(from: lastSeen))
        if let lastPoint = flightPath.last {
            row.append(String(format: "%.6f", lastPoint.latitude))
            row.append(String(format: "%.6f", lastPoint.longitude))
            row.append(String(format: "%.1f", lastPoint.altitude))
        } else {
            row.append(contentsOf: ["","",""])
        }
        
        // Identifiers
        row.append(id)
        row.append(metadata["caaRegistration"] ?? "")
        row.append(metadata["mac"] ?? "")
        row.append(String(flightPath.count))
        
        // Flight stats
        row.append(String(format: "%.1f", maxAltitude))
        row.append(String(format: "%.1f", maxSpeed))
        row.append(String(format: "%.1f", averageRSSI))
        
        // Format flight duration as HH:MM:SS
        let duration = Int(totalFlightTime)
        let hours = duration / 3600
        let minutes = (duration % 3600) / 60
        let seconds = duration % 60
        row.append(String(format: "%02d:%02d:%02d", hours, minutes, seconds))
        
        // Height and manufacturer
        row.append(String(format: "%.1f", signatures.last?.height ?? 0.0))
        row.append(metadata["manufacturer"] ?? "")

        return row.joined(separator: ",")
    }
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
        
        // Update metadata with any new information
        if let mac = signature.transmissionInfo.macAddress {
            encounter.metadata["mac"] = mac
        }
        
        if let opID = signature.operatorId {
            encounter.metadata["operatorID"] = opID
        }
        
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
    
    func exportToCSV() -> String {
        var csv = DroneEncounter.csvHeaders() + "\n"
        
        for encounter in encounters.values {
            csv += encounter.toCSVRow() + "\n"
        }
        
        return csv
    }
    
    func shareCSV(from viewController: UIViewController? = nil) {
        // Build CSV content using our existing functions
        var csvContent = DroneEncounter.csvHeaders() + "\n"
        let sortedEncounters = encounters.values.sorted { $0.lastSeen > $1.lastSeen }
        
        for encounter in sortedEncounters {
            csvContent += encounter.toCSVRow() + "\n"
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let timestamp = dateFormatter.string(from: Date()).replacingOccurrences(of: ":", with: "_")
        let filename = "drone_encounters_\(timestamp).csv"
        
        // Create a temporary file URL to store the CSV data
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent(filename)
        
        // Write CSV data to the file
        do {
            try csvContent.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to write CSV data to file: \(error)")
            return
        }
        
        let csvDataItem = CSVDataItem(fileURL: fileURL, filename: filename)
        
        let activityVC = UIActivityViewController(
            activityItems: [csvDataItem],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            
            if UIDevice.current.userInterfaceIdiom == .pad {
                activityVC.popoverPresentationController?.sourceView = window
                activityVC.popoverPresentationController?.sourceRect = CGRect(
                    x: window.bounds.midX,
                    y: window.bounds.midY,
                    width: 0,
                    height: 0
                )
                activityVC.popoverPresentationController?.permittedArrowDirections = []
            }
            
            DispatchQueue.main.async {
                window.rootViewController?.present(activityVC, animated: true)
            }
        }
    }

    class CSVDataItem: NSObject, UIActivityItemSource {
        private let fileURL: URL
        private let filename: String
        
        init(fileURL: URL, filename: String) {
            self.fileURL = fileURL
            self.filename = filename
            super.init()
        }
        
        func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
            return fileURL
        }
        
        func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
            return fileURL
        }
        
        func activityViewController(_ activityViewController: UIActivityViewController, dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?) -> String {
            return "public.comma-separated-values-text"
        }
        
        func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
            return filename
        }
        
        func activityViewController(_ activityViewController: UIActivityViewController, filenameForActivityType activityType: UIActivity.ActivityType?) -> String {
            return filename
        }
    }


}

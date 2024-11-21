//
//  StatusViewModel.swift
//  WarDragon
//
//  Created by Luke on 11/18/24.
//

import Foundation
import CoreLocation

class StatusViewModel: ObservableObject {
    @Published var statusMessages: [StatusMessage] = []
    
    struct StatusMessage: Identifiable {
        let id = UUID()
        var serialNumber: String
        var runtime: Int
        var gpsData: GPSData
        var systemStats: SystemStats
        
        struct GPSData {
            var latitude: Double
            var longitude: Double
            var altitude: Double
            
            var coordinate: CLLocationCoordinate2D {
                CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            }
        }
        
        struct SystemStats {
            var cpuUsage: Double
            var memory: MemoryStats
            var disk: DiskStats
            var temperature: Double
            var uptime: Int
            
            struct MemoryStats {
                var total: Int64
                var available: Int64
            }
            
            struct DiskStats {
                var total: Int64
                var used: Int64
            }
        }
    }
    
    func handleStatusMessage(_ message: String) {
        if let data = message.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            
            guard let serialNumber = json["serial_number"] as? String,
                  let runtime = json["runtime"] as? Int,
                  let gpsData = json["gps_data"] as? [String: Any],
                  let systemStats = json["system_stats"] as? [String: Any],
                  let latitude = gpsData["latitude"] as? Double,
                  let longitude = gpsData["longitude"] as? Double,
                  let altitude = gpsData["altitude"] as? Double,
                  let cpuUsage = systemStats["cpu_usage"] as? Double,
                  let memory = systemStats["memory"] as? [String: Any],
                  let disk = systemStats["disk"] as? [String: Any],
                  let temperature = systemStats["temperature"] as? Double,
                  let uptime = systemStats["uptime"] as? Int,
                  let memTotal = memory["total"] as? Int64,
                  let memAvailable = memory["available"] as? Int64,
                  let diskTotal = disk["total"] as? Int64,
                  let diskUsed = disk["used"] as? Int64 else {
                print("Failed to parse status message fields")
                return
            }
            
            let statusMessage = StatusMessage(
                serialNumber: serialNumber,
                runtime: runtime,
                gpsData: .init(
                    latitude: latitude,
                    longitude: longitude,
                    altitude: altitude
                ),
                systemStats: .init(
                    cpuUsage: cpuUsage,
                    memory: .init(
                        total: memTotal,
                        available: memAvailable
                    ),
                    disk: .init(
                        total: diskTotal,
                        used: diskUsed
                    ),
                    temperature: temperature,
                    uptime: uptime
                )
            )
            
            DispatchQueue.main.async {
                if let index = self.statusMessages.firstIndex(where: { $0.serialNumber == serialNumber }) {
                    // Update the existing status message
                    self.statusMessages[index] = statusMessage
                    print("Updated status message for \(serialNumber)")
                } else {
                    // Add a new status message
                    self.statusMessages.append(statusMessage)
                    print("Added new status message for \(serialNumber)")
                }
            }
        }
    }
}

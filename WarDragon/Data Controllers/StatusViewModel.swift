//
//  StatusViewModel.swift
//  WarDragon
//
//  Created by Luke on 11/18/24.
//

import Foundation
import CoreLocation
import SwiftUI

class StatusViewModel: ObservableObject {
    @Published var statusMessages: [StatusMessage] = []
    
    struct StatusMessage: Identifiable {
        let id = UUID()
        var serialNumber: String
        var timestamp: Double
        var gpsData: GPSData
        var systemStats: SystemStats
        
        struct GPSData {
            var latitude: Double
            var longitude: Double
            var altitude: Double
            var speed: Double
            
            var coordinate: CLLocationCoordinate2D {
                CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            }
        }
        
        struct SystemStats {
            var cpuUsage: Double
            var memory: MemoryStats
            var disk: DiskStats
            var temperature: Double
            var uptime: Double
            
            struct MemoryStats {
                var total: Int64
                var available: Int64
                var percent: Double
                var used: Int64
                var free: Int64
                var active: Int64
                var inactive: Int64
                var buffers: Int64
                var cached: Int64
                var shared: Int64
                var slab: Int64
            }
            
            struct DiskStats {
                var total: Int64
                var used: Int64
                var free: Int64
                var percent: Double
            }
        }
    }
    
    func handleStatusMessage(_ message: String) {
        if let data = message.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            
            // Match the dragonsync.py output here for tests
            guard let serialNumber = json["serial_number"] as? String,
                  let timestamp = json["timestamp"] as? Double,
                  let gpsData = json["gps_data"] as? [String: Any],
                  let systemStats = json["system_stats"] as? [String: Any],
                  let latitude = gpsData["latitude"] as? Double,
                  let longitude = gpsData["longitude"] as? Double,
                  let altitude = gpsData["altitude"] as? Double,
                  let speed = gpsData["speed"] as? Double,
                  let cpuUsage = systemStats["cpu_usage"] as? Double,
                  let memory = systemStats["memory"] as? [String: Any],
                  let disk = systemStats["disk"] as? [String: Any],
                  let temperature = systemStats["temperature"] as? Double,
                  let uptime = systemStats["uptime"] as? Double else {
                print("Failed to parse status message fields")
                return
            }
            
            // Parse memory details
            guard let memTotal = memory["total"] as? Int64,
                  let memAvailable = memory["available"] as? Int64,
                  let memPercent = memory["percent"] as? Double,
                  let memUsed = memory["used"] as? Int64,
                  let memFree = memory["free"] as? Int64,
                  let memActive = memory["active"] as? Int64,
                  let memInactive = memory["inactive"] as? Int64,
                  let memBuffers = memory["buffers"] as? Int64,
                  let memCached = memory["cached"] as? Int64,
                  let memShared = memory["shared"] as? Int64,
                  let memSlab = memory["slab"] as? Int64 else {
                print("Failed to parse memory stats")
                return
            }
            
            // Parse disk details
            guard let diskTotal = disk["total"] as? Int64,
                  let diskUsed = disk["used"] as? Int64,
                  let diskFree = disk["free"] as? Int64,
                  let diskPercent = disk["percent"] as? Double else {
                print("Failed to parse disk stats")
                return
            }
            
            let statusMessage = StatusMessage(
                serialNumber: serialNumber,
                timestamp: timestamp,
                gpsData: .init(
                    latitude: latitude,
                    longitude: longitude,
                    altitude: altitude,
                    speed: speed
                ),
                systemStats: .init(
                    cpuUsage: cpuUsage,
                    memory: .init(
                        total: memTotal,
                        available: memAvailable,
                        percent: memPercent,
                        used: memUsed,
                        free: memFree,
                        active: memActive,
                        inactive: memInactive,
                        buffers: memBuffers,
                        cached: memCached,
                        shared: memShared,
                        slab: memSlab
                    ),
                    disk: .init(
                        total: diskTotal,
                        used: diskUsed,
                        free: diskFree,
                        percent: diskPercent
                    ),
                    temperature: temperature,
                    uptime: uptime
                )
            )
            
            DispatchQueue.main.async {
                if let index = self.statusMessages.firstIndex(where: { $0.serialNumber == serialNumber }) {
                    self.statusMessages[index] = statusMessage
                    print("Updated status message for \(serialNumber)")
                } else {
                    self.statusMessages.append(statusMessage)
                    print("Added new status message for \(serialNumber)")
                }
            }
        }
    }
}

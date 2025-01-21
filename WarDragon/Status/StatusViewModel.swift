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
    
    struct StatusMessage: Identifiable  {
        var id: String { uid }
        let uid: String
        var serialNumber: String
        var timestamp: Double
        var gpsData: GPSData
        var systemStats: SystemStats
        var antStats: ANTStats
        

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
        
        struct ANTStats {
            var plutoTemp: Double
            var zynqTemp: Double
        }
    }
}

extension StatusViewModel {
    func checkSystemThresholds() {
        guard Settings.shared.systemWarningsEnabled,
              let lastMessage = statusMessages.last else {
            return
        }
        
        // Check CPU usage
        if lastMessage.systemStats.cpuUsage > Settings.shared.cpuWarningThreshold {
            sendSystemNotification(
                title: "High CPU Usage",
                message: "CPU usage at \(Int(lastMessage.systemStats.cpuUsage))%"
            )
        }
        
        // Check system temperature
        if lastMessage.systemStats.temperature > Settings.shared.tempWarningThreshold {
            sendSystemNotification(
                title: "High System Temperature",
                message: "Temperature at \(Int(lastMessage.systemStats.temperature))°C"
            )
        }
        
        // Check memory usage
        let memoryUsage = Double(lastMessage.systemStats.memory.used) / Double(lastMessage.systemStats.memory.total)
        if memoryUsage > Settings.shared.memoryWarningThreshold {
            sendSystemNotification(
                title: "High Memory Usage",
                message: "Memory usage at \(Int(memoryUsage * 100))%"
            )
        }
        
        // Check ANTSDR temperatures
        if lastMessage.antStats.plutoTemp > Settings.shared.plutoTempThreshold {
            sendSystemNotification(
                title: "High Pluto Temperature",
                message: "Temperature at \(Int(lastMessage.antStats.plutoTemp))°C"
            )
        }
        
        if lastMessage.antStats.zynqTemp > Settings.shared.zynqTempThreshold {
            sendSystemNotification(
                title: "High Zynq Temperature",
                message: "Temperature at \(Int(lastMessage.antStats.zynqTemp))°C"
            )
        }
    }

    private func sendSystemNotification(title: String, message: String) {
        guard Settings.shared.notificationsEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
}

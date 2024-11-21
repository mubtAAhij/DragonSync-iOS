//
//  StatusMessageView.swift
//  WarDragon
//
//  Created by Luke on 11/18/24.
//

import SwiftUI
import MapKit

struct StatusMessageView: View {
    let message: StatusViewModel.StatusMessage
    @State private var showMap = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Header
            HStack {
                HStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("ONLINE")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.green)
                }
                Spacer()
                Text("UNIT: \(message.serialNumber)")
                    .font(.system(.headline, design: .monospaced))
                Spacer()
                Text("T+\(formatUptime(message.runtime))")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.orange)
            }
            .padding(8)
            .background(Color.black.opacity(0.8))
            
            HStack(spacing: 12) {
                // Left Column - System Stats
                VStack(alignment: .leading, spacing: 8) {
                    // CPU and Temperature
                    HStack(spacing: 16) {
                        GaugeView(
                            title: "CPU",
                            value: message.systemStats.cpuUsage,
                            maxValue: 100,
                            unit: "%",
                            color: gaugeColor(for: message.systemStats.cpuUsage)
                        )
                        GaugeView(
                            title: "TEMP",
                            value: message.systemStats.temperature,
                            maxValue: 100,
                            unit: "°C",
                            color: temperatureColor(message.systemStats.temperature)
                        )
                    }
                    
                    // Memory
                    let memUsedPercent = 100.0 * (1.0 - Double(message.systemStats.memory.available) / Double(message.systemStats.memory.total))
                    ResourceBar(
                        title: "MEM",
                        usedPercent: memUsedPercent,
                        details: formatMemory(total: message.systemStats.memory.total, available: message.systemStats.memory.available)
                    )
                    
                    // Disk
                    let diskUsedPercent = 100.0 * Double(message.systemStats.disk.used) / Double(message.systemStats.disk.total)
                    ResourceBar(
                        title: "DSK",
                        usedPercent: diskUsedPercent,
                        details: formatDisk(total: message.systemStats.disk.total, used: message.systemStats.disk.used)
                    )
                }
                .frame(maxWidth: .infinity)
                
                // Right Column - GPS Data
                VStack(alignment: .leading, spacing: 8) {
                    DataRow(title: "LAT", value: String(format: "%.6f°", message.gpsData.latitude))
                    DataRow(title: "LON", value: String(format: "%.6f°", message.gpsData.longitude))
                    DataRow(title: "ALT", value: String(format: "%.1fm", message.gpsData.altitude))
                }
                .frame(maxWidth: .infinity)
            }
            .padding(8)
            .background(Color.black.opacity(0.6))
            
            // Mini Map
            Map {
                Marker(message.serialNumber, coordinate: message.gpsData.coordinate)
                    .tint(.green)
            }
            .frame(height: 100)
            .overlay(
                Rectangle()
                    .strokeBorder(Color.green.opacity(0.5), lineWidth: 1)
            )
            .onTapGesture {
                showMap = true
            }
        }
        .background(Color.black.opacity(0.4))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.green.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func formatUptime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, remainingSeconds)
    }
    
    private func formatMemory(total: Int64, available: Int64) -> String {
        let totalGB = Double(total) / 1_073_741_824
        let availableGB = Double(available) / 1_073_741_824
        return String(format: "%.1f/%.1fGB", totalGB - availableGB, totalGB)
    }
    
    private func formatDisk(total: Int64, used: Int64) -> String {
        let totalGB = Double(total) / 1_073_741_824
        let usedGB = Double(used) / 1_073_741_824
        return String(format: "%.1f/%.1fGB", usedGB, totalGB)
    }
    
    private func gaugeColor(for value: Double) -> Color {
        switch value {
        case 0..<60: return .green
        case 60..<80: return .yellow
        default: return .red
        }
    }
    
    private func temperatureColor(_ temp: Double) -> Color {
        switch temp {
        case 0..<50: return .green
        case 50..<70: return .yellow
        default: return .red
        }
    }
}

struct GaugeView: View {
    let title: String
    let value: Double
    let maxValue: Double
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.gray)
            HStack(alignment: .bottom, spacing: 4) {
                Text(String(format: "%.1f", value))
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(color)
                Text(unit)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(color.opacity(0.8))
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(value / maxValue))
                }
            }
            .frame(height: 4)
        }
    }
}

struct ResourceBar: View {
    let title: String
    let usedPercent: Double
    let details: String
    
    var color: Color {
        switch usedPercent {
        case 0..<70: return .green
        case 70..<90: return .yellow
        default: return .red
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.gray)
                Spacer()
                Text(details)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(color)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(usedPercent / 100.0))
                }
            }
            .frame(height: 4)
        }
    }
}

struct DataRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.gray)
            Text(value)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.green)
        }
    }
}

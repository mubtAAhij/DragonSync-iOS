//
//  StatusMessageView.swift
//  WarDragon
//
//  Created by Luke on 11/18/24.
//

import SwiftUI
import MapKit
import CoreLocation

// MARK: - CircularGauge View
struct CircularGauge: View {
    let value: Double
    let maxValue: Double
    let title: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: CGFloat(value / maxValue))
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text(String(format: "%.1f", value))
                        .font(.system(.title2, design: .monospaced))
                        .foregroundColor(color)
                    Text(unit)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(color.opacity(0.8))
                }
            }
            .frame(width: 80, height: 80)
            Text(title)
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.gray)
        }
    }
}

// MARK: - ResourceBar View
struct ResourceBar: View {
    let title: String
    let usedPercent: Double
    let details: String
    let color: Color
    
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
            .cornerRadius(2)
        }
    }
}

// MARK: - LocationDataRow View
struct LocationDataRow: View {
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

// MARK: - MemoryDetailView
struct MemoryDetailView: View {
    let memory: StatusViewModel.StatusMessage.SystemStats.MemoryStats
    
    private func formatBytes(_ bytes: Int64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        return String(format: "%.1f GB", gb)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                CircularGauge(
                    value: memory.percent,
                    maxValue: 100,
                    title: "USED",
                    unit: "%",
                    color: memoryColor(percent: memory.percent)
                )
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Total: \(formatBytes(memory.total))")
                    Text("Available: \(formatBytes(memory.available))")
                    Text("Used: \(formatBytes(memory.used))")
                }
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.gray)
            }
            
            VStack(spacing: 8) {
                MemoryBarView(title: "Active", value: memory.active, total: memory.total, color: .blue)
                MemoryBarView(title: "Inactive", value: memory.inactive, total: memory.total, color: .purple)
                MemoryBarView(title: "Cached", value: memory.cached, total: memory.total, color: .orange)
                MemoryBarView(title: "Buffers", value: memory.buffers, total: memory.total, color: .green)
                MemoryBarView(title: "Shared", value: memory.shared, total: memory.total, color: .yellow)
                MemoryBarView(title: "Slab", value: memory.slab, total: memory.total, color: .red)
            }
        }
        .padding()
        .background(Color.black.opacity(0.6))
        .cornerRadius(12)
    }
    
    private func memoryColor(percent: Double) -> Color {
        switch percent {
        case 0..<60: return .green
        case 60..<80: return .yellow
        default: return .red
        }
    }
}

// MARK: - MemoryBarView
struct MemoryBarView: View {
    let title: String
    let value: Int64
    let total: Int64
    let color: Color
    
    private var percentage: Double {
        Double(value) / Double(total) * 100
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        return String(format: "%.1f GB", gb)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.gray)
                Spacer()
                Text(formatBytes(value))
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(color)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(percentage / 100))
                }
            }
            .frame(height: 4)
            .cornerRadius(2)
        }
    }
}

// MARK: - SystemStatsView
struct SystemStatsView: View {
    let stats: StatusViewModel.StatusMessage.SystemStats
    @State private var showingMemoryDetail = false
    
    var body: some View {
        VStack(spacing: 16) {
            // CPU and Temperature row
            HStack {
                CircularGauge(
                    value: stats.cpuUsage,
                    maxValue: 100,
                    title: "CPU",
                    unit: "%",
                    color: gaugeColor(for: stats.cpuUsage)
                )
                
                // Just show temperature if it's above zero
                if stats.temperature > 0 {
                    CircularGauge(
                        value: stats.temperature,
                        maxValue: 100,
                        title: "TEMP",
                        unit: "°C",
                        color: temperatureColor(stats.temperature)
                    )
                }
            }
            
            // Memory and Disk section
            VStack(spacing: 12) {
                Button(action: { showingMemoryDetail.toggle() }) {
                    ResourceBar(
                        title: "MEMORY",
                        usedPercent: stats.memory.percent,
                        details: formatMemory(stats.memory),
                        color: memoryColor(percent: stats.memory.percent)
                    )
                }
                
                ResourceBar(
                    title: "DISK",
                    usedPercent: stats.disk.percent,
                    details: formatDisk(stats.disk),
                    color: diskColor(percent: stats.disk.percent)
                )
            }
        }
        .sheet(isPresented: $showingMemoryDetail) {
            NavigationView {
                MemoryDetailView(memory: stats.memory)
                    .navigationTitle("Memory Details")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingMemoryDetail = false
                            }
                        }
                    }
            }
            .presentationDetents([.medium])
        }
    }
    
    // Formatting and color helper functions
        private func formatMemory(_ memory: StatusViewModel.StatusMessage.SystemStats.MemoryStats) -> String {
            let usedGB = Double(memory.used) / 1_073_741_824
            let totalGB = Double(memory.total) / 1_073_741_824
            return String(format: "%.1f/%.1fGB", usedGB, totalGB)
        }
        
        private func formatDisk(_ disk: StatusViewModel.StatusMessage.SystemStats.DiskStats) -> String {
            let usedGB = Double(disk.used) / 1_073_741_824
            let totalGB = Double(disk.total) / 1_073_741_824
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
        
        private func memoryColor(percent: Double) -> Color {
            switch percent {
            case 0..<70: return .green
            case 70..<85: return .yellow
            default: return .red
            }
        }
        
        private func diskColor(percent: Double) -> Color {
            switch percent {
            case 0..<75: return .green
            case 75..<90: return .yellow
            default: return .red
            }
        }
}

// MARK: - Main StatusMessageView
struct StatusMessageView: View {
    let message: StatusViewModel.StatusMessage
    
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
                Text(message.serialNumber)
                    .font(.system(.headline, design: .monospaced))
                Spacer()
                Text(formatUptime(message.systemStats.uptime))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.orange)
            }
            .padding(8)
            .background(Color.black.opacity(0.8))
            
            HStack(spacing: 16) {
                // System Stats
                SystemStatsView(stats: message.systemStats)
                    .frame(maxWidth: .infinity)
                
                // Location Data
                VStack(alignment: .trailing, spacing: 8) {
                    LocationDataRow(title: "LAT", value: String(format: "%.6f°", message.gpsData.latitude))
                    LocationDataRow(title: "LON", value: String(format: "%.6f°", message.gpsData.longitude))
                    LocationDataRow(title: "ALT", value: String(format: "%.1fm", message.gpsData.altitude))
                    LocationDataRow(title: "SPD", value: String(format: "%.1fm/s", message.gpsData.speed))
                }
                .frame(maxWidth: .infinity)
            }
            .padding(8)
            
            // Map
            Map {
                Marker(message.serialNumber, coordinate: message.gpsData.coordinate)
                    .tint(.green)
            }
            .frame(height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.green.opacity(0.3), lineWidth: 1)
            )
        }
        .background(Color.black.opacity(0.4))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.green.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func formatUptime(_ uptime: Double) -> String {
        let hours = Int(uptime) / 3600
        let minutes = Int(uptime) % 3600 / 60
        let seconds = Int(uptime) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

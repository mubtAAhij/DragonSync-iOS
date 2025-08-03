//
//  StatusMessageView.swift
//  WarDragon
//
//  Created by Luke on 11/18/24.
//

import SwiftUI
import MapKit
import CoreLocation

// MARK: - Sheet Types for Status View
enum StatusSheetType: Identifiable {
    case memory
    case map
    
    var id: String {
        switch self {
        case .memory: return "memory"
        case .map: return "map"
        }
    }
}

// MARK: - CircularGauge View
struct CircularGauge: View {
    let value: Double
    let maxValue: Double
    let title: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: CGFloat(min(value / maxValue, 1.0)))
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: value)
                
                VStack(spacing: 1) {
                    Text(String(format: "%.0f", value))
                        .font(.system(.title2, design: .monospaced))
                        .foregroundColor(color)
                        .fontWeight(.bold)
                    Text(unit)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 70, height: 70)
            
            Text(title)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .fontWeight(.medium)
        }
    }
}

// MARK: - ResourceBar View
struct ResourceBar: View {
    let title: String
    let usedPercent: Double
    let details: String
    let color: Color
    let isInteractive: Bool
    let action: (() -> Void)?
    
    init(title: String, usedPercent: Double, details: String, color: Color, isInteractive: Bool = false, action: (() -> Void)? = nil) {
        self.title = title
        self.usedPercent = usedPercent
        self.details = details
        self.color = color
        self.isInteractive = isInteractive
        self.action = action
    }
    
    var body: some View {
        Button(action: action ?? {}) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title.uppercased())
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text(String(format: "%.1f%%", usedPercent))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(color)
                        .fontWeight(.bold)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [color.opacity(0.8), color]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * CGFloat(min(usedPercent / 100, 1.0)))
                            .animation(.easeInOut(duration: 0.3), value: usedPercent)
                    }
                }
                .frame(height: 8)
                
                Text(details)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isInteractive, let action = action {
                action()
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - StatusMessageView with Adaptive Layout
struct StatusMessageView: View {
    let message: StatusViewModel.StatusMessage
    @ObservedObject var statusViewModel: StatusViewModel
    @State private var activeSheet: StatusSheetType?
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    init(message: StatusViewModel.StatusMessage, statusViewModel: StatusViewModel) {
        self.message = message
        self.statusViewModel = statusViewModel
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Status Header
            statusHeader
            
            // Adaptive Content Layout
            if horizontalSizeClass == .regular {
                // iPad Layout - Horizontal
                iPadLayout
            } else {
                // iPhone Layout - Vertical
                iPhoneLayout
            }
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
        .sheet(item: $activeSheet) { sheetType in
            switch sheetType {
            case .memory:
                MemoryDetailView(memory: message.systemStats.memory)
            case .map:
                MapDetailView(coordinate: message.gpsData.coordinate)
            }
        }
    }
    
    // MARK: - Status Header
    private var statusHeader: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(statusViewModel.statusColor)
                        .frame(width: 12, height: 12)
                        .scaleEffect(statusViewModel.isSystemOnline ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.3), value: statusViewModel.isSystemOnline)
                    
                    Text(statusViewModel.statusText)
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundColor(statusViewModel.statusColor)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                Text(message.serialNumber)
                    .font(.system(.headline, design: .monospaced))
                    .foregroundColor(.primary)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text(formatUptime(message.systemStats.uptime))
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundColor(.secondary)
                    .fontWeight(.medium)
            }
            
            // Last Received Status Row
            HStack {
                Text(String(localized: "last_received", comment: "Last received status label"))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(statusViewModel.lastReceivedText)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(statusViewModel.isSystemOnline ? .green : .red)
                    .fontWeight(.bold)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    statusViewModel.statusColor.opacity(0.15),
                    statusViewModel.statusColor.opacity(0.08)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }
    
    // MARK: - iPad Layout (Horizontal)
    private var iPadLayout: some View {
        VStack(spacing: 20) {
            // System Metrics Row (Full Width)
            HStack(alignment: .top, spacing: 20) {
                // Left Column - CPU and Temperature dials
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader(String(localized: "system_metrics", comment: "System metrics section header"), icon: "cpu")
                    
                    HStack(spacing: 16) {
                        CircularGauge(
                            value: message.systemStats.cpuUsage,
                            maxValue: 100,
                            title: String(localized: "cpu", comment: "CPU gauge label"),
                            unit: "%",
                            color: cpuColor(message.systemStats.cpuUsage)
                        )
                        
                        CircularGauge(
                            value: message.systemStats.temperature,
                            maxValue: 100,
                            title: String(localized: "temp", comment: "Temperature gauge label"),
                            unit: "°C",
                            color: temperatureColor(message.systemStats.temperature)
                        )
                        
                        if message.antStats.plutoTemp > 0 {
                            CircularGauge(
                                value: message.antStats.plutoTemp,
                                maxValue: 100,
                                title: String(localized: "pluto", comment: "Pluto temperature gauge label"),
                                unit: "°C",
                                color: temperatureColor(message.antStats.plutoTemp)
                            )
                        }
                        
                        if message.antStats.zynqTemp > 0 {
                            CircularGauge(
                                value: message.antStats.zynqTemp,
                                maxValue: 100,
                                title: String(localized: "zynq", comment: "Zynq temperature gauge label"),
                                unit: "°C",
                                color: temperatureColor(message.antStats.zynqTemp)
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Right Column - Resource Bars
                VStack(spacing: 12) {
                    ResourceBar(
                        title: String(localized: "memory", comment: "Memory usage label"),
                        usedPercent: memoryUsagePercent,
                        details: "\(formatBytes(message.systemStats.memory.total - message.systemStats.memory.available)) / \(formatBytes(message.systemStats.memory.total))",
                        color: memoryColor(memoryUsagePercent),
                        isInteractive: true,
                        action: { activeSheet = .memory }
                    )
                    
                    ResourceBar(
                        title: String(localized: "disk", comment: "Disk usage label"),
                        usedPercent: diskUsagePercent,
                        details: "\(formatBytes(message.systemStats.disk.used)) / \(formatBytes(message.systemStats.disk.total))",
                        color: diskColor(diskUsagePercent),
                        isInteractive: false
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Location and Map Section (Full Width)
            VStack(alignment: .leading, spacing: 12) {
                // Location header and details - FULL WIDTH
                expandedLocationSection
                
                // Map Preview
                mapPreviewSection
            }
        }
        .padding(20)
    }
    
    private var expandedLocationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(String(localized: "location_system_status", comment: "Location and system status section header"), icon: "location")
            
            // Full-width location and system details
            HStack(spacing: 20) {
                // Location Details
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(String(localized: "coordinates", comment: "GPS coordinates label"))
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                            .fontWeight(.medium)
                        Spacer()
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Button(action: { activeSheet = .map }) {
                            HStack {
                                Text(String(format: "%.6f°", message.gpsData.latitude))
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.primary)
                                    .fontWeight(.medium)
                                
                                Image(systemName: "location")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                        .buttonStyle(.plain)
                        
                        Text(String(format: "%.6f°", message.gpsData.longitude))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.primary)
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text(String(localized: "alt_label", comment: "Altitude label"))
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                        Text("\(String(format: "%.1f", message.gpsData.altitude))m")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text("Speed:")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                        Text("\(String(format: "%.1f", message.gpsData.speed)) m/s")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // System Status Summary
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(String(localized: "system_status", comment: "System status section header"))
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                            .fontWeight(.medium)
                        Spacer()
                    }
                    
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: "cpu", comment: "CPU gauge label"))
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.secondary)
                            Text("\(String(format: "%.1f", message.systemStats.cpuUsage))%")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(cpuColor(message.systemStats.cpuUsage))
                                .fontWeight(.bold)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: "temp", comment: "Temperature gauge label"))
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.secondary)
                            Text("\(String(format: "%.1f", message.systemStats.temperature))°C")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(temperatureColor(message.systemStats.temperature))
                                .fontWeight(.bold)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: "uptime", comment: "System uptime label"))
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.secondary)
                            Text(formatUptime(message.systemStats.uptime))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.blue)
                                .fontWeight(.bold)
                        }
                    }
                    
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: "memory", comment: "Memory usage label"))
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.secondary)
                            Text("\(String(format: "%.1f", memoryUsagePercent))%")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(memoryColor(memoryUsagePercent))
                                .fontWeight(.bold)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: "disk", comment: "Disk usage label"))
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.secondary)
                            Text("\(String(format: "%.1f", message.systemStats.disk.percent))%")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(diskColor(message.systemStats.disk.percent))
                                .fontWeight(.bold)
                        }
                        
                        if message.antStats.plutoTemp > 0 {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(localized: "pluto", comment: "Pluto temperature gauge label"))
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundColor(.secondary)
                                Text("\(String(format: "%.1f", message.antStats.plutoTemp))°C")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(temperatureColor(message.antStats.plutoTemp))
                                    .fontWeight(.bold)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
        }
    }
    
    // MARK: - iPhone Layout (Vertical)
    private var iPhoneLayout: some View {
        VStack(spacing: 20) {
            HStack(alignment: .top, spacing: 16) {
                // System Metrics Column
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader(String(localized: "system_metrics", comment: "System metrics section header"), icon: "cpu")
                    
                    // Dials in 2x2 grid for iPhone
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                        CircularGauge(
                            value: message.systemStats.cpuUsage,
                            maxValue: 100,
                            title: String(localized: "cpu", comment: "CPU gauge label"),
                            unit: "%",
                            color: cpuColor(message.systemStats.cpuUsage)
                        )
                        
                        CircularGauge(
                            value: message.systemStats.temperature,
                            maxValue: 100,
                            title: String(localized: "temp", comment: "Temperature gauge label"),
                            unit: "°C",
                            color: temperatureColor(message.systemStats.temperature)
                        )
                        
                        if message.antStats.plutoTemp > 0 {
                            CircularGauge(
                                value: message.antStats.plutoTemp,
                                maxValue: 100,
                                title: String(localized: "pluto", comment: "Pluto temperature gauge label"),
                                unit: "°C",
                                color: temperatureColor(message.antStats.plutoTemp)
                            )
                        }
                        
                        if message.antStats.zynqTemp > 0 {
                            CircularGauge(
                                value: message.antStats.zynqTemp,
                                maxValue: 100,
                                title: String(localized: "zynq", comment: "Zynq temperature gauge label"),
                                unit: "°C",
                                color: temperatureColor(message.antStats.zynqTemp)
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Resource Bars (Full Width)
            VStack(spacing: 12) {
                ResourceBar(
                    title: String(localized: "memory", comment: "Memory usage label"),
                    usedPercent: memoryUsagePercent,
                    details: "\(formatBytes(message.systemStats.memory.total - message.systemStats.memory.available)) / \(formatBytes(message.systemStats.memory.total))",
                    color: memoryColor(memoryUsagePercent),
                    isInteractive: true,
                    action: { activeSheet = .memory }
                )
                
                ResourceBar(
                    title: String(localized: "disk", comment: "Disk usage label"),
                    usedPercent: diskUsagePercent,
                    details: "\(formatBytes(message.systemStats.disk.used)) / \(formatBytes(message.systemStats.disk.total))",
                    color: diskColor(diskUsagePercent),
                    isInteractive: false
                )
            }
            
            // Map Preview
            mapPreviewSection
        }
        .padding(20)
    }
    
    // MARK: - Shared Components
    
    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(.caption, weight: .bold))
                .foregroundColor(.blue)
            
            Text(title)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .fontWeight(.bold)
        }
    }
    
    private var mapPreviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(String(localized: "map_view", comment: "Map view section header"), icon: "map")
            
            Button(action: { activeSheet = .map }) {
                ZStack {
                    // Compact map preview
                    Map {
                        Marker(message.serialNumber, coordinate: message.gpsData.coordinate)
                            .tint(.blue)
                    }
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .allowsHitTesting(false) // Prevent map interaction, let button handle tap
                    
                    // Overlay with essential coordinates only
                    VStack {
                        Spacer()
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(String(format: "%.4f°", message.gpsData.latitude)), \(String(format: "%.4f°", message.gpsData.longitude))")
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundColor(.white)
                                    .fontWeight(.bold)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        .padding(8)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.black.opacity(0.0), Color.black.opacity(0.7)]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                }
            }
            .buttonStyle(.plain)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.blue.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Computed Properties
    private var memoryUsagePercent: Double {
        guard message.systemStats.memory.total > 0 else { return 0 }
        let used = message.systemStats.memory.total - message.systemStats.memory.available
        return Double(used) / Double(message.systemStats.memory.total) * 100
    }
    
    private var diskUsagePercent: Double {
        guard message.systemStats.disk.total > 0 else { return 0 }
        // Use the percent field directly if it's available and non-zero
        if message.systemStats.disk.percent > 0 {
            return message.systemStats.disk.percent
        }
        // Fallback to calculation
        return Double(message.systemStats.disk.used) / Double(message.systemStats.disk.total) * 100
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        if bytes >= 1_073_741_824 { // GB
            return String(format: "%.1f GB", Double(bytes) / 1_073_741_824)
        } else if bytes >= 1_048_576 { // MB
            return String(format: "%.0f MB", Double(bytes) / 1_048_576)
        } else {
            return String(format: "%.0f KB", Double(bytes) / 1024)
        }
    }
    
    private func formatUptime(_ uptime: Double) -> String {
        let hours = Int(uptime) / 3600
        let minutes = (Int(uptime) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func cpuColor(_ usage: Double) -> Color {
        switch usage {
        case 0..<60: return .green
        case 60..<80: return .yellow
        default: return .red
        }
    }
    
    private func memoryColor(_ percent: Double) -> Color {
        switch percent {
        case 0..<70: return .green
        case 70..<85: return .yellow
        default: return .red
        }
    }
    
    private func diskColor(_ percent: Double) -> Color {
        switch percent {
        case 0..<70: return .green
        case 50..<80: return .orange
        default: return .red
        }
    }
    
    private func temperatureColor(_ temp: Double) -> Color {
        switch temp {
        case 0..<60: return .green
        case 60..<75: return .yellow
        default: return .red
        }
    }
}

// MARK: - LocationStatsView
struct LocationStatsView: View {
    let gpsData: StatusViewModel.StatusMessage.GPSData
    let onLocationTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onLocationTap) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(format: "%.6f°", gpsData.latitude))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.primary)
                        .fontWeight(.medium)
                    
                    Text(String(format: "%.6f°", gpsData.longitude))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.primary)
                        .fontWeight(.medium)
                }
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(String(localized: "alt_label", comment: "Altitude label"))
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.secondary)
                    Text("\(String(format: "%.1f", gpsData.altitude))m")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.primary)
                }
                
                HStack {
                    Text("Speed:")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.secondary)
                    Text("\(String(format: "%.1f", gpsData.speed)) m/s")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.primary)
                }
            }
        }
    }
}

// MARK: - Detail Views
struct MemoryDetailView: View {
    let memory: StatusViewModel.StatusMessage.SystemStats.MemoryStats
    
    
    var body: some View {
        NavigationView {
            List {
                Section(String(localized: "memory_usage", comment: "Memory usage title")) {
                    MemoryBarView(title: String(localized: "total", comment: "Total memory label"), value: memory.total, total: memory.total, color: .blue)
                    MemoryBarView(title: String(localized: "memory_used", comment: "Memory usage label"), value: memory.used > 0 ? memory.used : (memory.total - memory.available), total: memory.total, color: .red)
                    MemoryBarView(title: String(localized: "memory_available", comment: "Available memory label"), value: memory.available, total: memory.total, color: .green)
                    MemoryBarView(title: String(localized: "memory_free", comment: "Free memory label"), value: memory.free, total: memory.total, color: .green)
                    MemoryBarView(title: String(localized: "memory_active", comment: "Active memory label"), value: memory.active, total: memory.total, color: .orange)
                    MemoryBarView(title: String(localized: "memory_inactive", comment: "Inactive memory label"), value: memory.inactive, total: memory.total, color: .yellow)
                    MemoryBarView(title: String(localized: "memory_buffers", comment: "Memory buffers label"), value: memory.buffers, total: memory.total, color: .purple)
                    MemoryBarView(title: String(localized: "memory_cached", comment: "Cached memory label"), value: memory.cached, total: memory.total, color: .cyan)
                    MemoryBarView(title: String(localized: "memory_shared", comment: "Shared memory label"), value: memory.shared, total: memory.total, color: .pink)
                    MemoryBarView(title: String(localized: "memory_slab", comment: "Slab memory label"), value: memory.slab, total: memory.total, color: .indigo)
                }
            }
            .navigationTitle(String(localized: "memory_details", comment: "Memory details section title"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct MemoryBarView: View {
    let title: String
    let value: Int64
    let total: Int64
    let color: Color
    
    private var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(value) / Double(total) * 100
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        return String(format: "%.2f GB", gb)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title.uppercased())
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(formatBytes(value))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(color)
                    .fontWeight(.medium)
                
                Text("(\(String(format: "%.1f", percentage))%)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.2))
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(percentage / 100))
                }
            }
            .frame(height: 6)
        }
    }
}

struct MapDetailView: View {
    let coordinate: CLLocationCoordinate2D
    @State private var region: MKCoordinateRegion
    @Environment(\.dismiss) private var dismiss
    
    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
        self._region = State(initialValue: MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
    }
    
    var body: some View {
        NavigationView {
            Map(coordinateRegion: $region, annotationItems: [MapPoint(coordinate: coordinate)]) { point in
                MapPin(coordinate: point.coordinate, tint: .red)
            }
            .navigationTitle(String(localized: "system_location", comment: "System location title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(String(localized: "done", comment: "Done button")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct MapPoint: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

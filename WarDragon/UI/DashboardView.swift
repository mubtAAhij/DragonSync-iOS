//
//  DashboardView.swift
//  WarDragon
//
//  Created by Luke on 1/20/25.
//

import Foundation
import SwiftUI
import UIKit


struct DashboardView: View {
    @ObservedObject var statusViewModel: StatusViewModel
    @ObservedObject var cotViewModel: CoTViewModel
    @ObservedObject var spectrumViewModel: SpectrumData.SpectrumViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // System Status Card
                SystemStatusCard(statusViewModel: statusViewModel)
                
                // Active Drones Card
                DronesOverviewCard(cotViewModel: cotViewModel)
                
                // SDR Status Card
                SDRStatusCard(
                    statusViewModel: statusViewModel,
                    spectrumViewModel: spectrumViewModel
                )
                
                // Warnings Card
                WarningsCard(
                    statusViewModel: statusViewModel,
                    cotViewModel: cotViewModel
                )
            }
            .padding()
        }
    }
}

struct SystemStatusCard: View {
    @ObservedObject var statusViewModel: StatusViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "cpu")
                    .foregroundColor(.green)
                Text("SYSTEM STATUS")
                    .font(.appHeadline)
                Spacer()
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
            }
            
            // Metrics row with circular gauges
            HStack(spacing: 16) {
                CircularGauge(
                    value: statusViewModel.statusMessages.last?.systemStats.cpuUsage ?? 0,
                    maxValue: 100,
                    title: "CPU",
                    unit: "%",
                    color: cpuColor
                )
                
                CircularGauge(
                    value: memoryUsagePercent,
                    maxValue: 100,
                    title: "MEM",
                    unit: "%",
                    color: memoryColor
                )
                
                CircularGauge(
                    value: statusViewModel.statusMessages.last?.systemStats.temperature ?? 0,
                    maxValue: 85,
                    title: "TEMP",
                    unit: "°C",
                    color: temperatureColor
                )
            }
            .frame(height: 80)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var cpuColor: Color {
        let usage = statusViewModel.statusMessages.last?.systemStats.cpuUsage ?? 0
        switch usage {
        case ..<60: return .green
        case 60..<80: return .yellow
        default: return .red
        }
    }

    private var memoryColor: Color {
        let percent = memoryUsagePercent
        switch percent {
        case ..<70: return .green
        case 70..<85: return .yellow
        default: return .red
        }
    }

    private var temperatureColor: Color {
        let temp = statusViewModel.statusMessages.last?.systemStats.temperature ?? 0
        switch temp {
        case ..<65: return .green
        case 65..<75: return .yellow
        default: return .red
        }
    }

    private var memoryUsagePercent: Double {
        guard let memory = statusViewModel.statusMessages.last?.systemStats.memory else {
            return 0
        }
        let used = Double(memory.total - memory.available)
        let total = Double(memory.total)
        return (used / total) * 100
    }
    
    private var statusColor: Color {
        guard let stats = statusViewModel.statusMessages.last?.systemStats else { return .gray }
        if stats.cpuUsage > 80 || stats.temperature > 75 { return .red }
        if stats.cpuUsage > 60 || stats.temperature > 65 { return .yellow }
        return .green
    }
    
    // Additional color computation vars...
}

struct DronesOverviewCard: View {
    @ObservedObject var cotViewModel: CoTViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "airplane")
                    .foregroundColor(.blue)
                Text("ACTIVE DRONES")
                    .font(.appHeadline)
                Spacer()
                Text("\(cotViewModel.parsedMessages.count)")
                    .font(.system(.title2, design: .monospaced))
                    .foregroundColor(.blue)
            }
            
            // Quick stats
            HStack {
                StatBox(
                    title: "TRACKED",
                    value: "\(cotViewModel.droneSignatures.count)",
                    icon: "antenna.radiowaves.left.and.right",
                    color: .blue
                )
                
                StatBox(
                    title: "SPOOFED",
                    value: "\(spoofedCount)",
                    icon: "exclamationmark.triangle",
                    color: .yellow
                )
                
                StatBox(
                    title: "NEARBY",
                    value: "\(nearbyCount)",
                    icon: "location.fill",
                    color: .green
                )
            }
            
            // Recent activity list
            if !recentDrones.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(recentDrones) { drone in
                        HStack {
                            Text(drone.uid)
                                .font(.appCaption)
                            Spacer()
                            Text(drone.rssi?.description ?? "")
                                .font(.appCaption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var signalColor: Color {
        guard let rssi = recentRSSI else { return .gray }
        switch rssi {
        case ..<(-75): return .red
        case (-75)...(-60): return .yellow
        default: return .green
        }
    }

    private var recentRSSI: Int? {
        return cotViewModel.parsedMessages.last?.rssi
    }
    
    private var spoofedCount: Int {
        cotViewModel.parsedMessages.filter { $0.isSpoofed }.count
    }
    
    private var nearbyCount: Int {
        cotViewModel.parsedMessages.filter { msg in
            guard let rssi = msg.rssi else { return false }
            return rssi > -70
        }.count
    }
    
    private var recentDrones: [CoTViewModel.CoTMessage] {
        Array(cotViewModel.parsedMessages.prefix(3))
    }
}

struct SDRStatusCard: View {
    @ObservedObject var statusViewModel: StatusViewModel
    @ObservedObject var spectrumViewModel: SpectrumData.SpectrumViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "thermometer")
                    .foregroundColor(.purple)
                Text("SDR STATUS")
                    .font(.appHeadline)
                Spacer()
                Circle()
                    .fill(sdrStatusColor)
                    .frame(width: 8, height: 8)
            }
            
            if let antStats = statusViewModel.statusMessages.last?.antStats {
                HStack(spacing: 20) {
                    // Pluto Temperature
                    VStack(alignment: .leading) {
                        Text("PLUTO")
                            .font(.appCaption)
                            .foregroundColor(.secondary)
                        Text("\(Int(antStats.plutoTemp))°C")
                            .font(.system(.title2, design: .monospaced))
                            .foregroundColor(temperatureColor(antStats.plutoTemp, threshold: Settings.shared.plutoTempThreshold))
                    }
                    
                    // Zynq Temperature
                    VStack(alignment: .leading) {
                        Text("ZYNQ")
                            .font(.appCaption)
                            .foregroundColor(.secondary)
                        Text("\(Int(antStats.zynqTemp))°C")
                            .font(.system(.title2, design: .monospaced))
                            .foregroundColor(temperatureColor(antStats.zynqTemp, threshold: Settings.shared.zynqTempThreshold))
                    }
                    
                    // SDR Connection Status
                    VStack(alignment: .leading) {
                        Text("STATUS")
                            .font(.appCaption)
                            .foregroundColor(.secondary)
                        Text(spectrumViewModel.isListening ? "ACTIVE" : "INACTIVE")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(spectrumViewModel.isListening ? .green : .red)
                    }
                }
                .padding(.vertical, 4)
            } else {
                Text("No SDR Data")
                    .font(.appCaption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var sdrStatusColor: Color {
        guard let antStats = statusViewModel.statusMessages.last?.antStats else {
            return .gray
        }
        
        if antStats.plutoTemp > Settings.shared.plutoTempThreshold ||
           antStats.zynqTemp > Settings.shared.zynqTempThreshold {
            return .red
        }
        if !spectrumViewModel.isListening {
            return .yellow
        }
        return .green
    }
    
    private func temperatureColor(_ temp: Double, threshold: Double) -> Color {
        switch temp {
        case ..<(threshold - 10): return .green
        case ..<threshold: return .yellow
        default: return .red
        }
    }
}

struct WarningsCard: View {
    @ObservedObject var statusViewModel: StatusViewModel
    @ObservedObject var cotViewModel: CoTViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.red)
                Text("WARNINGS")
                    .font(.appHeadline)
                Spacer()
                Text("\(activeWarnings.count)")
                    .font(.system(.title2, design: .monospaced))
                    .foregroundColor(.red)
            }
            
            if activeWarnings.isEmpty {
                Text("No active warnings")
                    .font(.appCaption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(activeWarnings) { warning in
                    WarningRow(warning: warning)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var activeWarnings: [SystemWarning] {
        var warnings: [SystemWarning] = []
        
        // Check system status
        if let stats = statusViewModel.statusMessages.last?.systemStats {
            if stats.temperature > 75 {
                warnings.append(SystemWarning(
                    id: "temp",
                    title: "High Temperature",
                    detail: "\(Int(stats.temperature))°C",
                    severity: .high
                ))
            }
            
            if stats.cpuUsage > 80 {
                warnings.append(SystemWarning(
                    id: "cpu",
                    title: "High CPU Usage",
                    detail: "\(Int(stats.cpuUsage))%",
                    severity: .medium
                ))
            }
        }
        
        // Add drone warnings
        let spoofedDrones = cotViewModel.parsedMessages.filter { $0.isSpoofed }
        if !spoofedDrones.isEmpty {
            warnings.append(SystemWarning(
                id: "spoof",
                title: "Possible Spoofed Signals",
                detail: "\(spoofedDrones.count) drones",
                severity: .medium
            ))
        }
        
        return warnings
    }
    
    private var warningColor: Color {
        switch activeWarnings.count {
        case 0: return .green
        case 1: return .yellow
        default: return .red
        }
    }
}

// Supporting Views
struct StatBox: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(value)
                .font(.system(.title2, design: .monospaced))
                .foregroundColor(color)
            Text(title)
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct WarningRow: View {
    let warning: SystemWarning
    
    var body: some View {
        HStack {
            Circle()
                .fill(warning.severity.color)
                .frame(width: 8, height: 8)
            Text(warning.title)
                .font(.appCaption)
            Spacer()
            Text(warning.detail)
                .font(.appCaption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct SystemWarning: Identifiable {
    let id: String
    let title: String
    let detail: String
    let severity: Severity
    
    enum Severity {
        case high, medium, low
        
        var color: Color {
            switch self {
            case .high: return .red
            case .medium: return .yellow
            case .low: return .blue
            }
        }
    }
}

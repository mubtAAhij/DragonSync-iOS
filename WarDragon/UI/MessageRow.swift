//
//  MessageRow.swift
//  WarDragon
//
//  Created by Luke on 11/18/24.
//

import SwiftUI
import MapKit

struct MessageRow: View {
    let message: CoTViewModel.CoTMessage
    @ObservedObject var cotViewModel: CoTViewModel
    @ObservedObject private var droneStorage = DroneStorageManager.shared
    @State private var activeSheet: SheetType?
    @State private var showingSaveConfirmation = false
    @State private var showingInfoEditor = false
    
    enum SheetType: Identifiable {
        case liveMap
        case detailView
        
        var id: Int { hashValue }
    }
    
    // MARK: - Helper Properties
    
    private var signature: DroneSignature? {
        cotViewModel.droneSignatures.first(where: { $0.primaryId.id == message.uid })
    }
    
    // MARK: - Helper Methods
    
    private func rssiColor(_ rssi: Double) -> Color {
        switch rssi {
        case ..<(-75): return .red
        case -75..<(-50): return .yellow
        case 0...0: return .red
        default: return .green
        }
    }
    
    private func getRSSI() -> Double? {
        // First check signal sources for strongest RSSI
        if !message.signalSources.isEmpty {
            let strongestSource = message.signalSources.max(by: { $0.rssi < $1.rssi })
            if let rssi = strongestSource?.rssi {
                return Double(rssi)
            }
        }
        
        // Get RSSI from transmission info
        if let signature = signature, let rssi = signature.transmissionInfo.signalStrength {
            return rssi
        }
        
        // Fallback to raw message parsing
        if let basicId = message.rawMessage["Basic ID"] as? [String: Any] {
            if let rssi = basicId["RSSI"] as? Double {
                return rssi
            }
            if let rssi = basicId["rssi"] as? Double {
                return rssi
            }
        }
        
        if let auxAdvInd = message.rawMessage["AUX_ADV_IND"] as? [String: Any],
           let rssi = auxAdvInd["rssi"] as? Double {
            return rssi
        }
        
        if let rssi = message.rssi {
            return Double(rssi)
        }
        
        // Check remarks field for RSSI
        if let details = message.rawMessage["detail"] as? [String: Any],
           let remarks = details["remarks"] as? String,
           let match = remarks.firstMatch(of: /RSSI[: ]*(-?\d+)/) {
            return Double(match.1)
        }
        
        return nil
    }
    
    private func getMAC() -> String? {
        // Function to validate MAC format
        func isValidMAC(_ mac: String) -> Bool {
            return mac.range(of: "^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$", options: .regularExpression) != nil
        }
        
        // Check signature for MAC
        if let signature = signature,
           let mac = signature.transmissionInfo.macAddress,
           isValidMAC(mac) {
            return mac
        }
        
        // Check Basic ID in raw message
        if let basicId = message.rawMessage["Basic ID"] as? [String: Any] {
            if let mac = basicId["MAC"] as? String, isValidMAC(mac) {
                return mac
            }
            if let mac = basicId["mac"] as? String, isValidMAC(mac) {
                return mac
            }
        }
        
        // Check AUX_ADV_IND in raw message
        if let auxAdvInd = message.rawMessage["AUX_ADV_IND"] as? [String: Any],
           let mac = auxAdvInd["mac"] as? String,
           isValidMAC(mac) {
            return mac
        }
        
        // Check remarks field for MAC address
        if let details = message.rawMessage["detail"] as? [String: Any],
           let remarks = details["remarks"] as? String {
            if let match = remarks.firstMatch(of: /MAC[: ]*([0-9a-fA-F:]+)/),
               isValidMAC(String(match.1)) {
                return String(match.1)
            }
        }
        
        return nil
    }
    
    // MARK: - Subview Builders
    
    @ViewBuilder
    private func headerView() -> some View {
        HStack {
            // Dynamically fetch encounter information
            let encounter = droneStorage.encounters[message.uid]
            let customName = encounter?.customName ?? ""
            let trustStatus = encounter?.trustStatus ?? .unknown
            
            VStack(alignment: .leading) {
                if !customName.isEmpty {
                    Text(customName)
                        .font(.system(.title3, design: .monospaced))
                        .foregroundColor(.primary)
                }
                
                HStack {
                    Text(message.id)
                        .font(.system(.title3, design: .monospaced))
                        .foregroundColor(.primary)
                    
//                    Image(systemName: trustStatus.icon)  // 11.2 hotfix for UI: iPhones need only one icon for size reasons,
//                        .foregroundColor(trustStatus.color)
                }
                
                if let caaReg = message.caaRegistration, !caaReg.isEmpty {
                    Text("CAA ID: \(caaReg)")
                        .font(.appSubheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Trust status indicator
            Image(systemName: trustStatus.icon)
                .foregroundColor(trustStatus.color)
                .font(.system(size: 18))
                .padding(.trailing, 4)
            
            // Edit button
            Button(action: { showingInfoEditor = true }) {
                Image(systemName: "pencil.circle")
                    .font(.system(size: 18))
                    .foregroundColor(.blue)
            }
            
            // Live Map Button
            Button(action: { activeSheet = .liveMap }) {
                HStack {
                    Image(systemName: "map.fill")
                    Text("Live")
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
    }
    
    @ViewBuilder
    private func typeInfoView() -> some View {
        Text("Type: \(message.type)")
            .font(.appSubheadline)
    }
    
    @ViewBuilder
    private func signalSourcesView() -> some View {
        if !message.signalSources.isEmpty {
            VStack(alignment: .leading) {
                // Sort by timestamp (most recent first)
                let sortedSources = message.signalSources.sorted(by: { $0.timestamp > $1.timestamp })
                
                ForEach(sortedSources, id: \.self) { source in
                    signalSourceRow(source)
                }
            }
        } else if let rssi = getRSSI() {
            // Fallback for messages without signal sources
            HStack(spacing: 8) {
                Label("\(Int(rssi))dBm", systemImage: "antenna.radiowaves.left.and.right")
                    .font(.appCaption)
                    .fontWeight(.bold)
                    .foregroundColor(rssiColor(rssi))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                    .background(rssiColor(rssi).opacity(0.1))
            }
        }
    }
    
    private func signalSourceRow(_ source: CoTViewModel.SignalSource) -> some View {
        let iconName: String
        let iconColor: Color
        
        // Determine icon and color based on source type
        switch source.type {
        case .bluetooth:
            iconName = "antenna.radiowaves.left.and.right.circle"
            iconColor = .blue
        case .wifi:
            iconName = "wifi.circle"
            iconColor = .green
        case .sdr:
            iconName = "dot.radiowaves.left.and.right"
            iconColor = .purple
        default:
            iconName = "questionmark.circle"
            iconColor = .gray
        }
        
        return HStack {
            Image(systemName: iconName)
                .foregroundColor(iconColor)
            
            VStack(alignment: .leading) {
                HStack {
                    Text(source.mac)
                        .font(.appCaption)
                    Text(source.type.rawValue)
                        .font(.appCaption)
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("\(source.rssi) dBm")
                        .font(.appCaption)
                        .fontWeight(.bold)
                        .foregroundColor(rssiColor(Double(source.rssi)))
                    Spacer()
                    Text(source.timestamp.formatted(.relative(presentation: .numeric)))
                        .font(.appCaption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .background(rssiColor(Double(source.rssi)).opacity(0.1))
        .cornerRadius(6)
        .id("\(source.mac)-\(source.timestamp.timeIntervalSince1970)")
    }
    
    @ViewBuilder
    private func macRandomizationView() -> some View {
        if let macs = cotViewModel.macIdHistory[message.uid], macs.count > 2 {
            let macCount = macs.count
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.yellow)
                Text("MAC randomizing")
                    .font(.appCaption)
                    .foregroundColor(.secondary)
                Text("(\(macCount > 10 ? "10+" : String(macCount)) MACs)")
                    .font(.appCaption)
                    .foregroundColor(.secondary)
                
                if cotViewModel.macProcessing[message.uid] == true {
                    Image(systemName: "shield.lefthalf.filled")
                        .foregroundColor(.yellow)
                        .help("Random MAC addresses detected")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
            .background(Color.yellow.opacity(0.1))
        }
    }
    
    @ViewBuilder
    private func mapSectionView() -> some View {
        MapView(message: message, cotViewModel: cotViewModel)
            .frame(height: 150)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray, lineWidth: 1)
            )
    }
    
    @ViewBuilder
    private func detailsView() -> some View {
        Group {
            if message.lat != "0.0" {
                Text("Position: \(message.lat), \(message.lon)")
            }
            if message.alt != "0.0" {
                Text("Altitude: \(message.alt)m")
            }
            if message.speed != "0.0" {
                Text("Speed: \(message.speed)m/s")
            }
            if message.pilotLat != "0.0" {
                Text("Pilot Location: \(message.pilotLat), \(message.pilotLon)")
            }
            if let operatorId = message.operator_id {
                Text("Operator ID: \(operatorId)")
            }
            if let manufacturer = message.manufacturer, manufacturer != "Unknown" {
                Text("Manufacturer: \(manufacturer)")
            }
            if let mac = message.mac, !mac.isEmpty {
                Text("MAC: \(mac)")
            }
        }
        .font(.appCaption)
        .foregroundColor(.primary)
    }
    
    @ViewBuilder
    private func spoofDetectionView() -> some View {
        if message.isSpoofed, let details = message.spoofingDetails {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                    Text("Possible Spoofed Signal")
                        .foregroundColor(.primary)
                    Spacer()
                    Text(String(format: "Confidence: %.0f%%", details.confidence * 100))
                        .foregroundColor(.primary)
                }
                
                ForEach(details.reasons, id: \.self) { reason in
                    Text("• \(reason)")
                        .font(.appCaption)
                        .foregroundColor(.primary)
                }
            }
            .padding(.vertical, 4)
            .background(Color.yellow.opacity(0.1))
            .cornerRadius(8)
        }
    }
    
    // MARK: - Main View
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                activeSheet = .detailView
            }) {
                VStack(alignment: .leading, spacing: 4) {
                    headerView()
                    typeInfoView()
                    signalSourcesView()
                    macRandomizationView()
                    mapSectionView()
                    detailsView()
                    spoofDetectionView()
                }
            }
            .cornerRadius(8)
            .padding(.vertical, 8)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.primary, lineWidth: 3)
                    .padding(-8)
            )
        }
        .sheet(item: $activeSheet) { sheetType in
            switch sheetType {
            case .liveMap:
                NavigationView {
                    LiveMapView(cotViewModel: cotViewModel, initialMessage: message)
                        .navigationTitle("Live Drone Map")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    activeSheet = nil
                                }
                            }
                        }
                }
            case .detailView:
                NavigationView {
                    DroneDetailView(
                        message: message,
                        flightPath: [], // Single location view doesn't have flight path
                        cotViewModel: cotViewModel
                    )
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                activeSheet = nil
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingInfoEditor) {
            NavigationView {
                DroneInfoEditor(droneId: message.uid)
                    .navigationTitle("Edit Drone Info")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingInfoEditor = false
                            }
                        }
                    }
            }
            .presentationDetents([.medium])
        }
    }
}

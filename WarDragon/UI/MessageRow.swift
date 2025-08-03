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
    @State private var showingDeleteConfirmation = false
    
    enum SheetType: Identifiable {
        case liveMap
        case detailView
        
        var id: Int { hashValue }
    }
    
    // MARK: - Helper Properties
    
    private var signature: DroneSignature? {
        cotViewModel.droneSignatures.first(where: { $0.primaryId.id == message.uid })
    }
    
    private func removeDroneFromTracking() {
        // Get all possible ID variants for this drone
        let baseId = message.uid.replacingOccurrences(of: "drone-", with: "")
        let droneId = message.uid.hasPrefix("drone-") ? message.uid : "drone-\(message.uid)"
        
        let idsToRemove = [
            message.uid,
            droneId,
            baseId,
            "drone-\(baseId)"
        ]
        
        // Remove from active messages - use both ID and UID matching
        cotViewModel.parsedMessages.removeAll { msg in
            return idsToRemove.contains(msg.uid) || idsToRemove.contains(msg.id) || msg.uid.contains(baseId)
        }
        
        // Remove signatures for all ID variants
        cotViewModel.droneSignatures.removeAll { signature in
            return idsToRemove.contains(signature.primaryId.id)
        }
        
        // Remove MAC history for all ID variants
        for id in idsToRemove {
            cotViewModel.macIdHistory.removeValue(forKey: id)
            cotViewModel.macProcessing.removeValue(forKey: id)
        }
        
        // Remove any alert rings for all ID variants
        cotViewModel.alertRings.removeAll { ring in
            return idsToRemove.contains(ring.droneId)
        }
        
        // Mark this device as "do not track" in storage for all possible ID formats
        for id in idsToRemove {
            DroneStorageManager.shared.markAsDoNotTrack(id: id)
        }
        
        // Force immediate UI update
        cotViewModel.objectWillChange.send()
        
        print("🛑 Stopped tracking drone with IDs: \(idsToRemove)")
    }
    
    private func deleteDroneFromStorage() {
        let baseId = message.uid.replacingOccurrences(of: "drone-", with: "")
        let possibleIds = [
            message.uid,
            "drone-\(message.uid)",
            baseId,
            "drone-\(baseId)"
        ]
        for id in possibleIds {
            droneStorage.deleteEncounter(id: id)
        }
    }

    private func findEncounterForID(_ id: String) -> DroneEncounter? {
        // Direct lookup first
        if let encounter = droneStorage.encounters[id] {
            return encounter
        }

        
        return nil
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
                }
                
                if let caaReg = message.caaRegistration, !caaReg.isEmpty {
                    Text(String(localized: "caa_id_label", comment: "Label for CAA registration ID").replacingOccurrences(of: "{id}", with: caaReg))
                        .font(.appSubheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Add FAA lookup button if we have the necessary IDs
            if message.idType.contains("Serial Number") ||
                message.idType.contains("ANSI") ||
                message.idType.contains("CTA-2063-A") {
                FAALookupButton(mac: message.mac, remoteId: message.uid.replacingOccurrences(of: "drone-", with: ""))
            }
            
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(message.statusColor)
                        .frame(width: 8, height: 8)
                    Text(message.statusDescription)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(message.statusColor)
                }
                
                Image(systemName: trustStatus.icon)
                    .foregroundColor(trustStatus.color)
                    .font(.system(size: 18))
            }
            
            Button(action: { showingInfoEditor = true }) {
                Image(systemName: "pencil.circle")
                    .font(.system(size: 18))
                    .foregroundColor(.blue)
            }
            
            Menu {
                Button(action: { showingInfoEditor = true }) {
                    Label(String(localized: "edit_info", comment: "Button to edit drone information"), systemImage: "pencil")
                }
                
                Button(action: { activeSheet = .liveMap }) {
                    Label(String(localized: "live_map", comment: "Button to view live map"), systemImage: "map")
                }
                
                Divider()
                
                Button(action: {
                    removeDroneFromTracking()
                }) {
                    Label(String(localized: "stop_tracking", comment: "Button to stop tracking a drone"), systemImage: "eye.slash")
                }
                
                Button(role: .destructive, action: {
                    showingDeleteConfirmation = true
                }) {
                    Label(String(localized: "delete", comment: "Delete button"), systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 18))
                    .foregroundColor(.blue)
            }
        }
    }
    
    @ViewBuilder
    private func typeInfoView() -> some View {
        Text(String(localized: "type_label", comment: "Label for drone type").replacingOccurrences(of: "{type}", with: message.type))
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
                Label(String(localized: "rssi_value", comment: "RSSI signal strength value").replacingOccurrences(of: "{value}", with: "\(Int(rssi))"), systemImage: "antenna.radiowaves.left.and.right")
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
                    Text(String(localized: "rssi_dbm", comment: "RSSI value in dBm units").replacingOccurrences(of: "{value}", with: "\(source.rssi)"))
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
                Text(String(localized: "mac_randomizing", comment: "Indicator that MAC address is randomizing"))
                    .font(.appCaption)
                    .foregroundColor(.secondary)
                Text(String(localized: "mac_count", comment: "Count of MAC addresses").replacingOccurrences(of: "{count}", with: macCount > 10 ? String(localized: "ten_plus", comment: "10+ indicator") : String(macCount)))
                    .font(.appCaption)
                    .foregroundColor(.secondary)
                
                if cotViewModel.macProcessing[message.uid] == true {
                    Image(systemName: "shield.lefthalf.filled")
                        .foregroundColor(.yellow)
                        .help(String(localized: "random_mac_detected", comment: "Alert message when random MAC addresses are detected"))
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
                Text(String(localized: "position_coordinates", comment: "Label for GPS coordinates").replacingOccurrences(of: "{lat}", with: "\(message.lat)").replacingOccurrences(of: "{lon}", with: "\(message.lon)"))
            }
            if message.alt != "0.0" {
                Text(String(localized: "altitude_meters", comment: "Altitude in meters").replacingOccurrences(of: "{value}", with: "\(message.alt)"))
            }
            if message.speed != "0.0" {
                Text(String(localized: "speed_meters_per_second", comment: "Speed in meters per second").replacingOccurrences(of: "{value}", with: "\(message.speed)"))
            }
            if message.pilotLat != "0.0" {
                Text(String(localized: "pilot_location", comment: "Label for pilot location coordinates").replacingOccurrences(of: "{lat}", with: "\(message.pilotLat)").replacingOccurrences(of: "{lon}", with: "\(message.pilotLon)"))
            }
            if let operatorId = message.operator_id {
                Text(String(localized: "operator_id", comment: "Label for operator ID").replacingOccurrences(of: "{id}", with: operatorId))
            }
            if let manufacturer = message.manufacturer, manufacturer != "Unknown" {
                Text(String(localized: "manufacturer", comment: "Label for manufacturer").replacingOccurrences(of: "{name}", with: manufacturer))
            }
            if let mac = message.mac, !mac.isEmpty {
                Text(String(localized: "mac_address", comment: "Label for MAC address").replacingOccurrences(of: "{address}", with: mac))
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
                    Text(String(localized: "possible_spoofed_signal", comment: "Warning about potentially spoofed signal"))
                        .foregroundColor(.primary)
                    Spacer()
                    Text(String(format: String(localized: "confidence_percentage", comment: "Confidence level as percentage"), details.confidence * 100))
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
            .contextMenu {  // Add context menu for long press
                Button(action: {
                    removeDroneFromTracking()
                }) {
                    Label(String(localized: "stop_tracking", comment: "Button to stop tracking a drone"), systemImage: "eye.slash")
                }
                
                Button(role: .destructive, action: {
                    showingDeleteConfirmation = true
                }) {
                    Label(String(localized: "delete_from_history", comment: "Button to delete from history"), systemImage: "trash")
                }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    removeDroneFromTracking()
                    deleteDroneFromStorage()
//                    showingDeleteConfirmation = true
                } label: {
                    Label(String(localized: "delete", comment: "Delete button"), systemImage: "trash")
                }
                
                Button {
                    removeDroneFromTracking()
                } label: {
                    Label(String(localized: "stop", comment: "Stop button"), systemImage: "eye.slash")
                }
                .tint(.orange)
            }
        .sheet(item: $activeSheet) { sheetType in
            switch sheetType {
            case .liveMap:
                NavigationView {
                    LiveMapView(cotViewModel: cotViewModel, initialMessage: message)
                        .navigationTitle(String(localized: "live_drone_map", comment: "Title for live drone map view"))
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button(String(localized: "done", comment: "Done button")) {
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
                            Button(String(localized: "done", comment: "Done button")) {
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
                    .navigationTitle(String(localized: "edit_drone_info", comment: "Title for editing drone information"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(String(localized: "done", comment: "Done button")) {
                                showingInfoEditor = false
                            }
                        }
                    }
            }
            .presentationDetents([.medium])
        }
    }
}

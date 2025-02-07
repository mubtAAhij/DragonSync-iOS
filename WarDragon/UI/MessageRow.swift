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
    @State private var activeSheet: SheetType?
    @State private var showingSaveConfirmation = false

    
    enum SheetType: Identifiable {
        case liveMap
        case detailView
        
        var id: Int { hashValue }
    }
    
    private var signature: DroneSignature? {
        cotViewModel.droneSignatures.first(where: { $0.primaryId.id == message.uid })
    }
    
    private func rssiColor(_ rssi: Double) -> Color {
       switch rssi {
       case ..<(-75): return .red
       case -75..<(-60): return .yellow
       case 0...0: return .red
       default: return .green
       }
    }
    
    private func getRSSI() -> Double? {
        // First check signal sources for strongest RSSI
        if !message.signalSources.isEmpty {
            return Double(message.signalSources.max(by: { $0.rssi < $1.rssi })?.rssi ?? 0)
        }
        
        // Get RSSI from transmission info or raw message
        if let signature = signature,
           let rssi = signature.transmissionInfo.signalStrength {
            return rssi
        }
        
        // Fallback to raw message parsing
        if let rssiValue = (message.rawMessage["Basic ID"] as? [String: Any])?["RSSI"] as? Double ??
            (message.rawMessage["Basic ID"] as? [String: Any])?["rssi"] as? Double ??
            (message.rawMessage["AUX_ADV_IND"] as? [String: Any])?["rssi"] as? Double ??
            message.rssi.map(Double.init) {
            return rssiValue
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
        // Check signature for MAC
        if let signature = signature,
           let mac = signature.transmissionInfo.macAddress {
            return mac
        }
        
        // Fallback to raw message parsing
        if let macValue = (message.rawMessage["Basic ID"] as? [String: Any])?["MAC"] as? String ??
            (message.rawMessage["Basic ID"] as? [String: Any])?["mac"] as? String ??
            (message.rawMessage["AUX_ADV_IND"] as? [String: Any])?["mac"] as? String {
            return macValue
        }
        
        // Check remarks field for MAC address
        if let details = message.rawMessage["detail"] as? [String: Any],
           let remarks = details["remarks"] as? String,
           let match = remarks.firstMatch(of: /MAC[: ]*([0-9a-fA-F:]+)/) {
            return String(match.1) // Convert Substring to String
        }
        
        if let details = message.rawMessage["detail"] as? [String: Any],
           let remarks = details["remarks"] as? String {
            print("Remarks: \(remarks)")
            if let match = remarks.firstMatch(of: /MAC[: ]*([0-9a-fA-F:]+)/) {
                print("Regex Match: \(match.1)")
                return String(match.1)
            }
        }
        
        return nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                activeSheet = .detailView
            }) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: signature?.primaryId.uaType.icon ?? "airplane")
                            .foregroundColor(.blue)
                        Text("ID: \(message.id)")
                            .font(.appHeadline)
                        if let caaReg = message.caaRegistration {
                            if !caaReg.isEmpty {
                                Text("CAA ID: \(caaReg)")
                                    .font(.appSubheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
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
                    
                    Text("Type: \(message.type)")
                        .font(.appSubheadline)
                    
                    if !message.signalSources.isEmpty {
                        VStack(alignment: .leading) {
                            ForEach(message.signalSources.sorted(by: { $0.rssi > $1.rssi }), id: \.mac) { source in
                                HStack {
                                    // Signal type icon with proper type handling
                                    Image(systemName: source.type == .bluetooth ? "antenna.radiowaves.left.and.right.circle" :
                                                     source.type == .wifi ? "wifi.circle" :
                                                     source.type == .sdr ? "dot.radiowaves.left.and.right" :
                                                     "questionmark.circle")
                                        .foregroundColor(source.type == .bluetooth ? .blue :
                                                       source.type == .wifi ? .green :
                                                       source.type == .sdr ? .purple :
                                                       .gray)
                                    
                                    VStack(alignment: .leading) {
                                        HStack {
                                            Text(source.mac)
                                                .font(.appCaption)
                                            Text(source.type.rawValue)
                                                .font(.appCaption)
                                                .foregroundColor(.secondary)
                                        }
                                        Text("\(source.rssi) dBm")
                                            .font(.appCaption)
                                            .fontWeight(.bold)
                                            .foregroundColor(rssiColor(Double(source.rssi)))
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                                .background(rssiColor(Double(source.rssi)).opacity(0.1))
                                .cornerRadius(6)
                            }
                        }
                    } else if let mRSSI = getRSSI() {
                        // Fallback for messages without signal sources
                        HStack(spacing: 8) {
                            Label("\(Int(mRSSI))dBm", systemImage: "antenna.radiowaves.left.and.right")
                                .font(.appCaption)
                                .fontWeight(.bold)
                                .foregroundColor(rssiColor(mRSSI))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                                .background(rssiColor(mRSSI).opacity(0.1))
                        }
                    }
                    
                    // MAC randomization indicator
                    if let macs = cotViewModel.macIdHistory[message.uid], macs.count > 3 {
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
                    
                    
                    MapView(message: message)
                        .frame(height: 150)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray, lineWidth: 1)
                        )
                    
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
                        if message.operator_id != nil {
                            Text("Operator ID: \(message.operator_id ?? "")")
                        }
                        if message.manufacturer != "Unknown" {
                            Text("Manufacturer: \(message.manufacturer ?? "")")
                        }
                        if (message.mac != "") {
                            Text("MAC: \(message.mac ?? "")")
                        }
                    }
                    .font(.appCaption)
                    .foregroundColor(.primary)
                    
                    // Spoof detection
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
                            
                            VStack(alignment: .leading) {
                                
                            }
                            .font(.appCaption)
                            .foregroundColor(.secondary)
                            
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
    }
}

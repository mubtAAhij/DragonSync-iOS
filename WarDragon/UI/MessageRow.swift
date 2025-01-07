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
    
    enum SheetType: Identifiable {
        case liveMap
        case detailView
        
        var id: Int { hashValue }
    }
    
    private var signature: DroneSignature? {
        cotViewModel.droneSignatures.first(where: { $0.primaryId.id == message.uid })
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Tap Gesture for Entire Row (Excluding Button)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: signature?.primaryId.uaType.icon ?? "airplane")
                        .foregroundColor(.blue)
                    Text("ID: \(message.id)")
                        .font(.headline)
                    
                    Spacer()
                    
                    // Live Map Button
                    Button(action: {activeSheet = .liveMap}) {
                        HStack {
                            Image(systemName: "map.fill")
                            Text("Live")
                        }
                        .onTapGesture {
                            activeSheet = .liveMap  // TODO: cleanup this logic
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
                
                Text("Type: \(message.type)")
                    .font(.subheadline)
                
                
                if let transmissionInfo = signature?.transmissionInfo {
                    HStack(spacing: 8) {
                        if let rssi = transmissionInfo.signalStrength {
                            Label("\(Int(rssi))dBm", systemImage: "antenna.radiowaves.left.and.right")
                        }
                        if let channel = transmissionInfo.channel {
                            Label("CH:\(channel)", systemImage: "number")
                        }
                        if transmissionInfo.advMode != nil {
                            Image(systemName: "dot.radiowaves.left.and.right")
                        }
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }

                MapView(message: message)
                    .frame(height: 150)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray, lineWidth: 1)
                    )
                
                Group {
                    Text("Position: \(message.lat), \(message.lon)")
                    Text("Altitude: \(message.alt)m AGL: \(message.height)m")
                    Text("Speed: \(message.speed)m/s Vertical: \(message.vspeed)m/s")
                    if !message.pilotLat.isEmpty {
                        Text("Pilot Location: \(message.pilotLat), \(message.pilotLon)")
                    }
                    if !message.description.isEmpty {
                        Text("Description: \(message.description)")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
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
                                .foregroundColor(.yellow)
                        }
                        
                        VStack(alignment: .leading) {
                            Text(String(format: "Distance: %.1fm", details.distance))
                            Text(String(format: "Expected RSSI: %.1f dB", details.expectedRssi))
                            Text(String(format: "Actual RSSI: %.1f dB", details.actualRssi))
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                        
                        ForEach(details.reasons, id: \.self) { reason in
                            Text("• \(reason)")
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(.vertical, 4)
                    .background(Color.yellow.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                activeSheet = .detailView
            }
        }
        .cornerRadius(8)
        .padding(.vertical, 8)
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
                        flightPath: [] // Single location view doesn't have flight path
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

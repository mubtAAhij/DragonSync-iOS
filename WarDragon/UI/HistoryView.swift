//
//  HistoryView.swift
//  WarDragon
//
//  Created by Luke on 1/21/25.
//

import Foundation
import UIKit
import SwiftUI
import MapKit

struct StoredEncountersView: View {
    @ObservedObject var storage = DroneStorageManager.shared
    @State private var showingDeleteConfirmation = false
    
    var sortedEncounters: [DroneEncounter] {
        storage.encounters.values.sorted { $0.lastSeen > $1.lastSeen }
    }
    
    var body: some View {
        List {
            ForEach(sortedEncounters) { encounter in
                NavigationLink(destination: EncounterDetailView(encounter: encounter)) {
                    EncounterRow(encounter: encounter)
                }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    storage.deleteEncounter(id: sortedEncounters[index].id)
                }
            }
        }
        .navigationTitle("Encounter History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .alert("Delete Encounter", isPresented: $showingDeleteConfirmation) {
            Button("Delete All", role: .destructive) {
                storage.deleteAllEncounters()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure? This action cannot be undone.")
        }
    }
    
}

// Add the missing EncounterRow view
struct EncounterRow: View {
    let encounter: DroneEncounter
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Drone ID: \(encounter.id)")
                .font(.appHeadline)
            
            Text("First Seen: \(encounter.firstSeen.formatted())")
                .font(.appCaption)
            
            Text("Last Seen: \(encounter.lastSeen.formatted())")
                .font(.appCaption)
            
            HStack {
                Label("\(encounter.flightPath.count)", systemImage: "map")
                Label(String(format: "%.0fm", encounter.maxAltitude), systemImage: "arrow.up")
                Label(String(format: "%.0fm/s", encounter.maxSpeed), systemImage: "speedometer")
                if encounter.averageRSSI != 0 {
                    Label(String(format: "%.0fdB", encounter.averageRSSI),
                          systemImage: "antenna.radiowaves.left.and.right")
                }
            }
            .font(.appCaption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct EncounterDetailView: View {
    let encounter: DroneEncounter
    @Environment(\.dismiss) private var dismiss
    @StateObject private var storage = DroneStorageManager.shared
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        VStack {
            encounterMap
            encounterStatistics
            Spacer()
        }
        .navigationTitle("Encounter Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .alert("Delete Encounter", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                storage.deleteEncounter(id: encounter.id)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this encounter?")
        }
    }
    
    private var encounterMap: some View {
        Map(initialPosition: .automatic) {
            if !encounter.flightPath.isEmpty {
                MapPolyline(coordinates: encounter.flightPath.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) })
                    .stroke(.blue, lineWidth: 2)
                
                ForEach(Array(encounter.flightPath.enumerated()), id: \.offset) { index, point in
                    Marker(
                        encounter.id,
                        coordinate: CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)
                    )
                }
            }
        }
        .frame(height: 300)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var encounterStatistics: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("STATISTICS")
                .font(.headline)
            
            Group {
                DetailRow(title: "Flight Time", value: encounter.totalFlightTime.formatted())
                DetailRow(title: "Max Altitude", value: String(format: "%.1fm", encounter.maxAltitude))
                DetailRow(title: "Max Speed", value: String(format: "%.1fm/s", encounter.maxSpeed))
                DetailRow(title: "Avg RSSI", value: String(format: "%.1fdBm", encounter.averageRSSI))
                DetailRow(title: "Data Points", value: "\(encounter.flightPath.count)")
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
        }
    }
}

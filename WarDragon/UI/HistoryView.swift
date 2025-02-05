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
    @State private var searchText = ""
    @State private var sortOrder: SortOrder = .lastSeen
    
    enum SortOrder {
        case lastSeen, firstSeen, maxAltitude, maxSpeed
    }
    
    var sortedEncounters: [DroneEncounter] {
        // Get unique drones by MAC, falling back to ID
        let uniqueEncounters = Dictionary(grouping: storage.encounters.values) { encounter in
            encounter.metadata["mac"] ?? encounter.id
        }.values.map { encounters in
            encounters.max { $0.lastSeen < $1.lastSeen }!
        }
        
        // CAA ID handler
        let filtered = uniqueEncounters.filter { encounter in
            searchText.isEmpty ||
            encounter.id.localizedCaseInsensitiveContains(searchText) ||
            encounter.metadata["caaRegistration"]?.localizedCaseInsensitiveContains(searchText) ?? false
        }
        
        return filtered.sorted { first, second in
            switch sortOrder {
            case .lastSeen: return first.lastSeen > second.lastSeen
            case .firstSeen: return first.firstSeen > second.firstSeen
            case .maxAltitude: return first.maxAltitude > second.maxAltitude
            case .maxSpeed: return first.maxSpeed > second.maxSpeed
            }
        }
    }
    
    var body: some View {
        NavigationStack {
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
            .searchable(text: $searchText, prompt: "Search by ID or CAA Registration")
            .navigationTitle("Encounter History")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Picker("Sort By", selection: $sortOrder) {
                            Text("Last Seen").tag(SortOrder.lastSeen)
                            Text("First Seen").tag(SortOrder.firstSeen)
                            Text("Max Altitude").tag(SortOrder.maxAltitude)
                            Text("Max Speed").tag(SortOrder.maxSpeed)
                        }
                        Button {
                            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let window = windowScene.windows.first,
                               let rootVC = window.rootViewController {
                                storage.shareCSV(from: rootVC)
                            }
                        } label: {
                            Label("Export CSV", systemImage: "square.and.arrow.up")
                        }
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete All", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .alert("Delete All Encounters", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    storage.deleteAllEncounters()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
    
    struct EncounterRow: View {
        let encounter: DroneEncounter
        
        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(ensureDronePrefix(encounter.id))
                        .font(.appHeadline)
                    if let caaReg = encounter.metadata["caaRegistration"] {
                        Text("CAA: \(caaReg)")
                            .font(.appCaption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "airplane")
                        .foregroundStyle(.blue)
                }
                
                if let mac = encounter.metadata["mac"] {
                    Text("MAC: \(mac)")
                        .font(.appCaption)
                }
                
                HStack {
                    Label("\(encounter.flightPath.count) points", systemImage: "map")
                    Label(String(format: "%.0fm", encounter.maxAltitude), systemImage: "arrow.up")
                    Label(String(format: "%.0fm/s", encounter.maxSpeed), systemImage: "speedometer")
                    if encounter.averageRSSI != 0 {
                        Label(String(format: "%.0fdB", encounter.averageRSSI),
                              systemImage: "antenna.radiowaves.left.and.right")
                    }
                }
                .font(.appCaption)
                .foregroundStyle(.secondary)
                
                Text("Duration: \(formatDuration(encounter.totalFlightTime))")
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
            
//            if !encounter.macHistory.isEmpty && encounter.macHistory.count > 1 {
//                VStack(alignment: .leading) {
//                    Text("MAC RANDOMIZATION")
//                        .font(.appHeadline)
//                    ForEach(Array(encounter.macHistory).sorted(), id: \.self) { mac in
//                        Text(mac)
//                            .font(.appCaption)
//                    }
//                }
//                .padding()
//                .background(Color.yellow.opacity(0.1))
//                .cornerRadius(12)
//            }
        }
        
        private func formatDuration(_ time: TimeInterval) -> String {
            let hours = Int(time) / 3600
            let minutes = Int(time) % 3600 / 60
            let seconds = Int(time) % 60
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        
        private func ensureDronePrefix(_ id: String) -> String {
                return id.hasPrefix("drone-") ? id : "drone-\(id)"
            }
    }
    
    struct EncounterDetailView: View {
        let encounter: DroneEncounter
        @Environment(\.dismiss) private var dismiss
        @StateObject private var storage = DroneStorageManager.shared
        @State private var showingDeleteConfirmation = false
        @State private var selectedMapType: MapStyle = .standard
        
        enum MapStyle {
            case standard, satellite, hybrid
        }
        
        var body: some View {
            ScrollView {
                VStack(spacing: 16) {
                    mapSection
                    encounterStats
//                    metadataSection
                    flightDataSection
                }
                .padding()
            }
            .navigationTitle("Encounter Details")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Picker("Map Style", selection: $selectedMapType) {
                            Text("Standard").tag(MapStyle.standard)
                            Text("Satellite").tag(MapStyle.satellite)
                            Text("Hybrid").tag(MapStyle.hybrid)
                        }
                        Button {
                            exportKML()
                        } label: {
                            Label("Export KML", systemImage: "square.and.arrow.up")
                        }
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .alert("Delete Encounter", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    storage.deleteEncounter(id: encounter.id)
                    dismiss() // Add this to return to list after deletion
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this encounter? This action cannot be undone.")
            }
        }
        
        private var mapSection: some View {
            Map {
                if !encounter.flightPath.isEmpty {
                    MapPolyline(coordinates: encounter.flightPath.map {
                        CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                    })
                    .stroke(.blue, lineWidth: 2)
                    
                    // Start point
                    if let start = encounter.flightPath.first {
                        Annotation("Start", coordinate: start.coordinate) {
                            Image(systemName: "airplane.departure")
                                .foregroundStyle(.green)
                        }
                    }
                    
                    // End point
                    if let end = encounter.flightPath.last {
                        Annotation("End", coordinate: end.coordinate) {
                            Image(systemName: "airplane.arrival")
                                .foregroundStyle(.red)
                        }
                    }
                    
                    // Home location
                    if let firstPoint = encounter.flightPath.first,
                       let homeLat = firstPoint.homeLatitude,
                       let homeLon = firstPoint.homeLongitude {
                        let homeCoord = CLLocationCoordinate2D(
                            latitude: homeLat,
                            longitude: homeLon
                        )
                        Annotation("Home", coordinate: homeCoord) {
                            Image(systemName: "house.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
            .mapStyle(mapStyleForSelectedType())
            .frame(height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        
        
        private func mapStyleForSelectedType() -> MapKit.MapStyle {
            switch selectedMapType {
            case .standard:
                return .standard
            case .satellite:
                return .imagery
            case .hybrid:
                return .hybrid
            }
        }
        
        private var encounterStats: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("ENCOUNTER STATS")
                    .font(.appHeadline)
                    .frame(maxWidth: .infinity, alignment: .center)
                
                StatsGrid {
                    StatItem(title: "Duration", value: formatDuration(encounter.totalFlightTime))
                    StatItem(title: "Max Alt", value: String(format: "%.1fm", encounter.maxAltitude))
                    StatItem(title: "Max Speed", value: String(format: "%.1fm/s", encounter.maxSpeed))
                    StatItem(title: "Avg RSSI", value: String(format: "%.1fdBm", encounter.averageRSSI))
                    StatItem(title: "Points", value: "\(encounter.flightPath.count)")
                    StatItem(title: "Signatures", value: "\(encounter.signatures.count)")
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
        
//        private var metadataSection: some View {
//            VStack(alignment: .leading, spacing: 8) {
//                Text("METADATA")
//                    .font(.appHeadline)
//                
//                ForEach(Array(encounter.metadata.sorted(by: { $0.key < $1.key })), id: \.key) { key, value in
//                    HStack {
//                        Text(key)
//                            .foregroundStyle(.secondary)
//                        Spacer()
//                        Text(value)
//                    }
//                    .font(.appCaption)
//                }
//            }
//            .padding()
//            .background(Color(UIColor.secondarySystemBackground))
//            .cornerRadius(12)
//        }
        
        private var flightDataSection: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("FLIGHT DATA")
                    .font(.appHeadline)
                    .frame(maxWidth: .infinity, alignment: .center)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        Spacer()
                        FlightDataChart(title: "Altitude", data: encounter.flightPath.map { $0.altitude })
                        FlightDataChart(title: "Speed", data: encounter.signatures.map { $0.speed })
                        FlightDataChart(title: "RSSI", data: encounter.signatures.map { $0.rssi })
                        Spacer()
                    }
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }

    }
    
    struct StatsGrid<Content: View>: View {
        let content: Content
        
        init(@ViewBuilder content: () -> Content) {
            self.content = content()
        }
        
        var body: some View {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                content
            }
        }
    }
    
    struct StatItem: View {
        let title: String
        let value: String
        
        var body: some View {
            VStack(spacing: 4) {
                Text(title)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.appHeadline)
            }
        }
    }
    
    struct FlightDataChart: View {
        let title: String
        let data: [Double]
        
        var body: some View {
            VStack {
                Text(title)
                    .font(.appCaption)
                
                GeometryReader { geometry in
                    Path { path in
                        let step = geometry.size.width / CGFloat(data.count - 1)
                        let scale = geometry.size.height / (data.max()! - data.min()!)
                        
                        path.move(to: CGPoint(
                            x: 0,
                            y: geometry.size.height - (data[0] - data.min()!) * scale
                        ))
                        
                        for i in 1..<data.count {
                            path.addLine(to: CGPoint(
                                x: CGFloat(i) * step,
                                y: geometry.size.height - (data[i] - data.min()!) * scale
                            ))
                        }
                    }
                    .stroke(.blue, lineWidth: 2)
                }
            }
            .frame(width: 200, height: 100)
        }
    }
}

private func formatDuration(_ time: TimeInterval) -> String {
    let hours = Int(time) / 3600
    let minutes = Int(time) % 3600 / 60
    let seconds = Int(time) % 60
    return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
}

extension StoredEncountersView.EncounterDetailView {
    private func generateKML(for encounter: DroneEncounter) -> String {
        let kml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <kml xmlns="http://www.opengis.net/kml/2.2">
          <Document>
            <name>\(encounter.id) Flight Path</name>
            <Style id="flightPath">
              <LineStyle>
                <color>ff0000ff</color>
                <width>4</width>
              </LineStyle>
            </Style>
            <Placemark>
              <name>\(encounter.id) Track</name>
              <styleUrl>#flightPath</styleUrl>
              <LineString>
                <altitudeMode>absolute</altitudeMode>
                <coordinates>
                    \(encounter.flightPath.map { point in
                        "\(point.longitude),\(point.latitude),\(point.altitude)"
                    }.joined(separator: "\n                    "))
                </coordinates>
              </LineString>
            </Placemark>
          </Document>
        </kml>
        """
        return kml
    }
    
    func exportKML(from viewController: UIViewController? = nil) {
        // Generate KML content
        let kmlContent = generateKML(for: encounter)
        
        // Ensure KML stuff is valid
        guard let kmlData = kmlContent.data(using: .utf8) else {
            print("Failed to convert KML content to NSData.")
            return
        }
        
        // Stamp the filename
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let timestamp = dateFormatter.string(from: Date()).replacingOccurrences(of: ":", with: "_")
        let filename = "\(encounter.id)_flightpath_\(timestamp).kml"
        
        // Create a temporary file URL to share it
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent(filename)
        
        // Write KML data to the file
        do {
            try kmlData.write(to: fileURL)
        } catch {
            print("Failed to write KML data to file: \(error)")
            return
        }
        
        // Create the activity item source for sharing
        let kmlDataItem = KMLDataItem(fileURL: fileURL, filename: filename)
        
        let activityVC = UIActivityViewController(
            activityItems: [kmlDataItem],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            
            if UIDevice.current.userInterfaceIdiom == .pad {
                activityVC.popoverPresentationController?.sourceView = window
                activityVC.popoverPresentationController?.sourceRect = CGRect(
                    x: window.bounds.midX,
                    y: window.bounds.midY,
                    width: 0,
                    height: 0
                )
                activityVC.popoverPresentationController?.permittedArrowDirections = []
            }
            
            DispatchQueue.main.async {
                window.rootViewController?.present(activityVC, animated: true)
            }
        }
    }
    
    // Workaround to prevent writing where we don't want to
    class KMLDataItem: NSObject, UIActivityItemSource {
        private let fileURL: URL
        private let filename: String
        
        init(fileURL: URL, filename: String) {
            self.fileURL = fileURL
            self.filename = filename
            super.init()
        }
        
        func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
            return fileURL
        }
        
        func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
            return fileURL
        }
        
        func activityViewController(_ activityViewController: UIActivityViewController, dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?) -> String {
            return "application/vnd.google-earth.kml+xml"
        }
        
        func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
            return filename
        }
        
        func activityViewController(_ activityViewController: UIActivityViewController, filenameForActivityType activityType: UIActivity.ActivityType?) -> String {
            return filename
        }
    }

}

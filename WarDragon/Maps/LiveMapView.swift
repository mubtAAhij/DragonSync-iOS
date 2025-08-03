//
//  LiveMapView.swift
//  WarDragon
//
//  Created by Luke on 11/18/24.
//

import SwiftUI
import MapKit

struct LiveMapView: View {
    @ObservedObject var cotViewModel: CoTViewModel
    @State public var mapCameraPosition: MapCameraPosition
    @State private var showDroneList = false
    @State private var showDroneDetail = false
    @State private var selectedDrone: CoTViewModel.CoTMessage?
    @State private var selectedFlightPath: [CLLocationCoordinate2D] = []
    @State private var flightPaths: [String: [(coordinate: CLLocationCoordinate2D, timestamp: Date)]] = [:]
    @State private var lastProcessedDrones: [String: CoTViewModel.CoTMessage] = [:] // Track last processed drones
    @State private var shouldUpdateMapView: Bool = false
    @State private var userHasMovedMap = false
    let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect() // Timer for updates
    
    init(cotViewModel: CoTViewModel, initialMessage: CoTViewModel.CoTMessage) {
        self.cotViewModel = cotViewModel
        let lat = Double(initialMessage.lat) ?? 0
        let lon = Double(initialMessage.lon) ?? 0
        
        // Prioritize alert ring if coordinates are 0,0
        if lat == 0 && lon == 0,
           let ring = cotViewModel.alertRings.first(where: { $0.droneId == initialMessage.uid }) {
            _mapCameraPosition = State(initialValue: .region(MKCoordinateRegion(
                center: ring.centerCoordinate,
                span: MKCoordinateSpan(latitudeDelta: max(ring.radius / 250, 0.1),
                                        longitudeDelta: max(ring.radius / 250, 0.1))
            )))
        } else {
            _mapCameraPosition = State(initialValue: .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )))
        }
    }
    
    private func cleanOldPathPoints() {
        let maxAge: TimeInterval = 3600 // 1 hour
        let now = Date()
        
        for (droneId, path) in flightPaths {
            let updatedPath = path.filter { now.timeIntervalSince($0.timestamp) < maxAge }
            flightPaths[droneId] = updatedPath
        }
    }
    
    private var uniqueDrones: [CoTViewModel.CoTMessage] {
        var latestDronePositions: [String: CoTViewModel.CoTMessage] = [:]
        var droneOrder: [String] = [] // Track the original order of appearance
        
        for message in cotViewModel.parsedMessages {
            // Only include valid non-CAA messages with coordinates
            if !message.idType.contains("CAA"), let _ = message.coordinate {
                if latestDronePositions[message.uid] == nil {
                    droneOrder.append(message.uid)
                }
                latestDronePositions[message.uid] = message
            }
        }
        
        // Return drones in their original order of first appearance
        return droneOrder.compactMap { latestDronePositions[$0] }
    }
    
    func updateFlightPathsIfNewData() {
        let newMessages = cotViewModel.parsedMessages.filter { message in
            guard let lastMessage = lastProcessedDrones[message.uid] else {
                return true // Always process first time
            }
            
            // Only process if significant coordinate change occurred
            return message.lat != lastMessage.lat ||
                   message.lon != lastMessage.lon
        }
        
        guard !newMessages.isEmpty else { return }
        
        for message in newMessages {
            guard let coordinate = message.coordinate else { continue }
            
            var path = flightPaths[message.uid] ?? []
            path.append((coordinate: coordinate, timestamp: Date()))
            
            // Limit path length
            if path.count > 200 {
                path.removeFirst()
            }
            
            flightPaths[message.uid] = path
            lastProcessedDrones[message.uid] = message
        }
    }
    
    var body: some View {
        ZStack {
            Map(position: $mapCameraPosition) {
                ForEach(flightPaths.keys.sorted(), id: \.self) { droneId in
                    if let path = flightPaths[droneId], path.count > 1 {
                        MapPolyline(coordinates: path.map { $0.coordinate })
                            .stroke(Color.blue, lineWidth: 2)
                    }
                }
                // Draw drone markers with valid coordinates
                ForEach(uniqueDrones, id: \.uid) { message in
                    if let coordinate = message.coordinate,
                       coordinate.latitude != 0 || coordinate.longitude != 0 {
                        Annotation(message.uid, coordinate: coordinate) {
                            Circle()
                                .fill(message.uid == uniqueDrones.last?.uid ? Color.red : Color.blue)
                                .frame(width: 10, height: 10)
                        }
                    }
                }
                
                // Draw alert rings for drones with no valid coordinates
                ForEach(cotViewModel.alertRings, id: \.id) { ring in
                    MapCircle(center: ring.centerCoordinate, radius: ring.radius)
                        .foregroundStyle(.yellow.opacity(0.1))
                        .stroke(.yellow, lineWidth: 2)
                    
                    
                    Annotation(String(localized: "rssi_value", comment: "RSSI signal strength label"), coordinate: ring.centerCoordinate) {
                        VStack {
                            Text(String(localized: "encrypted_drone", comment: "Label for encrypted drone detection"))
                                .font(.caption)
                            Text(String(localized: "radius_meters", comment: "Radius measurement in meters"))
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                        .padding(6)
                        .background(.ultraThinMaterial)
                        .cornerRadius(6)
                    }
                }
            }
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { _ in
                        userHasMovedMap = true
                    }
            )
            VStack {
                // Reset view button
                if userHasMovedMap {
                    HStack {
                        Spacer()
                        Button(action: {
                            // Force an immediate camera update
                            let allCoordinates = uniqueDrones.compactMap { $0.coordinate }
                            if !allCoordinates.isEmpty {
                                let latitudes = allCoordinates.map(\.latitude)
                                let longitudes = allCoordinates.map(\.longitude)
                                let minLat = latitudes.min()!
                                let maxLat = latitudes.max()!
                                let minLon = longitudes.min()!
                                let maxLon = longitudes.max()!
                                let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2,
                                                                    longitude: (minLon + maxLon) / 2)
                                let deltaLat = max((maxLat - minLat) * 1.2, 0.05)
                                let deltaLon = max((maxLon - minLon) * 1.2, 0.05)
                                withAnimation {
                                    mapCameraPosition = .region(
                                        MKCoordinateRegion(center: center,
                                                           span: MKCoordinateSpan(latitudeDelta: deltaLat,
                                                                                  longitudeDelta: deltaLon))
                                    )
                                }
                            }
                        }) {
                            Image(systemName: "arrow.counterclockwise")
                                .padding(8)
                                .background(.ultraThinMaterial)
                                .cornerRadius(8)
                        }
                        .padding()
                    }
                }
                
                Spacer()
                Button(action: { showDroneList.toggle() }) {
                    Text(String(localized: "drones_count", comment: "Button text showing number of drones"))
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                }
                .padding(.bottom)
            }
        }
        .sheet(isPresented: $showDroneList) {
            NavigationView {
                List(uniqueDrones) { message in
                    NavigationLink(destination: DroneDetailView(message: message, flightPath: flightPaths[message.uid]?.map { $0.coordinate } ?? [], cotViewModel: cotViewModel)) {
                        VStack(alignment: .leading) {
                            Text(message.uid)
                                .font(.appHeadline)
                            Text(String(localized: "position_coordinates", comment: "Label showing drone position coordinates"))
                                .font(.appCaption)
                            if !message.description.isEmpty {
                                Text(String(localized: "description_label", comment: "Label for drone description"))
                                    .font(.appCaption)
                            }
                            if message.pilotLat != "0.0" && message.pilotLon != "0.0" {
                                Text(String(localized: "pilot_coordinates", comment: "Label showing pilot coordinates"))
                                    .font(.appCaption)
                            }
                            if let macs = cotViewModel.macIdHistory[message.uid], macs.count > 1 {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.yellow)
                                    Text(String(localized: "mac_randomizing", comment: "Warning text for MAC address randomization"))
                                        .font(.appCaption)
                                        .foregroundColor(.yellow)
                                }
                            }
                        }
                    }
                }
                .navigationTitle(String(localized: "active_drones", comment: "Navigation title for active drones list"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(String(localized: "done", comment: "Done button text")) {
                            showDroneList = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showDroneDetail) {
            if let drone = selectedDrone {
                NavigationView {
                    DroneDetailView(
                        message: drone,
                        flightPath: selectedFlightPath,
                        cotViewModel: cotViewModel
                    )
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(String(localized: "done", comment: "Done button text")) {
                                showDroneDetail = false
                            }
                        }
                    }
                }
            }
        }
        .onReceive(timer) { _ in
            updateFlightPathsIfNewData()
            
            // Only auto-update camera if user hasn't moved map and we have new data
            if !userHasMovedMap && shouldUpdateMapView {
                let allCoordinates = uniqueDrones.compactMap { $0.coordinate }
                if !allCoordinates.isEmpty {
                    print("Rendering new flightpaths & map...")
                    let latitudes = allCoordinates.map(\.latitude)
                    let longitudes = allCoordinates.map(\.longitude)
                    let minLat = latitudes.min()!
                    let maxLat = latitudes.max()!
                    let minLon = longitudes.min()!
                    let maxLon = longitudes.max()!
                    let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2,
                                                        longitude: (minLon + maxLon) / 2)
                    let deltaLat = max((maxLat - minLat) * 1.2, 0.05)
                    let deltaLon = max((maxLon - minLon) * 1.2, 0.05)
                    withAnimation {
                        mapCameraPosition = .region(
                            MKCoordinateRegion(center: center,
                                               span: MKCoordinateSpan(latitudeDelta: deltaLat,
                                                                      longitudeDelta: deltaLon))
                        )
                    }
                }
            }
        }
    }
}

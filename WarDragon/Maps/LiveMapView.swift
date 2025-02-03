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
    @State private var mapCameraPosition: MapCameraPosition
    @State private var showDroneList = false
    @State private var showDroneDetail = false
    @State private var selectedDrone: CoTViewModel.CoTMessage?
    @State private var selectedFlightPath: [CLLocationCoordinate2D] = []
    @State private var flightPaths: [String: [(coordinate: CLLocationCoordinate2D, timestamp: Date)]] = [:]
    @State private var lastProcessedDrones: [String: CoTViewModel.CoTMessage] = [:] // Track last processed drones
    @State private var shouldUpdateMapView: Bool = false
    let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect() // Timer for updates
    
    init(cotViewModel: CoTViewModel, initialMessage: CoTViewModel.CoTMessage) {
        self.cotViewModel = cotViewModel
        let lat = Double(initialMessage.lat) ?? 0
        let lon = Double(initialMessage.lon) ?? 0
        _mapCameraPosition = State(initialValue: .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )))
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
        for message in cotViewModel.parsedMessages {
            // Only include valid non-CAA messages with coordinates
            if !message.idType.contains("CAA"), let _ = message.coordinate {
                latestDronePositions[message.uid] = message
            }
        }
        return Array(latestDronePositions.values)
    }
    
    func updateFlightPathsIfNewData() {
        let newMessages = cotViewModel.parsedMessages.filter { message in
            guard let lastMessage = lastProcessedDrones[message.uid] else {
                return true // Process if no prior message exists for this uid
            }
            return message != lastMessage // Process only if the message is different
        }
        
        guard !newMessages.isEmpty else {
            shouldUpdateMapView = false // No new data; suppress map updates
            return
        }
        
        print("Updating flight paths with new data...")
        for message in newMessages {
            guard let coordinate = message.coordinate else { continue }
            
            var path = flightPaths[message.uid] ?? []
            path.append((coordinate: coordinate, timestamp: Date()))
            if path.count > 200 {
                path.removeFirst()
            }
            flightPaths[message.uid] = path
            
            // Update the processed message
            lastProcessedDrones[message.uid] = message
        }
        
        shouldUpdateMapView = true // Trigger map updates
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
                ForEach(uniqueDrones, id: \.uid) { message in
                    if let coordinate = message.coordinate {
                        Annotation(message.uid, coordinate: coordinate) {
                            Circle()
                                .fill(message.uid == uniqueDrones.last?.uid ? Color.red : Color.blue)
                                .frame(width: 10, height: 10)
                        }
                    }
                }
            }
            VStack {
                Spacer()
                Button(action: { showDroneList.toggle() }) {
                    Text("\(uniqueDrones.count) Drones")
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
                            Text("Position: \(message.lat), \(message.lon)")
                                .font(.appCaption)
                            if !message.description.isEmpty {
                                Text("Description: \(message.description)")
                                    .font(.appCaption)
                            }
                            if message.pilotLat != "0.0" && message.pilotLon != "0.0" {
                                Text("Pilot: \(message.pilotLat), \(message.pilotLon)")
                                    .font(.appCaption)
                            }
                            if let macs = cotViewModel.macIdHistory[message.uid], macs.count > 1 {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.yellow)
                                    Text("MAC randomizing (\(macs.count))")
                                        .font(.appCaption)
                                        .foregroundColor(.yellow)
                                }
                            }
                        }
                    }
                }
                .navigationTitle("Active Drones")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
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
                            Button("Done") {
                                showDroneDetail = false
                            }
                        }
                    }
                }
            }
        }
        .onReceive(timer) { _ in
            updateFlightPathsIfNewData()
            
            guard shouldUpdateMapView else { return } // Only update if necessary
            
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
                                           span: MKCoordinateSpan(latitudeDelta: deltaLat, longitudeDelta: deltaLon))
                    )
                }
            }
        }
    }
}

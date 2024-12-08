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
    @State private var flightPaths: [String: [CLLocationCoordinate2D]] = [:]
    let timer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()
    
    init(cotViewModel: CoTViewModel, initialMessage: CoTViewModel.CoTMessage) {
        self.cotViewModel = cotViewModel
        let lat = Double(initialMessage.lat) ?? 0
        let lon = Double(initialMessage.lon) ?? 0
        _mapCameraPosition = State(initialValue: .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )))
    }
    
    private var uniqueDrones: [CoTViewModel.CoTMessage] {
        var latestDronePositions: [String: CoTViewModel.CoTMessage] = [:]
        for message in cotViewModel.parsedMessages {
            if let coordinate = message.coordinate {
                var path = flightPaths[message.uid] ?? []
                path.append(coordinate)
                if path.count > 100 {
                    path.removeFirst()
                }
                flightPaths[message.uid] = path
            }
            latestDronePositions[message.uid] = message
        }
        return Array(latestDronePositions.values)
    }
    
    var body: some View {
        ZStack {
            Map(position: $mapCameraPosition) {
                // Flight paths
                ForEach(flightPaths.keys.sorted(), id: \.self) { droneId in
                    if let path = flightPaths[droneId], path.count > 1 {
                        MapPolyline(coordinates: path)
                            .stroke(Color.blue, lineWidth: 2)
                    }
                }
                
                // Drone markers
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
                    VStack(alignment: .leading) {
                        Text(message.uid)
                            .font(.headline)
                        Text("Position: \(message.lat), \(message.lon)")
                            .font(.caption)
                        if !message.description.isEmpty {
                            Text("Description: \(message.description)")
                                .font(.caption)
                        }
                        if message.pilotLat != "0.0" && message.pilotLon != "0.0" {
                            Text("Pilot: \(message.pilotLat), \(message.pilotLon)")
                                .font(.caption)
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
        .onReceive(timer) { _ in
            if let latestMessage = uniqueDrones.last,
               let lat = Double(latestMessage.lat),
               let lon = Double(latestMessage.lon) {
                withAnimation {
                    mapCameraPosition = .region(MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                    ))
                }
            }
        }
    }
}

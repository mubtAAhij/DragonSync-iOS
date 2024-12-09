//
//  DroneDetailView.swift
//  WarDragon
//
//  Created by Luke on 12/09/24.
//

import SwiftUI
import MapKit
import CoreLocation

struct DroneDetailView: View {
    let message: CoTViewModel.CoTMessage
    let flightPath: [CLLocationCoordinate2D]
    @State private var region: MKCoordinateRegion
    
    init(message: CoTViewModel.CoTMessage, flightPath: [CLLocationCoordinate2D]) {
        self.message = message
        self.flightPath = flightPath
        let lat = Double(message.lat) ?? 0
        let lon = Double(message.lon) ?? 0
        _region = State(initialValue: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Map {
                    // Current position marker
                    Annotation(message.uid, coordinate: CLLocationCoordinate2D(
                        latitude: Double(message.lat) ?? 0,
                        longitude: Double(message.lon) ?? 0
                    )) {
                        Image(systemName: "airplane")
                            .foregroundStyle(.blue)
                    }
                    // Flight path line
                    if flightPath.count > 1 {
                        MapPolyline(coordinates: flightPath)
                            .stroke(.blue, lineWidth: 2)
                    }
                    
                    // Show operator location if available
                    if message.pilotLat != "0.0" && message.pilotLon != "0.0" {
                        let pilotCoord = CLLocationCoordinate2D(
                            latitude: Double(message.pilotLat) ?? 0,
                            longitude: Double(message.pilotLon) ?? 0
                        )
                        Annotation("Operator", coordinate: pilotCoord) {
                            Image(systemName: "person.circle")
                                .foregroundStyle(.green)
                        }
                    }
                }
                .frame(height: 300)
                .cornerRadius(12)
                
                Group {
                    InfoRow(title: "Drone ID", value: message.uid)
                    InfoRow(title: "Type", value: message.type)
                    InfoRow(title: "Description", value: message.description)
                }
                
                Group {
                    SectionHeader(title: "Position")
                    InfoRow(title: "Latitude", value: message.lat)
                    InfoRow(title: "Longitude", value: message.lon)
                    InfoRow(title: "Altitude", value: "\(message.alt)m")
                    InfoRow(title: "Height AGL", value: "\(message.height)m")
                }
                
                Group {
                    SectionHeader(title: "Movement")
                    InfoRow(title: "Ground Speed", value: "\(message.speed)m/s")
                    InfoRow(title: "Vertical Speed", value: "\(message.vspeed)m/s")
                }
                
                if message.pilotLat != "0.0" && message.pilotLon != "0.0" {
                    Group {
                        SectionHeader(title: "Operator Location")
                        InfoRow(title: "Latitude", value: message.pilotLat)
                        InfoRow(title: "Longitude", value: message.pilotLon)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Drone Details")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    let lat = Double(message.lat) ?? 0
                    let lon = Double(message.lon) ?? 0
                    let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                    let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
                    mapItem.name = message.uid
                    mapItem.openInMaps()
                }) {
                    Image(systemName: "map")
                }
            }
        }
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .foregroundColor(.primary)
        }
    }
}

struct SectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.headline)
            .padding(.top, 8)
    }
}

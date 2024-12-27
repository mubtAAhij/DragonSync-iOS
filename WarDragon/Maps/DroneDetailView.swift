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
                    Annotation(message.uid, coordinate: CLLocationCoordinate2D(
                        latitude: Double(message.lat) ?? 0,
                        longitude: Double(message.lon) ?? 0
                    )) {
                        Image(systemName: message.uaType.icon)
                            .foregroundStyle(.blue)
                    }
                    if flightPath.count > 1 {
                        MapPolyline(coordinates: flightPath)
                            .stroke(.blue, lineWidth: 2)
                    }
                    
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
                    if !message.description.isEmpty {
                        InfoRow(title: "Description", value: message.description)
                    }
                    InfoRow(title: "UA Type", value: message.uaType.rawValue)
                    if let auth = message.authData {
                        InfoRow(title: "Authentication", value: auth)
                    }
                    if let mac = message.mac {
                        InfoRow(title: "MAC", value: mac)
                    }
                }
                
                Group {
                    SectionHeader(title: "Position")
                    InfoRow(title: "Latitude", value: message.lat)
                    InfoRow(title: "Longitude", value: message.lon)
                    InfoRow(title: "Altitude", value: "\(message.alt)m")
                    InfoRow(title: "Height AGL", value: "\(message.height)m")
                    if let altPressure = message.altPressure {
                        InfoRow(title: "Pressure Altitude", value: "\(altPressure)m")
                    }
                    if let heightType = message.heightType {
                        InfoRow(title: "Height Type", value: heightType)
                    }
                }
                
                Group {
                    SectionHeader(title: "Movement")
                    InfoRow(title: "Ground Speed", value: "\(message.speed)m/s")
                    InfoRow(title: "Vertical Speed", value: "\(message.vspeed)m/s")
                    if let direction = message.direction {
                        InfoRow(title: "Direction", value: "\(direction)°")
                    }
                    if let timeSpeed = message.timeSpeed {
                        InfoRow(title: "Time Speed", value: timeSpeed)
                    }
                }
                
                Group {
                    if let auxAdvData = message.rawMessage.lazy
                        .compactMap({ $0.value as? [String: Any] })
                        .first(where: { $0.keys.contains("rssi") }) {
                        
                        SectionHeader(title: "Signal Data")
                        
                        if let rssi = auxAdvData["rssi"] as? Int {
                            InfoRow(title: "RSSI", value: "\(rssi) dBm")
                        }
                        
                        if let channel = auxAdvData["chan"] as? Int {
                            InfoRow(title: "Channel", value: "\(channel)")
                        }
                        
                        if let phy = auxAdvData["phy"] as? Int {
                            InfoRow(title: "PHY", value: "\(phy)")
                        }
                        
                        if let aa = auxAdvData["aa"] as? Int {
                            InfoRow(title: "Access Address", value: String(format: "0x%08X", aa))
                        }
                    }
                }

                
                Group {
                    if message.horizAcc != nil || message.vertAcc != nil || message.baroAcc != nil || message.speedAcc != nil {
                        SectionHeader(title: "Accuracy")
                        
                        if let horizAcc = message.horizAcc {
                            InfoRow(title: "Horizontal", value: "\(horizAcc)m")
                        }
                        if let vertAcc = message.vertAcc {
                            InfoRow(title: "Vertical", value: "\(vertAcc)m")
                        }
                        if let baroAcc = message.baroAcc {
                            InfoRow(title: "Barometric", value: "\(baroAcc)m")
                        }
                        if let speedAcc = message.speedAcc {
                            InfoRow(title: "Speed", value: "\(speedAcc)m/s")
                        }
                    }
                }

                
                if message.pilotLat != "0.0" && message.pilotLon != "0.0" {
                    Group {
                        SectionHeader(title: "Operator Location")
                        InfoRow(title: "Latitude", value: message.pilotLat)
                        InfoRow(title: "Longitude", value: message.pilotLon)
                        if let operatorAltGeo = message.operatorAltGeo {
                            InfoRow(title: "Altitude", value: "\(operatorAltGeo)m")
                        }
                    }
                }
                
                if let areaCount = message.areaCount, areaCount != "0" {
                    Group {
                        SectionHeader(title: "Operation Area")
                        InfoRow(title: "Count", value: areaCount)
                        if let radius = message.areaRadius {
                            InfoRow(title: "Radius", value: "\(radius)m")
                        }
                        if let ceiling = message.areaCeiling {
                            InfoRow(title: "Ceiling", value: "\(ceiling)m")
                        }
                        if let floor = message.areaFloor {
                            InfoRow(title: "Floor", value: "\(floor)m")
                        }
                    }
                }

                if let status = message.status {
                    Group {
                        SectionHeader(title: "System Status")
                        InfoRow(title: "Status Code", value: status)
                        if let classification = message.classification {
                            InfoRow(title: "Classification", value: classification)
                        }
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

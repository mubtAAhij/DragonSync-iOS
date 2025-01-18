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
                .font(.appDefault)
                Group {
                    InfoRow(title: "ID", value: message.uid)
                    if !message.description.isEmpty {
                        InfoRow(title: "Description", value: message.description)
                    }
                    InfoRow(title: "UA Type", value: message.uaType.rawValue)
                    
                    // MAC from multiple sources
                    if let mac = message.mac ??
                        (message.rawMessage["Basic ID"] as? [String: Any])?["MAC"] as? String ??
                        (message.rawMessage["AUX_ADV_IND"] as? [String: Any])?["addr"] as? String {
                        InfoRow(title: "MAC", value: mac)
                    }
                    
                    // RSSI from multiple sources
                    if let rssi = message.rssi ??
                        (message.rawMessage["Basic ID"] as? [String: Any])?["RSSI"] as? Int ??
                        (message.rawMessage["AUX_ADV_IND"] as? [String: Any])?["rssi"] as? Int {
                        InfoRow(title: "RSSI", value: "\(rssi) dBm")
                    }
                }

                Group {
                    SectionHeader(title: "Position")
                    InfoRow(title: "Latitude", value: message.lat)
                    InfoRow(title: "Longitude", value: message.lon)
                    InfoRow(title: "Altitude", value: "\(message.alt)m")
                    if let heightAGL = message.height_type {
                        InfoRow(title: "Height Type", value: "\(heightAGL)m")
                    }
                    if let heightType = message.heightType {
                        InfoRow(title: "Height Type", value: heightType)
                        InfoRow(title: "Operation Status", value: message.op_status ?? "Unknown")
                    }
                    
                }
                
                Group {
                    if let direction = message.direction {
                        SectionHeader(title: "Movement")
                        InfoRow(title: "Direction", value: "\(direction)°")
                        InfoRow(title: "Speed", value: "\(message.speed)m/s")
                        InfoRow(title: "Vertical Speed", value: "\(message.vspeed)m/s")
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
                
                // Operator Section
                if message.operator_id != nil {
                    Group {
                        SectionHeader(title: "Operator")
                        InfoRow(title: "ID", value: message.operator_id ?? "")
                        InfoRow(title: "Type", value: message.operator_id_type ?? "")
                        
                    }
                }
                
                if let aux = message.rawMessage["AUX_ADV_IND"] as? [String: Any],
                   let aext = message.rawMessage["aext"] as? [String: Any] {
                    Group {
                        SectionHeader(title: "Transmission Data")
                        if let rssi = aux["rssi"] as? Int {
                            InfoRow(title: "Signal", value: "\(rssi) dBm")
                        }
                        if let channel = aux["chan"] as? Int {
                            InfoRow(title: "Channel", value: "\(channel)")
                        }
                        if let mode = aext["AdvMode"] as? String {
                            InfoRow(title: "Mode", value: mode)
                        }
                        if let addr = aext["AdvA"] as? String {
                            InfoRow(title: "Address", value: addr)
                        }
                        if let dataInfo = aext["AdvDataInfo"] as? [String: Any] {
                            if let did = dataInfo["did"] as? Int {
                                InfoRow(title: "Data ID", value: "\(did)")
                            }
                            if let sid = dataInfo["sid"] as? Int {
                                InfoRow(title: "Set ID", value: "\(sid)")
                            }
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
        .font(.appSubheadline)
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
            .font(.appHeadline)
            .padding(.top, 8)
    }
}

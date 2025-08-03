//
//  DroneDetailView.swift
//  WarDragon
//
//  Created by Luke on 11/18/24.
//


import SwiftUI
import MapKit

struct DroneDetailView: View {
    let message: CoTViewModel.CoTMessage
    let flightPath: [CLLocationCoordinate2D]
    @ObservedObject var cotViewModel: CoTViewModel
    @State private var mapCameraPosition: MapCameraPosition
    @State private var showAllLocations = true
    
    init(message: CoTViewModel.CoTMessage, flightPath: [CLLocationCoordinate2D], cotViewModel: CoTViewModel) {
        self.message = message
        self.flightPath = flightPath
        self.cotViewModel = cotViewModel
        
        // Calculate map region to show all relevant locations
        let allCoordinates = Self.getAllRelevantCoordinates(message: message, flightPath: flightPath)
        
        if allCoordinates.isEmpty {
            _mapCameraPosition = State(initialValue: .region(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                    span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                )
            ))
        } else {
            let region = Self.calculateRegionForCoordinates(allCoordinates)
            _mapCameraPosition = State(initialValue: .region(region))
        }
    }

    //MARK: - Main Detail View

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Show sections of details
                
                mapSection
            
                droneInfoSection
                
                locationDetailsSection
                
                if !flightPath.isEmpty {
                    flightPathStatsSection
                }
                
                // Signal information
                signalInfoSection
                
                // Raw data section
                rawDataSection
            }
            .padding()
        }
        .navigationTitle(message.uid)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var mapSection: some View {
           VStack(spacing: 8) {
               HStack {
                   Text(String(localized: "flight_map", comment: "Header for flight map section"))
                       .font(.headline)
                   Spacer()
                   Button(action: {
                       showAllLocations.toggle()
                       updateMapRegion()
                   }) {
                       Text(showAllLocations ? String(localized: "drone_only", comment: "Button to show drone location only on map") : String(localized: "show_all", comment: "Button to show all locations on map"))
                           .font(.caption)
                           .padding(.horizontal, 8)
                           .padding(.vertical, 4)
                           .background(.ultraThinMaterial)
                           .cornerRadius(8)
                   }
               }
               
               Map(position: $mapCameraPosition) {
                   // Drone current position
                   if let droneCoordinate = message.coordinate {
                       Annotation(String(localized: "drone", comment: "Map annotation label for drone location"), coordinate: droneCoordinate) {
                           Image(systemName: "airplane")
                               .foregroundStyle(.blue)
                               .background(Circle().fill(.white))
                       }
                   }
                   
                   // Home location
                   if message.homeLat != "0.0" && message.homeLon != "0.0",
                      let homeLat = Double(message.homeLat),
                      let homeLon = Double(message.homeLon) {
                       let homeCoordinate = CLLocationCoordinate2D(latitude: homeLat, longitude: homeLon)
                       Annotation("Home", coordinate: homeCoordinate) {
                           Image(systemName: "house.fill")
                               .foregroundStyle(.green)
                               .background(Circle().fill(.white))
                       }
                   }
                   
                   // Pilot/Operator location
                   if message.pilotLat != "0.0" && message.pilotLon != "0.0",
                      let pilotLat = Double(message.pilotLat),
                      let pilotLon = Double(message.pilotLon) {
                       let pilotCoordinate = CLLocationCoordinate2D(latitude: pilotLat, longitude: pilotLon)
                       Annotation(String(localized: "pilot", comment: "Map annotation label for pilot location"), coordinate: pilotCoordinate) {
                           Image(systemName: "person.fill")
                               .foregroundStyle(.orange)
                               .background(Circle().fill(.white))
                       }
                   }
                   
                   // Flight path polyline
                   if flightPath.count > 1 {
                       MapPolyline(coordinates: flightPath)
                           .stroke(.purple, lineWidth: 3)
                   }
                   
                   // Flight path start and end points
                   if let startPoint = flightPath.first, flightPath.count > 1 {
                       Annotation(String(localized: "start", comment: "Map annotation label for flight start point"), coordinate: startPoint) {
                           Image(systemName: "airplane.departure")
                               .foregroundStyle(.green)
                               .background(Circle().fill(.white))
                       }
                   }
                   if let endPoint = flightPath.last,
                      let startPoint = flightPath.first,
                      flightPath.count > 1,
                      !(endPoint.latitude == startPoint.latitude && endPoint.longitude == startPoint.longitude) {
                       Annotation(String(localized: "latest", comment: "Map annotation label for latest flight position"), coordinate: endPoint) {
                           Image(systemName: "airplane.arrival")
                               .foregroundStyle(.red)
                               .background(Circle().fill(.white))
                       }
                   }
                   
                   // Alert rings if any
                   ForEach(cotViewModel.alertRings.filter { $0.droneId == message.uid }) { ring in
                       MapCircle(center: ring.centerCoordinate, radius: ring.radius)
                           .foregroundStyle(.red.opacity(0.2))
                           .stroke(.red, lineWidth: 2)
                   }
               }
               .frame(height: 300)
               .cornerRadius(12)
           }
       }
    
    
    private var droneInfoSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text(String(localized: "drone_information", comment: "Header for drone information section"))
                    .font(.headline)
                Spacer()
            }
            
            VStack(spacing: 4) {
                DroneInfoRow(title: String(localized: "type", comment: "Label for drone type field"), value: message.type)
                DroneInfoRow(title: "ID", value: message.id)
                DroneInfoRow(title: String(localized: "id_type", comment: "Label for drone ID type field"), value: message.idType)
                if !message.description.isEmpty {
                    DroneInfoRow(title: String(localized: "description", comment: "Label for drone description field"), value: message.description)
                }
                if !message.selfIDText.isEmpty {
                    DroneInfoRow(title: String(localized: "self_id", comment: "Label for drone self-ID field"), value: message.selfIDText)
                }
                if let manufacturer = message.manufacturer {
                    DroneInfoRow(title: String(localized: "manufacturer", comment: "Label for drone manufacturer field"), value: manufacturer)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
        }
    }
    
    private var locationDetailsSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text(String(localized: "location_details", comment: "Header for location details section"))
                    .font(.headline)
                Spacer()
            }
            
            VStack(spacing: 4) {
                // Current position
                DroneInfoRow(title: String(localized: "current_position", comment: "Label for current drone position"), value: "\(message.lat), \(message.lon)")
                DroneInfoRow(title: String(localized: "altitude", comment: "Label for drone altitude"), value: String(localized: "altitude_meters", comment: "Altitude display format in meters").replacingOccurrences(of: "{altitude}", with: "\(message.alt)"))
                if let height = message.height {
                    DroneInfoRow(title: String(localized: "height_agl", comment: "Label for height above ground level"), value: String(localized: "height_meters", comment: "Height display format in meters").replacingOccurrences(of: "{height}", with: "\(height)"))
                }
                if message.speed != "" {
                    DroneInfoRow(title: String(localized: "speed", comment: "Label for drone speed"), value: String(localized: "speed_meters_per_second", comment: "Speed display format in meters per second").replacingOccurrences(of: "{speed}", with: "\(message.speed)"))
                }
                
                DroneInfoRow(title: String(localized: "vertical_speed", comment: "Label for drone vertical speed"), value: String(localized: "vertical_speed_meters_per_second", comment: "Vertical speed display format in meters per second").replacingOccurrences(of: "{vspeed}", with: "\(message.vspeed)"))
                
                // Track data from CoT messages
                let trackData = message.getTrackData()
                if let course = trackData.course, course != "0.0" && !course.isEmpty {
                    DroneInfoRow(title: String(localized: "course", comment: "Label for drone course/heading"), value: String(localized: "course_degrees", comment: "Course display format in degrees").replacingOccurrences(of: "{course}", with: "\(course)"))
                }
                if let speed = trackData.speed, speed != "0.0" {
                    DroneInfoRow(title: String(localized: "track_speed", comment: "Label for drone track speed"), value: String(localized: "track_speed_meters_per_second", comment: "Track speed display format in meters per second").replacingOccurrences(of: "{speed}", with: "\(speed)"))
                }
                if let bearing = trackData.bearing, !bearing.isEmpty {
                    DroneInfoRow(title: String(localized: "bearing", comment: "Label for drone bearing"), value: "\(bearing)°")
                }
                
                Divider()
                
                // Home location
                if message.homeLat != "0.0" && message.homeLon != "0.0" {
                    DroneInfoRow(title: String(localized: "home_location", comment: "Label for drone home location"), value: "\(message.homeLat), \(message.homeLon)")
                }
                
                // Pilot location
                if message.pilotLat != "0.0" && message.pilotLon != "0.0" {
                    DroneInfoRow(title: String(localized: "pilot_location", comment: "Label for pilot location"), value: "\(message.pilotLat), \(message.pilotLon)")
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
        }
    }
    
    private var flightPathStatsSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text(String(localized: "flight_path_statistics", comment: "Header for flight path statistics section"))
                    .font(.headline)
                Spacer()
            }
            
            VStack(spacing: 4) {
                DroneInfoRow(title: String(localized: "total_points", comment: "Label for total flight path points"), value: "\(flightPath.count)")
                
                if flightPath.count > 1 {
                    let distance = calculateTotalDistance()
                    DroneInfoRow(title: String(localized: "total_distance", comment: "Label for total flight distance"), value: String(format: String(localized: "distance_meters_format", comment: "Distance display format in meters"), distance))
                    
                    if let bounds = calculateFlightBounds() {
                        DroneInfoRow(title: String(localized: "area_covered", comment: "Label for area covered by flight"), value: String(format: String(localized: "area_degrees_format", comment: "Area coverage format in degrees"), bounds.latSpan, bounds.lonSpan))
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
        }
    }
    
    private var signalInfoSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text(String(localized: "signal_information", comment: "Header for signal information section"))
                    .font(.headline)
                Spacer()
            }
            
            VStack(spacing: 4) {
                if let rssi = message.rssi {
                    DroneInfoRow(title: "RSSI", value: String(localized: "rssi_dbm_format", comment: "RSSI display format in dBm").replacingOccurrences(of: "{rssi}", with: "\(rssi)"))
                }
                
                if let mac = message.mac {
                    DroneInfoRow(title: String(localized: "mac_address", comment: "Label for MAC address"), value: mac)
                }
                
                // Show MAC randomization if detected
                if let macs = cotViewModel.macIdHistory[message.uid], macs.count > 1 {
                    DroneInfoRow(title: String(localized: "mac_randomization", comment: "Label for MAC randomization status"), value: String(localized: "mac_randomization_detected", comment: "MAC randomization detection message").replacingOccurrences(of: "{count}", with: "\(macs.count)"))
                }
                
                // Show signal sources if available
                if !message.signalSources.isEmpty {
                    DroneInfoRow(title: String(localized: "signal_sources", comment: "Label for signal sources count"), value: "\(message.signalSources.count)")
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
        }
    }
    
    private var rawDataSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text(String(localized: "raw_data", comment: "Header for raw data section"))
                    .font(.headline)
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                Text(formatRawMessage())
                    .font(.system(.caption, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(UIColor.tertiarySystemBackground))
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private static func getAllRelevantCoordinates(message: CoTViewModel.CoTMessage, flightPath: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        var coordinates: [CLLocationCoordinate2D] = []
        
        // Current drone position
        if let droneCoordinate = message.coordinate {
            coordinates.append(droneCoordinate)
        }
        
        // Home location
        if message.homeLat != "0.0" && message.homeLon != "0.0",
           let homeLat = Double(message.homeLat),
           let homeLon = Double(message.homeLon) {
            coordinates.append(CLLocationCoordinate2D(latitude: homeLat, longitude: homeLon))
        }
        
        // Pilot location
        if message.pilotLat != "0.0" && message.pilotLon != "0.0",
           let pilotLat = Double(message.pilotLat),
           let pilotLon = Double(message.pilotLon) {
            coordinates.append(CLLocationCoordinate2D(latitude: pilotLat, longitude: pilotLon))
        }
        
        // Flight path
        coordinates.append(contentsOf: flightPath)
        
        return coordinates
    }
    
    private static func calculateRegionForCoordinates(_ coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard !coordinates.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
        }
        
        let latitudes = coordinates.map(\.latitude)
        let longitudes = coordinates.map(\.longitude)
        
        let minLat = latitudes.min() ?? 0
        let maxLat = latitudes.max() ?? 0
        let minLon = longitudes.min() ?? 0
        let maxLon = longitudes.max() ?? 0
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        let deltaLat = max((maxLat - minLat) * 1.3, 0.01) // Add 30% padding, minimum 0.01°
        let deltaLon = max((maxLon - minLon) * 1.3, 0.01)
        
        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: deltaLat, longitudeDelta: deltaLon)
        )
    }
    
    private func updateMapRegion() {
        let coordinates = showAllLocations
        ? Self.getAllRelevantCoordinates(message: message, flightPath: flightPath)
        : message.coordinate.map { [$0] } ?? []
        
        let region = Self.calculateRegionForCoordinates(coordinates)
        
        withAnimation(.easeInOut(duration: 0.5)) {
            mapCameraPosition = .region(region)
        }
    }
    
    private func calculateTotalDistance() -> Double {
        guard flightPath.count > 1 else { return 0 }
        
        var totalDistance: Double = 0
        for i in 1..<flightPath.count {
            let location1 = CLLocation(latitude: flightPath[i-1].latitude, longitude: flightPath[i-1].longitude)
            let location2 = CLLocation(latitude: flightPath[i].latitude, longitude: flightPath[i].longitude)
            totalDistance += location1.distance(from: location2)
        }
        return totalDistance
    }
    
    private func calculateFlightBounds() -> (latSpan: Double, lonSpan: Double)? {
        guard flightPath.count > 1 else { return nil }
        
        let latitudes = flightPath.map(\.latitude)
        let longitudes = flightPath.map(\.longitude)
        
        let minLat = latitudes.min() ?? 0
        let maxLat = latitudes.max() ?? 0
        let minLon = longitudes.min() ?? 0
        let maxLon = longitudes.max() ?? 0
        
        return (latSpan: maxLat - minLat, lonSpan: maxLon - minLon)
    }
    
    private func formatRawMessage() -> String {
        // Remove the unnecessary cast since rawMessage is already [String: Any]
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: message.rawMessage, options: .prettyPrinted)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                return jsonString
            }
        } catch {
            return "Error formatting raw data: \(error.localizedDescription)"
        }
        return "No raw data available"
    }
}

struct DroneInfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

//
//  MapView.swift
//  WarDragon
//
//  Created by Luke on 11/18/24.
//

import SwiftUI
import MapKit

struct MapView: View {
    let message: CoTViewModel.CoTMessage
    @State private var region: MKCoordinateRegion
    @State private var showDetail = false
    
    init(message: CoTViewModel.CoTMessage) {
        self.message = message
        let lat = Double(message.lat) ?? 0
        let lon = Double(message.lon) ?? 0
        _region = State(initialValue: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
    }
    
    var body: some View {
        Map {
            Marker(message.uid, coordinate: CLLocationCoordinate2D(
                latitude: Double(message.lat) ?? 0,
                longitude: Double(message.lon) ?? 0
            ))
        }
        .frame(height: 200)
        .onTapGesture {
            showDetail = true  // Show detail instead of opening Maps directly
        }
        .sheet(isPresented: $showDetail) {
            NavigationView {
                DroneDetailView(
                    message: message,
                    flightPath: []  // Single location view doesn't have flight path
                )
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showDetail = false
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }
}

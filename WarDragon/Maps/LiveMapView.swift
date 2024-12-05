//
//  LiveMapView.swift
//  WarDragon
//
//  Created by Luke on 11/18/24.
//

// LiveMapView.swift

import SwiftUI
import MapKit

struct LiveMapView: View {
    @ObservedObject var cotViewModel: CoTViewModel
    @State private var region: MKCoordinateRegion
    @State private var showDroneList = false
    let timer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()
    
    init(cotViewModel: CoTViewModel, initialMessage: CoTViewModel.CoTMessage) {
        self.cotViewModel = cotViewModel
        let lat = Double(initialMessage.lat) ?? 0
        let lon = Double(initialMessage.lon) ?? 0
        _region = State(initialValue: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        ))
    }
    
    // Add computed property for unique drones
    private var uniqueDrones: [CoTViewModel.CoTMessage] {
        var latestDronePositions: [String: CoTViewModel.CoTMessage] = [:]
        for message in cotViewModel.parsedMessages {
            latestDronePositions[message.uid] = message
        }
        return Array(latestDronePositions.values)
    }
    
    var body: some View {
        ZStack {
            Map {
                // Use uniqueDrones instead of parsedMessages
                ForEach(uniqueDrones) { message in
                    if let coordinate = message.coordinate {
                        Marker(message.uid, coordinate: coordinate)
                            .tint(message.uid == uniqueDrones.last?.uid ? .red : .blue)
                    }
                }
            }
            
            VStack {
                Spacer()
                
                // Update count to use uniqueDrones
                Button(action: { showDroneList.toggle() }) {
                    Text("\(uniqueDrones.count) Drones")
                        .padding()
                        .background(Color.black)
                        .cornerRadius(20)
                }
                .padding(.bottom)
            }
        }
        .sheet(isPresented: $showDroneList) {
            NavigationView {
                // Update list to use uniqueDrones
                List(uniqueDrones) { message in
                    VStack(alignment: .leading) {
                        Text(message.uid)
                            .font(.headline)
                        Text("Position: \(message.lat), \(message.lon)")
                            .font(.caption)
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
            // Update to use uniqueDrones for latest position
            if let latestMessage = uniqueDrones.last,
               let lat = Double(latestMessage.lat),
               let lon = Double(latestMessage.lon) {
                withAnimation {
                    region.center = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                }
            }
        }
    }
}

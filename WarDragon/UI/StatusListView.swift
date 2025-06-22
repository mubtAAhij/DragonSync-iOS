//
//  StatusListView.swift
//  WarDragon
//
//  Created by Luke on 11/18/24.
//

import SwiftUI
import MapKit
import CoreLocation

struct StatusListView: View {
    @ObservedObject var statusViewModel: StatusViewModel
    @ObservedObject var cotViewModel: CoTViewModel
    @StateObject private var serviceViewModel = ServiceViewModel()
    @State private var showServiceManagement = false
    
    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                List {
                    // We'll create flight paths from the parsed messages instead
                    let messagesWithCoordinates = cotViewModel.parsedMessages.filter {
                        $0.coordinate != nil && $0.coordinate!.latitude != 0 && $0.coordinate!.longitude != 0
                    }
                    
//                    if !messagesWithCoordinates.isEmpty {
//                        Section("Active Drones") {
//                            ForEach(messagesWithCoordinates) { message in
//                                ActiveDroneRow(message: message)
//                            }
//                        }
//                    }
                    
                    // System status messages
                    Section("System Status") {
                        ForEach(statusViewModel.statusMessages) { message in
                            StatusMessageView(message: message)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(minHeight: geometry.size.height, alignment: .center)
                .onChange(of: statusViewModel.statusMessages.count) { _, _ in
                    if let latest = statusViewModel.statusMessages.last {
                        withAnimation {
                            proxy.scrollTo(latest.id, anchor: .bottom)
                        }
                    }
                }
                // Option to start/stop status listening (needs handler to see if running)
//                .onAppear {
//                    serviceViewModel.startMonitoring()
//                }
//                .onDisappear {
//                    serviceViewModel.stopMonitoring()
//                }
            }
        }
        .navigationTitle("System Status")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(action: { statusViewModel.statusMessages.removeAll() }) {
                        Label("Clear Status", systemImage: "trash")
                    }
                    Button(action: { showServiceManagement = true }) {
                        Label("Services", systemImage: "gearshape.2")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showServiceManagement) {
            NavigationView {
                ServiceManagementView(viewModel: serviceViewModel)
                    .navigationTitle("Service Management")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Done") {
                                showServiceManagement = false
                            }
                        }
                    }
            }
            // Force the status monitor ZMQ/Multicast to listen when tapping system services
//            .onAppear {
//                    serviceViewModel.startMonitoring()
//            }
//            .onDisappear {
//                    serviceViewModel.stopMonitoring()
//            }
        }
    }
}

struct DroneConnectionRow: View {
    let message: CoTViewModel.CoTMessage
    let cotViewModel: CoTViewModel
    
    var body: some View {
        HStack {
            Circle()
                .fill(message.connectionStatus.color)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(message.uid)
                    .font(.appHeadline)
                Text(message.connectionStatus.description)
                    .font(.appCaption)
                    .foregroundColor(message.connectionStatus.color)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                if let rssi = message.rssi {
                    Text("\(rssi) dBm")
                        .font(.appCaption)
                        .foregroundColor(.secondary)
                }
                Text(formatLastSeen(Double(message.timestamp ?? "0") ?? 0))
                    .font(.appCaption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatLastSeen(_ timestamp: Double) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// Replace FlightPathRow with ActiveDroneRow since we don't have flight paths
struct ActiveDroneRow: View {
    let message: CoTViewModel.CoTMessage
    
    var body: some View {
        HStack {
            Image(systemName: "video")
                .foregroundStyle(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(message.id)
                    .font(.appHeadline)
                if let coordinate = message.coordinate {
                    Text("Lat: \(coordinate.latitude, specifier: "%.4f"), Lon: \(coordinate.longitude, specifier: "%.4f")")
                        .font(.appCaption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(message.alt) m")
                    .font(.appCaption)
                Text("\(message.speed) m/s")
                    .font(.appCaption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ServiceStatusWidget: View {
    let healthReport: ServiceViewModel.HealthReport?
    let criticalServices: [ServiceControl]
    @Binding var showServiceManagement: Bool
    
    var body: some View {
        Button(action: { showServiceManagement = true }) {
            VStack(spacing: 4) {
                HStack {
                    Circle()
                        .fill(.gray)
                        .frame(width: 12, height: 12)
                    
                    Text("SERVICE STATUS")
                        .font(.appHeadline)
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

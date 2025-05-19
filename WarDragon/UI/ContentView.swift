//
//  ContentView.swift
//  WarDragon
//
//  Created by Luke on 11/18/24.
//

import SwiftUI
import Network
import UserNotifications

struct ContentView: View {
    @StateObject private var statusViewModel = StatusViewModel()
    @StateObject private var spectrumViewModel = SpectrumData.SpectrumViewModel()
    @StateObject private var droneStorage = DroneStorageManager.shared
    @StateObject private var cotViewModel: CoTViewModel
    @StateObject private var settings = Settings.shared
    @State private var showAlert = false
    @State private var latestMessage: CoTViewModel.CoTMessage?
    @State private var selectedTab: Int
    
    
    init() {
        // Create temporary non-StateObject instances for initialization
        let statusVM = StatusViewModel()
        let cotVM = CoTViewModel(statusViewModel: statusVM)
        
        // Initialize the StateObject properties
        self._statusViewModel = StateObject(wrappedValue: statusVM)
        self._cotViewModel = StateObject(wrappedValue: cotVM)
        self._selectedTab = State(initialValue: Settings.shared.isListening ? 0 : 3)
        
        // Configure background manager with the created instance, not the StateObject wrapper
        BackgroundManager.shared.configure(with: cotVM)
        
        // Add lightweight connection check listener
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("LightweightConnectionCheck"),
            object: nil,
            queue: .main
        ) { [weak cotVM] _ in
            cotVM?.checkConnectionStatus()
        }
        
        // Add notification for background task expiry
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("BackgroundTaskExpiring"),
            object: nil,
            queue: .main
        ) { [weak cotVM] _ in
            // Perform urgent cleanup when background task is about to expire
            cotVM?.prepareForBackgroundExpiry()
        }
    }
    
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                DashboardView(
                    statusViewModel: statusViewModel,
                    cotViewModel: cotViewModel,
                    spectrumViewModel: spectrumViewModel
                )
                .navigationTitle("Dashboard")
            }
            .tabItem {
                Label("Dashboard", systemImage: "gauge")
            }
            .tag(0)
            
            NavigationStack {
                VStack {
                    ScrollViewReader { proxy in
                        List(cotViewModel.parsedMessages) { item in
                            MessageRow(message: item, cotViewModel: cotViewModel)
                        }
                        .listStyle(.inset)
                        .onChange(of: cotViewModel.parsedMessages) { oldMessages, newMessages in
                            // Only proceed if we have more messages than before
                            if oldMessages.count < newMessages.count {
                                // Get the newest message
                                if let latest = newMessages.last {
                                    // Check if this message ID wasn't in the old messages
                                    if !oldMessages.contains(where: { $0.id == latest.id }) {
                                        latestMessage = latest
                                        showAlert = false
                                        withAnimation {
                                            proxy.scrollTo(latest.id, anchor: .bottom)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .navigationTitle("DragonSync")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button(action: {
                                cotViewModel.parsedMessages.removeAll()
                                cotViewModel.droneSignatures.removeAll()
                                cotViewModel.macIdHistory.removeAll()
                                cotViewModel.macProcessing.removeAll()
                                cotViewModel.alertRings.removeAll()
                            }) {
                                Label("Clear All", systemImage: "trash")
                            }
                            
                            // Add option to clear just active tracking but keep history
                            Button(action: {
                                cotViewModel.parsedMessages.removeAll()
                                cotViewModel.droneSignatures.removeAll()
                                cotViewModel.alertRings.removeAll()
                            }) {
                                Label("Stop All Tracking", systemImage: "eye.slash")
                            }
                            
                            // Add option to delete all from history
                            Button(role: .destructive, action: {
                                droneStorage.deleteAllEncounters()
                                cotViewModel.parsedMessages.removeAll()
                                cotViewModel.droneSignatures.removeAll()
                                cotViewModel.macIdHistory.removeAll()
                                cotViewModel.macProcessing.removeAll()
                                cotViewModel.alertRings.removeAll()
                            }) {
                                Label("Delete All History", systemImage: "trash.fill")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                .alert("New Message", isPresented: $showAlert) {
                    Button("OK", role: .cancel) {}
                } message: {
                    if let message = latestMessage {
                        Text("From: \(message.uid)\nType: \(message.type)\nLocation: \(message.lat), \(message.lon)")
                    }
                }
            }
            
            .tabItem {
                Label("Drones", systemImage: "airplane.circle")
            }
            .tag(1)
            
            NavigationStack {
                StatusListView(statusViewModel: statusViewModel)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(action: { statusViewModel.statusMessages.removeAll() }) {
                                Image(systemName: "trash")
                            }
                        }
                    }
            }
            .tabItem {
                Label("Status", systemImage: "server.rack")
            }
            .tag(2)
            
            NavigationStack {
                SettingsView(cotHandler: cotViewModel)
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
            .tag(3)
            NavigationStack {
                StoredEncountersView(cotViewModel: cotViewModel)
            }
            .tabItem {
                Label("History", systemImage: "clock.arrow.circlepath")
            }
            .tag(4)
            
//            NavigationStack {
//                SpectrumView(viewModel: spectrumViewModel)
//                    .navigationTitle("Spectrum")
//            }
//            .tabItem {
//                Label("Spectrum", systemImage: "waveform")
//            }
//            .tag(4)
        }
        
        .onChange(of: settings.isListening) {
            if settings.isListening {
                cotViewModel.startListening()
            } else { 
                cotViewModel.stopListening()
            }
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            if newValue != 3 { // Spectrum tab
//                spectrumViewModel.stopListening()
            } else if settings.isListening {
                let port = UInt16(UserDefaults.standard.integer(forKey: "spectrumPort"))
//                spectrumViewModel.startListening(port: port)
            }
        }
        .onChange(of: settings.connectionMode) {
            if settings.isListening {
                // Handle switch when enabled, for now just do not allow
            }
        }
    }
    
    
}

//
//  ContentView.swift
//  WarDragon
//
//  Created by Luke on 11/18/24.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var cotViewModel = CoTViewModel()
    @State private var isListening = false
    @State private var showAlert = false
    @State private var latestMessage: CoTViewModel.CoTMessage?
    
    var body: some View {
        NavigationStack {
            VStack {
                ScrollViewReader { proxy in
                    List(cotViewModel.parsedMessages) { item in
                        MessageRow(message: item, cotViewModel: cotViewModel)
                    }
                    .listStyle(.inset)
                    .onChange(of: cotViewModel.parsedMessages) { _, messages in
                        if let latest = messages.last {
                            latestMessage = latest
                            showAlert = false
                            withAnimation {
                                proxy.scrollTo(latest.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                Button(isListening ? "Stop Listening" : "Start Listening") {
                    isListening.toggle()
                    if isListening {
                        cotViewModel.startListening()
                    } else {
                        cotViewModel.stopListening()
                    }
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
            .navigationTitle("DragonLink")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { cotViewModel.parsedMessages.removeAll() }) {
                        Image(systemName: "trash")
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
    }
}

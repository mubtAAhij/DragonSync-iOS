//
//  FAALookupButton.swift
//  WarDragon
//
//  Created by Luke on 4/25/25.
//

import SwiftUI


struct FAALookupButton: View {
    let mac: String?
    let remoteId: String?
    @StateObject private var faaService = FAAService.shared
    @State private var showingFAAInfo = false
    @State private var showingError = false
    @State private var faaData: [String: Any]?
    @State private var isLoading = false
    
    var body: some View {
        Group {
            if let mac = mac, let remoteId = remoteId {
                Button(action: {
                    isLoading = true
                    Task {
                        if let data = await faaService.queryFAAData(mac: mac, remoteId: remoteId) {
                            faaData = data
                            showingFAAInfo = true
                        } else if let error = faaService.error {
                            showingError = true
                        }
                        isLoading = false
                    }
                }) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "airplane.departure")
                        }
                        Text(isLoading ? String(localized: "loading", comment: "Loading state text") : String(localized: "faa_lookup", comment: "FAA lookup button text"))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isLoading ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(faaService.isFetching || isLoading)
                .alert(String(localized: "faa_lookup_error", comment: "FAA lookup error alert title"), isPresented: $showingError) {
                    Button(String(localized: "ok_button", comment: "OK button in alert dialog"), role: .cancel) {}
                } message: {
                    Text(faaService.error ?? String(localized: "unknown_error_occurred", comment: "Error message when an unknown error occurs"))
                }
            }
        }
        .sheet(isPresented: $showingFAAInfo) {
            if let data = faaData {
                ZStack {
                    Color.clear
                    VStack(spacing: 0) {
                        HStack {
                            Spacer()
                            Button(String(localized: "done_button", comment: "Done button to close sheet")) {
                                showingFAAInfo = false
                            }
                            .padding(.trailing)
                            .padding(.top, 8)
                        }
                        .background(Color.clear)
                        
                        // FAA Info View
                        FAAInfoView(faaData: data)
                            .padding(.horizontal)
                    }
                }
                .background(Color.clear)
                .presentationDetents([.height(350)]) // TODO dont hardcode this 
                .presentationBackground(.clear)
                .presentationDragIndicator(.visible)
            }
        }
    }
}

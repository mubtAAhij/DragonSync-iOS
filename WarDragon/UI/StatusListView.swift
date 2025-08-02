//
//  StatusListView.swift
//  WarDragon
//
//  Created by Luke on 11/18/24.
//

import SwiftUI

struct StatusListView: View {
    @ObservedObject var statusViewModel: StatusViewModel
    @StateObject private var serviceViewModel = ServiceViewModel()
    @State private var showServiceManagement = false
    @State private var showingDeleteConfirmation = false
    @State private var messageToDelete: StatusViewModel.StatusMessage?
    
    private func deleteMessage(_ message: StatusViewModel.StatusMessage) {
        messageToDelete = message
        showingDeleteConfirmation = true
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                List {
                    // Real-time status header
                    Section {
                        StatusConnectionHeaderView(statusViewModel: statusViewModel)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    
                    // System status messages
                    Section {
                        ForEach(statusViewModel.statusMessages) { message in
                            StatusMessageView(message: message, statusViewModel: statusViewModel)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        deleteMessage(message)
                                    } label: {
                                        Label(String(localized: "delete", comment: "Delete button"), systemImage: "trash")
                                    }
                                }
                                .contextMenu {
                                    Button(role: .destructive, action: {
                                        deleteMessage(message)
                                    }) {
                                        Label(String(localized: "delete", comment: "Delete button"), systemImage: "trash")
                                    }
                                }
                        }
                        .onDelete(perform: statusViewModel.deleteStatusMessages)
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
                .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
                    // Force UI update every second to refresh "last received" times
                    statusViewModel.objectWillChange.send()
                }
            }
        }
        .navigationTitle(String(localized: "system_status", comment: "System status navigation title"))
        .sheet(isPresented: $showServiceManagement) {
            NavigationView {
                ServiceManagementView(viewModel: serviceViewModel)
                    .navigationTitle(String(localized: "service_management", comment: "Service management title"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(String(localized: "done", comment: "Done button")) {
                                showServiceManagement = false
                            }
                        }
                    }
            }
        }
        .alert(String(localized: "delete_message", comment: "Delete message alert title"), isPresented: $showingDeleteConfirmation) {
            Button(String(localized: "delete", comment: "Delete button text"), role: .destructive) {
                if let message = messageToDelete,
                   let index = statusViewModel.statusMessages.firstIndex(where: { $0.id == message.id }) {
                    statusViewModel.deleteStatusMessages(at: IndexSet([index]))
                }
                messageToDelete = nil
            }
            Button(String(localized: "cancel", comment: "Cancel button text"), role: .cancel) {
                messageToDelete = nil
            }
        } message: {
            Text(String(localized: "delete_status_message_confirmation", comment: "Confirmation message for deleting status message"))
        }
    }
    
}

// MARK: - Connection Status Header
struct StatusConnectionHeaderView: View {
    @ObservedObject var statusViewModel: StatusViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(statusViewModel.statusColor)
                        .frame(width: 12, height: 12)
                    
                    Text(String(localized: "system_connection", comment: "System connection status header"))
                        .font(.system(.headline, design: .monospaced))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(statusViewModel.statusText)
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundColor(statusViewModel.statusColor)
                        .fontWeight(.semibold)
                }
            }
            
            if let lastReceived = statusViewModel.lastStatusMessageReceived {
                HStack {
                    Text(String(localized: "last_message_received", comment: "Label for last message received time"))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(statusViewModel.lastReceivedText)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(statusViewModel.isSystemOnline ? .green : .red)
                            .fontWeight(.medium)
                        
                        Text(lastReceived, style: .time)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                HStack {
                    Text(String(localized: "no_status_messages_received", comment: "Message when no status messages have been received"))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            
            // Connection quality indicator
            HStack {
                Text(String(localized: "connection_reliability", comment: "Label for connection reliability indicator"))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                connectionQualityView
            }
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    statusViewModel.statusColor.opacity(0.1),
                    statusViewModel.statusColor.opacity(0.05)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var connectionQualityView: some View {
        let quality = connectionQuality
        
        HStack(spacing: 2) {
            ForEach(0..<4) { index in
                Rectangle()
                    .fill(index < quality.bars ? quality.color : Color.gray.opacity(0.3))
                    .frame(width: 4, height: CGFloat(6 + index * 2))
                    .cornerRadius(1)
            }
        }
    }
    
    private var connectionQuality: (bars: Int, color: Color) {
        guard let lastReceived = statusViewModel.lastStatusMessageReceived else {
            return (0, .red)
        }
        
        let timeSinceLastMessage = Date().timeIntervalSince(lastReceived)
        
        switch timeSinceLastMessage {
        case 0..<90:        // Less than 1.5 minutes - excellent
            return (4, .green)
        case 90..<180:      // 1.5-3 minutes - good
            return (3, .green)
        case 180..<300:     // 3-5 minutes - fair
            return (2, .yellow)
        case 300..<600:     // 5-10 minutes - weak
            return (1, .orange)
        default:            // 10+ minutes - poor/offline
            return (0, .red)
        }
    }
}

struct ServiceStatusWidget: View {
    let healthReport: ServiceViewModel.HealthReport?
    let criticalServices: [ServiceControl]
    @Binding var showServiceManagement: Bool
    
    var body: some View {
        Button(action: { showServiceManagement = true }) {
            VStack(spacing: 4) {
                // Health Status Bar
                HStack(spacing: 12) {
                    Circle()
                        .fill(healthReport?.statusColor ?? .gray)
                        .frame(width: 12, height: 12)
                    
                    Text(healthReport?.overallHealth.uppercased() ?? String(localized: "no_connection", comment: "No connection status text"))
                        .font(.appHeadline)
                    
                    Spacer()
                    
                    Text(healthReport?.timestamp.formatted(date: .omitted, time: .standard) ?? "")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                
                // Critical Services Summary
                if !criticalServices.isEmpty {
                    HStack {
                        Text(String(localized: "critical_issues_count", comment: "Critical issues count label").replacingOccurrences(of: "{count}", with: "\(criticalServices.count)"))
                            .font(.appCaption)
                            .foregroundColor(.red)
                        Spacer()
                    }
                    .padding(.horizontal)
                }
            }
        }
        .buttonStyle(.plain)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

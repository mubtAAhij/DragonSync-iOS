//
//  DroneInfoEditor.swift
//  WarDragon
//
//  Created by Luke on 4/6/25.
//

import Foundation
import SwiftUI

struct DroneInfoEditor: View {
    let droneId: String
    @State private var customName: String
    @State private var trustStatus: DroneSignature.UserDefinedInfo.TrustStatus
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var droneStorage = DroneStorageManager.shared
    
    init(droneId: String) {
        self.droneId = droneId
        let encounter = DroneStorageManager.shared.encounters[droneId]
        _customName = State(initialValue: encounter?.customName ?? "")
        _trustStatus = State(initialValue: encounter?.trustStatus ?? .unknown)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField(String(localized: "drone_name_field", comment: "Drone name input field placeholder"), text: $customName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.appDefault)
                .padding(.bottom, 8)
            
            Text(String(localized: "trust_status_label", comment: "Trust status section label"))
                .font(.appSubheadline)
                .padding(.bottom, 4)
            
            HStack(spacing: 16) {
                TrustButton(
                    title: String(localized: "trust_status_trusted", comment: "Trusted status option"),
                    icon: "checkmark.shield.fill",
                    color: .green,
                    isSelected: trustStatus == .trusted,
                    action: { trustStatus = .trusted }
                )
                
                TrustButton(
                    title: "Unknown",
                    icon: "shield.fill",
                    color: .gray,
                    isSelected: trustStatus == .unknown,
                    action: { trustStatus = .unknown }
                )
                
                TrustButton(
                    title: String(localized: "trust_status_untrusted", comment: "Untrusted status option"),
                    icon: "xmark.shield.fill",
                    color: .red,
                    isSelected: trustStatus == .untrusted,
                    action: { trustStatus = .untrusted }
                )
            }
            .padding(.bottom, 16)
            
            Button(action: saveChanges) {
                Text(String(localized: "save_button", comment: "Save button text"))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func saveChanges() {
        // Use the proper method in DroneStorageManager
        DroneStorageManager.shared.updateDroneInfo(
            id: droneId,
            name: customName,
            trustStatus: trustStatus
        )
        dismiss()
    }

}

struct TrustButton: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .white : color)
                Text(title)
                    .font(.appCaption)
                    .foregroundColor(isSelected ? .white : color)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? color : Color.clear)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(color, lineWidth: 2)
            )
        }
    }
}

//
//  FAAInfoView.swift
//  WarDragon
//
//  Created by Luke on 4/25/25.
//

import SwiftUI

struct FAAInfoView: View {
    let faaData: [String: Any]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FAA REGISTRATION")
                .font(.appHeadline)
                .frame(maxWidth: .infinity, alignment: .center)
            
            if let items = faaData["items"] as? [[String: Any]],
               let firstItem = items.first {
                InfoRow(title: "Status", value: firstItem["status"] as? String ?? "Unknown")
                InfoRow(title: "Brand", value: firstItem["brand"] as? String ?? "Unknown")
                InfoRow(title: "Model", value: firstItem["model"] as? String ?? "Unknown")
                InfoRow(title: "Manufacturer Code", value: firstItem["manufacturerCode"] as? String ?? "Unknown")
                InfoRow(title: "Product Type", value: firstItem["productType"] as? String ?? "Unknown")
                InfoRow(title: "Operation Rules", value: firstItem["operationRules"] as? String ?? "Unknown")
            } else if let data = faaData["data"] as? [String: Any],
                      let items = data["items"] as? [[String: Any]],
                      let firstItem = items.first {
                // Handle nested data structure
                InfoRow(title: "Make", value: firstItem["makeName"] as? String ?? "Unknown")
                InfoRow(title: "Model", value: firstItem["modelName"] as? String ?? "Unknown")
                InfoRow(title: "Series", value: firstItem["series"] as? String ?? "Unknown")
                InfoRow(title: "Remote ID", value: firstItem["trackingNumber"] as? String ?? "Unknown")
                InfoRow(title: "Compliance", value: firstItem["complianceCategories"] as? String ?? "Unknown")
                InfoRow(title: "Updated", value: firstItem["updatedAt"] as? String ?? "Unknown")
            } else {
                // Show more debug info when no data is available
                Text("No registration data found")
                    .font(.appCaption)
                    .foregroundColor(.secondary)
                    .padding()
                
                // Debug info
                Text("Response Structure:")
                    .font(.appCaption)
                    .foregroundColor(.secondary)
                Text(debugDescription(for: faaData))
                    .font(.appCaption)
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func debugDescription(for data: [String: Any]) -> String {
        var description = ""
        for (key, value) in data {
            if let dictValue = value as? [String: Any] {
                description += "\(key): [nested dictionary with \(dictValue.count) items]\n"
            } else if let arrayValue = value as? [[String: Any]] {
                description += "\(key): [array with \(arrayValue.count) items]\n"
            } else {
                description += "\(key): \(type(of: value))\n"
            }
        }
        return description.isEmpty ? "Empty response" : description
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    
    
    var body: some View {
        HStack {
            Text(title)
                .font(.appHeadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.appCaption)
                .foregroundColor(.primary)
        }
    }
}

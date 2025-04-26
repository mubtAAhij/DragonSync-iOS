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
        VStack(alignment: .leading, spacing: 8) {
            Text("FAA REGISTRATION")
                .font(.appHeadline)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 5)

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
                InfoRow(title: "Make", value: firstItem["makeName"] as? String ?? "Unknown")
                InfoRow(title: "Model", value: firstItem["modelName"] as? String ?? "Unknown")
                InfoRow(title: "Series", value: firstItem["series"] as? String ?? "Unknown")
                InfoRow(title: "Remote ID", value: firstItem["trackingNumber"] as? String ?? "Unknown")
                InfoRow(title: "Compliance", value: firstItem["complianceCategories"] as? String ?? "Unknown")
                InfoRow(title: "Updated", value: firstItem["updatedAt"] as? String ?? "Unknown")
            } else {
                VStack {
                    Text("No registration data found")
                        .font(.appCaption)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 5)

                    Text("Response Structure:")
                        .font(.appCaption)
                        .foregroundColor(.secondary)
                    Text(debugDescription(for: faaData))
                        .font(.appCaption)
                        .foregroundColor(.red)
                }
                .frame(maxWidth: .infinity, alignment: .center)
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
                description += "\(key): [dictionary: \(dictValue.count) items]\n"
            } else if let arrayValue = value as? [[String: Any]] {
                description += "\(key): [array: \(arrayValue.count) items]\n"
            } else {
                description += "\(key): \(type(of: value))\n"
            }
        }
        return String(description.prefix(300)) + (description.count > 300 ? "..." : "")
    }
}

struct InfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.appHeadline)
                .foregroundColor(.secondary)
                .layoutPriority(1)

            Spacer()

            Text(value)
                .font(.appCaption)
                .foregroundColor(.primary)
                .multilineTextAlignment(.trailing)
                .lineLimit(nil)
        }
        .frame(minHeight: 20)
    }
}

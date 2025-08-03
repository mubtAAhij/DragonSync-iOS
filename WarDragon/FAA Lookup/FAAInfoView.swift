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
            Text(String(localized: "faa_registration_header", defaultValue: "FAA REGISTRATION", comment: "Header text for FAA registration information"))
                .font(.appHeadline)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 5)

            if let items = faaData["items"] as? [[String: Any]],
               let firstItem = items.first {
                InfoRow(title: String(localized: "faa_status_label", defaultValue: "Status", comment: "Label for FAA registration status"), value: firstItem["status"] as? String ?? "Unknown")
                InfoRow(title: String(localized: "faa_brand_label", defaultValue: "Brand", comment: "Label for drone brand"), value: firstItem["brand"] as? String ?? "Unknown")
                InfoRow(title: "Model", value: firstItem["model"] as? String ?? "Unknown")
                InfoRow(title: String(localized: "faa_manufacturer_code_label", defaultValue: "Manufacturer Code", comment: "Label for manufacturer code"), value: firstItem["manufacturerCode"] as? String ?? "Unknown")
                InfoRow(title: String(localized: "faa_product_type_label", defaultValue: "Product Type", comment: "Label for product type"), value: firstItem["productType"] as? String ?? "Unknown")
                InfoRow(title: String(localized: "faa_operation_rules_label", defaultValue: "Operation Rules", comment: "Label for operation rules"), value: firstItem["operationRules"] as? String ?? "Unknown")
            } else if let data = faaData["data"] as? [String: Any],
                      let items = data["items"] as? [[String: Any]],
                      let firstItem = items.first {
                InfoRow(title: String(localized: "faa_make_label", defaultValue: "Make", comment: "Label for drone make"), value: firstItem["makeName"] as? String ?? "Unknown")
                InfoRow(title: "Model", value: firstItem["modelName"] as? String ?? "Unknown")
                InfoRow(title: String(localized: "faa_series_label", defaultValue: "Series", comment: "Label for drone series"), value: firstItem["series"] as? String ?? "Unknown")
                InfoRow(title: String(localized: "faa_remote_id_label", defaultValue: "Remote ID", comment: "Label for remote ID"), value: firstItem["trackingNumber"] as? String ?? "Unknown")
                InfoRow(title: String(localized: "faa_compliance_label", defaultValue: "Compliance", comment: "Label for compliance status"), value: firstItem["complianceCategories"] as? String ?? "Unknown")
                InfoRow(title: String(localized: "faa_updated_label", defaultValue: "Updated", comment: "Label for last updated date"), value: firstItem["updatedAt"] as? String ?? "Unknown")
            } else {
                VStack {
                    Text(String(localized: "faa_no_data_found", defaultValue: "No registration data found", comment: "Message when no FAA registration data is available"))
                        .font(.appCaption)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 5)

                    Text(String(localized: "faa_response_structure_label", defaultValue: "Response Structure:", comment: "Label for debugging response structure"))
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

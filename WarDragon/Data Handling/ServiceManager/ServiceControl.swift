//
//  ServiceControl.swift
//  WarDragon
//
//  Created by Luke on 1/10/25.
//

import Foundation
import SwiftUI

struct ServiceControl: Identifiable, Hashable {
    let id: String
    let service: String
    let category: ServiceCategory
    let description: String
    let dependencies: [String]
    let isCritical: Bool
    var status: ServiceStatus
    var resources: ResourceUsage?
    var issues: [ServiceIssue]
    
    enum ServiceCategory: String {
        case radio = "radio"
        case sensors = "sensors"
        case comms = "comms"
        
        var icon: String {
            switch self {
            case .radio: return "antenna.radiowaves.left.and.right"
            case .sensors: return "sensor"
            case .comms: return "network"
            }
        }
        
        var color: Color {
            switch self {
            case .radio: return .blue
            case .sensors: return .green
            case .comms: return .orange
            }
        }
    }
    
    struct ServiceStatus {
        var isActive: Bool
        var isEnabled: Bool
        var statusText: String
        var rawStatus: String?
        var healthStatus: HealthStatus
        
        enum HealthStatus {
            case healthy
            case warning
            case critical
            case unknown
            
            var color: Color {
                switch self {
                case .healthy: return .green
                case .warning: return .yellow
                case .critical: return .red
                case .unknown: return .gray
                }
            }
        }
    }
    
    struct ResourceUsage: Hashable {
        var cpuPercent: Double
        var memoryPercent: Double
    }
    
    struct ServiceIssue: Identifiable, Hashable {
        let id = UUID()
        let message: String
        let severity: IssueSeverity
        
        enum IssueSeverity: Hashable {
            case high
            case medium
            case warning
            
            var color: Color {
                switch self {
                case .high: return .red
                case .medium: return .orange
                case .warning: return .yellow
                }
            }
        }
    }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(service)
        hasher.combine(category)
        hasher.combine(description)
        hasher.combine(dependencies)
        hasher.combine(isCritical)
        hasher.combine(status.isActive)
        hasher.combine(status.isEnabled)
        hasher.combine(status.statusText)
        hasher.combine(resources?.cpuPercent)
        hasher.combine(resources?.memoryPercent)
        hasher.combine(issues)
    }
    
    static func == (lhs: ServiceControl, rhs: ServiceControl) -> Bool {
        lhs.id == rhs.id &&
        lhs.service == rhs.service &&
        lhs.category == rhs.category &&
        lhs.description == rhs.description &&
        lhs.dependencies == rhs.dependencies &&
        lhs.isCritical == rhs.isCritical &&
        lhs.status.isActive == rhs.status.isActive &&
        lhs.status.isEnabled == rhs.status.isEnabled &&
        lhs.status.statusText == rhs.status.statusText &&
        lhs.resources?.cpuPercent == rhs.resources?.cpuPercent &&
        lhs.resources?.memoryPercent == rhs.resources?.memoryPercent &&
        lhs.issues == rhs.issues
    }
}

//
//  StatusNotificationInterval.swift
//  WarDragon
//
//  Created by Luke on 6/23/25.
//

import Foundation

enum StatusNotificationInterval: String, CaseIterable, Codable {
    case never = "never"
    case always = "always"
    case thresholdOnly = "threshold_only"
    case every5Minutes = "5_minutes"
    case every15Minutes = "15_minutes"
    case every30Minutes = "30_minutes"
    case hourly = "hourly"
    case every2Hours = "2_hours"
    case every6Hours = "6_hours"
    case daily = "daily"
    
    var displayName: String {
        switch self {
        case .never:
            return String(localized: "never", comment: "Never option")
        case .always:
            return "Always"
        case .thresholdOnly:
            return "Threshold Alerts Only"
        case .every5Minutes:
            return "Every 5 Minutes"
        case .every15Minutes:
            return "Every 15 Minutes"
        case .every30Minutes:
            return "Every 30 Minutes"
        case .hourly:
            return "Every Hour"
        case .every2Hours:
            return "Every 2 Hours"
        case .every6Hours:
            return "Every 6 Hours"
        case .daily:
            return "Daily"
        }
    }
    
    var description: String {
        switch self {
        case .never:
            return "No status notifications"
        case .always:
            return "Send every status update immediately"
        case .thresholdOnly:
            return "Only when thresholds are exceeded"
        case .every5Minutes:
            return "Regular status updates every 5 minutes"
        case .every15Minutes:
            return "Regular status updates every 15 minutes"
        case .every30Minutes:
            return "Regular status updates every 30 minutes"
        case .hourly:
            return "Regular status updates every hour"
        case .every2Hours:
            return "Regular status updates every 2 hours"
        case .every6Hours:
            return "Regular status updates every 6 hours"
        case .daily:
            return "Daily status summary"
        }
    }
    
    var icon: String {
        switch self {
        case .never:
            return "bell.slash.fill"
        case .always:
            return "bell.fill"
        case .thresholdOnly:
            return "exclamationmark.triangle.fill"
        case .every5Minutes, .every15Minutes, .every30Minutes:
            return "clock.fill"
        case .hourly, .every2Hours, .every6Hours:
            return "timer"
        case .daily:
            return "calendar"
        }
    }
    
    var intervalSeconds: TimeInterval? {
        switch self {
        case .never, .thresholdOnly:
            return nil
        case .always:
            return 0 // Always send immediately
        case .every5Minutes:
            return 300
        case .every15Minutes:
            return 900
        case .every30Minutes:
            return 1800
        case .hourly:
            return 3600
        case .every2Hours:
            return 7200
        case .every6Hours:
            return 21600
        case .daily:
            return 86400
        }
    }
}

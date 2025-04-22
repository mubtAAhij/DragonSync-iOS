//
//  BackgroundManager.swift
//  WarDragon
//
//  Created by Luke on 4/18/25.
//

import Foundation
import UIKit
import BackgroundTasks

class BackgroundManager {
    static let shared = BackgroundManager()
    
    // Maintain background task identifier
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    // Keep track of the timer for refreshing
    private var keepAliveTimer: Timer?
    
    // Track if background processing is active
    @Published var isBackgroundModeActive = false
    
    // Available background task identifiers
    private let refreshTaskIdentifier = "com.wardragon.refreshconnection"
    private let monitoringTaskIdentifier = "com.wardragon.dronemonitoring"
    
    // Track when the background task was last started to prevent excessive starts
    private var lastBackgroundTaskStartTime: Date?
    
    // Debug flag to log activity
    private let debugLogging = true
    
    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: refreshTaskIdentifier, using: nil) { task in
            self.handleRefreshTask(task as! BGAppRefreshTask)
        }
        
        BGTaskScheduler.shared.register(forTaskWithIdentifier: monitoringTaskIdentifier, using: nil) { task in
            self.handleMonitoringTask(task as! BGProcessingTask)
        }
        
        logDebug("Background tasks registered")
    }
    
    func startBackgroundProcessing() {
        // Don't start if already active - prevents multiple starts
        guard !isBackgroundModeActive else {
            logDebug("Background processing already active - ignoring duplicate start request")
            return
        }
        
        logDebug("Starting background processing")
        beginBackgroundTask()
        startKeepAliveTimer()
        scheduleBackgroundTasks()
        isBackgroundModeActive = true
    }
    
    func stopBackgroundProcessing() {
        guard isBackgroundModeActive else {
            logDebug("Background processing not active - ignoring stop request")
            return
        }
        
        logDebug("Stopping background processing")
        endBackgroundTask()
        isBackgroundModeActive = false
    }
    
    private func beginBackgroundTask() {
        // Don't end the previous task unless it's been running for a while
        // This prevents task churn during frequent state changes
        let now = Date()
        if let lastStart = lastBackgroundTaskStartTime,
           now.timeIntervalSince(lastStart) < 10.0,
           backgroundTask != .invalid {
            logDebug("Recent background task already exists - not restarting")
            return
        }
        
        // End previous task if it exists
        endBackgroundTask()
        
        logDebug("Beginning new background task")
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.logDebug("Background task expiration handler called")
            self?.endBackgroundTask()
            
            // Try to restart processing if we still want it active
            if self?.isBackgroundModeActive == true {
                self?.logDebug("Restarting background processing after expiration")
                self?.beginBackgroundTask()
                self?.startKeepAliveTimer()
            }
        }
        
        lastBackgroundTaskStartTime = now
        
        if backgroundTask == .invalid {
            logDebug("Failed to start background task")
        } else {
            logDebug("Background task started with identifier \(backgroundTask)")
        }
    }
    
    private func endBackgroundTask() {
        keepAliveTimer?.invalidate()
        keepAliveTimer = nil
        
        if backgroundTask != .invalid {
            logDebug("Ending background task \(backgroundTask)")
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    
    private func startKeepAliveTimer() {
        // Invalidate existing timer
        keepAliveTimer?.invalidate()
        
        // Create a new timer that fires every 20 seconds
        // iOS background tasks typically expire after 30 seconds
        keepAliveTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            self?.refreshBackgroundTask()
        }
        
        // Ensure the timer runs in background modes
        if let timer = keepAliveTimer {
            RunLoop.current.add(timer, forMode: .common)
            logDebug("Keep-alive timer started")
        }
    }
    
    private func refreshBackgroundTask() {
        if backgroundTask != .invalid && isBackgroundModeActive {
            logDebug("Refreshing background task")
            
            // Begin a new task before ending the old one to ensure continuity
            let oldTask = backgroundTask
            
            backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
                self?.logDebug("New background task expiration handler called")
                self?.endBackgroundTask()
                
                // Try to restart processing if we still want it active
                if self?.isBackgroundModeActive == true {
                    self?.beginBackgroundTask()
                    self?.startKeepAliveTimer()
                }
            }
            
            lastBackgroundTaskStartTime = Date()
            
            // Now end the old task
            UIApplication.shared.endBackgroundTask(oldTask)
            
            // Only post the refresh notification if we're actually active
            if isBackgroundModeActive {
                logDebug("Posting refresh connections notification")
                NotificationCenter.default.post(name: Notification.Name("RefreshNetworkConnections"), object: nil)
            }
        } else if isBackgroundModeActive {
            // Task became invalid but we want to be active - restart
            logDebug("Background task invalid but mode is active - restarting")
            beginBackgroundTask()
        }
    }
    
    private func scheduleBackgroundTasks() {
        scheduleAppRefresh()
        scheduleProcessingTask()
    }
    
    private func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            logDebug("Scheduled app refresh task")
        } catch {
            logDebug("Could not schedule app refresh: \(error)")
        }
    }
    
    private func scheduleProcessingTask() {
        let request = BGProcessingTaskRequest(identifier: monitoringTaskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 5 * 60)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            logDebug("Scheduled processing task")
        } catch {
            logDebug("Could not schedule processing task: \(error)")
        }
    }
    
    private func handleRefreshTask(_ task: BGAppRefreshTask) {
        logDebug("Refresh task started")
        scheduleAppRefresh()
        
        // Set up expiration handler that preserves our state
        task.expirationHandler = { [weak self] in
            self?.logDebug("Refresh task expired")
            
            // Try to restart background processing if needed
            if self?.isBackgroundModeActive == true {
                self?.logDebug("Restarting background processing after task expiration")
                self?.beginBackgroundTask()
                self?.startKeepAliveTimer()
            }
        }
        
        // Post a refresh notification without stopping existing connections
        if isBackgroundModeActive {
            logDebug("Posting refresh connections notification from refresh task")
            NotificationCenter.default.post(name: Notification.Name("RefreshNetworkConnections"), object: nil)
        }
        
        task.setTaskCompleted(success: true)
    }
    
    private func handleMonitoringTask(_ task: BGProcessingTask) {
        logDebug("Monitoring task started")
        scheduleProcessingTask()
        
        // Set up expiration handler that preserves our state
        task.expirationHandler = { [weak self] in
            self?.logDebug("Monitoring task expired")
            
            // Try to restart background processing if needed
            if self?.isBackgroundModeActive == true {
                self?.logDebug("Restarting background processing after task expiration")
                self?.beginBackgroundTask()
                self?.startKeepAliveTimer()
            }
        }
        
        // If we're not active but should be, start processing
        if Settings.shared.enableBackgroundDetection && !isBackgroundModeActive {
            logDebug("Starting background processing from monitoring task")
            startBackgroundProcessing()
        }
        
        task.setTaskCompleted(success: true)
    }
    
    private func logDebug(_ message: String) {
        if debugLogging {
            print("BackgroundManager: \(message)")
        }
    }
}

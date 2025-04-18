//
//  BackgroundManager.swift
//  WarDragon
//
//  Created by Luke on 4/16/25.
//

import Foundation
import UIKit

class BackgroundManager {
    static let shared = BackgroundManager()
    
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var timer: Timer?
    private var lastRefreshTime: Date?
    @Published var isBackgroundModeActive = false
    
    func startBackgroundProcessing() {
        // Begin background task
        beginBackgroundTask()
        
        // Start a timer to periodically refresh the background task
        startKeepAliveTimer()
        
        isBackgroundModeActive = true
    }
    
    func stopBackgroundProcessing() {
        // End background task
        endBackgroundTask()
        
        isBackgroundModeActive = false
    }
    
    private func beginBackgroundTask() {
        // End existing task if any
        endBackgroundTask()
        
        // Begin a new background task
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            // Expiration handler - iOS is about to terminate our background task
            self?.endBackgroundTask()
        }
    }
    
    private func endBackgroundTask() {
        // Cancel the timer
        timer?.invalidate()
        timer = nil
        
        // End the background task if active
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    
    private func startKeepAliveTimer() {
        // Create a timer that periodically refreshes the background task
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.refreshBackgroundTask()
        }
        RunLoop.current.add(timer!, forMode: .common)
    }
    
    private func refreshBackgroundTask() {
        // Only refresh if enough time has passed since the last refresh (avoid too frequent refreshes)
        if let lastTime = lastRefreshTime, Date().timeIntervalSince(lastTime) < 25 {
            return
        }
        
        // End the current task and begin a new one to extend the runtime
        if backgroundTask != .invalid {
            let oldTask = backgroundTask
            
            // Start a new task before ending the old one
            backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
                self?.endBackgroundTask()
            }
            
            // End the old task
            UIApplication.shared.endBackgroundTask(oldTask)
            
            // Notify that connections should be checked
            lastRefreshTime = Date()
            NotificationCenter.default.post(name: Notification.Name("RefreshNetworkConnections"), object: nil)
        }
    }
}

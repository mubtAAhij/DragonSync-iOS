//
//  BackgroundManager.swift
//  WarDragon
//
//  Created by Luke on 4/16/25.
//

import Foundation
import UIKit
import Network

class BackgroundManager {
    static let shared = BackgroundManager()
    
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var timer: Timer?
    @Published var isBackgroundModeActive = false
    private var networkMonitor: NWPathMonitor?
    private var hasActiveConnection = true
    private var isInBackground = false
    
    // Weak reference to the CoTViewModel to avoid reference cycles
    private weak var cotViewModel: CoTViewModel?
    
    // Setup method to be called during app initialization
    func configure(with viewModel: CoTViewModel) {
        self.cotViewModel = viewModel
        // Register for app state change notifications
        setupNotifications()
        startNetworkMonitoring()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }
    
    @objc private func applicationWillResignActive() {
        // App is about to go into the background
        if Settings.shared.isListening {
            startBackgroundProcessing()
        }
    }
    
    @objc private func applicationDidBecomeActive() {
        // App has returned to the foreground
        isInBackground = false
        
        // Check if we need to reconnect
        if Settings.shared.isListening {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.cotViewModel?.reconnectIfNeeded()
            }
        }
        
        // Stop background processing if it was active
        if isBackgroundModeActive {
            stopBackgroundProcessing()
        }
    }
    
    @objc private func applicationDidEnterBackground() {
        isInBackground = true
        
        // Start background processing if we should be listening
        if Settings.shared.isListening && !isBackgroundModeActive {
            startBackgroundProcessing()
        }
    }
    
    @objc private func applicationWillTerminate() {
        // Clean up resources when app is terminating
        stopBackgroundProcessing()
        networkMonitor?.cancel()
        networkMonitor = nil
    }
    
    // Network monitoring to detect changes while in background
    private func startNetworkMonitoring() {
        networkMonitor = NWPathMonitor()
        networkMonitor?.pathUpdateHandler = { [weak self] path in
            let newConnectionState = path.status == .satisfied
            let connectionChanged = newConnectionState != self?.hasActiveConnection
            
            self?.hasActiveConnection = newConnectionState
            
            // If we're in the background and network status changed, handle it
            if connectionChanged && self?.isInBackground == true {
                if newConnectionState {
                    // Network came back - try to reconnect
                    self?.handleNetworkReturn()
                } else {
                    // Network lost - notify the app
                    self?.handleNetworkLoss()
                }
            }
        }
        
        networkMonitor?.start(queue: DispatchQueue.global(qos: .background))
    }
    
    private func handleNetworkReturn() {
        // Network became available while in background
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.cotViewModel?.reconnectIfNeeded()
        }
    }
    
    private func handleNetworkLoss() {
        // Network was lost while in background
        // Could implement safe shutdown of connection resources here
    }
    
    func startBackgroundProcessing() {
        // Prevent duplicate starts
        guard !isBackgroundModeActive else { return }
        
        // Begin background task
        beginBackgroundTask()
        
        // Start a timer to periodically refresh the background task
        startKeepAliveTimer()
        
        isBackgroundModeActive = true
        isInBackground = true
        
        // Notify that we're entering background mode
        NotificationCenter.default.post(name: NSNotification.Name("EnteringBackgroundMode"), object: nil)
    }
    
    func stopBackgroundProcessing() {
        // End background task
        endBackgroundTask()
        
        isBackgroundModeActive = false
        
        // Notify that we're leaving background mode
        NotificationCenter.default.post(name: NSNotification.Name("LeavingBackgroundMode"), object: nil)
    }
    
    private func beginBackgroundTask() {
        // End existing task if any
        endBackgroundTask()
        
        // Begin a new background task with a safety buffer for cleanup
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            // Expiration handler - iOS is about to terminate our background task
            // Perform urgent cleanup with a higher QoS to ensure it completes
            DispatchQueue.global(qos: .userInitiated).async {
                // Notify that background task is about to expire
                NotificationCenter.default.post(name: NSNotification.Name("BackgroundTaskExpiring"), object: nil)
                
                // Give a moment for cleanup before ending
                Thread.sleep(forTimeInterval: 0.5)
                
                // End the task
                self?.endBackgroundTask()
            }
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
        // Use 25 seconds to stay well under the 30-second background task limit
        timer = Timer.scheduledTimer(withTimeInterval: 25, repeats: true) { [weak self] _ in
            self?.refreshBackgroundTask()
        }
        RunLoop.current.add(timer!, forMode: .common)
    }
    
    private func refreshBackgroundTask() {
        // End the current task and begin a new one to extend the runtime
        if backgroundTask != .invalid {
            let oldTask = backgroundTask
            
            // Start a new task before ending the old one to ensure continuity
            backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
                // Safety handler if the new task is about to expire
                DispatchQueue.global(qos: .userInitiated).async {
                    NotificationCenter.default.post(name: NSNotification.Name("BackgroundTaskExpiring"), object: nil)
                    Thread.sleep(forTimeInterval: 0.5)
                    self?.endBackgroundTask()
                }
            }
            
            // End the old task only after creating a new one
            UIApplication.shared.endBackgroundTask(oldTask)
            
            // Do a lightweight connection check
            performLightweightConnectionCheck()
        }
    }
    
    private func performLightweightConnectionCheck() {
        // Notify that connections should be checked in a lightweight manner
        // Use a distinct notification name to differentiate from heavier processing
        NotificationCenter.default.post(name: NSNotification.Name("LightweightConnectionCheck"), object: nil)
        
        // If we have direct access to the view model, we could check more directly
        if let cotViewModel = self.cotViewModel, Settings.shared.isListening {
            // Only check if network is available and we should be listening
            if hasActiveConnection {
                // Add ZMQHandler checkAlive" method TODO
                cotViewModel.checkConnectionStatus()
            }
        }
    }
    
    func isNetworkAvailable() -> Bool {
        return hasActiveConnection
    }
}

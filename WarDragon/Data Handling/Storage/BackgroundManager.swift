import Foundation
import UIKit
import BackgroundTasks

class BackgroundManager {
    static let shared = BackgroundManager()
    
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var timer: Timer?
    @Published var isBackgroundModeActive = false
    
    private let refreshTaskIdentifier = "com.wardragon.refreshconnection"
    private let monitoringTaskIdentifier = "com.wardragon.dronemonitoring"
    
    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: refreshTaskIdentifier, using: nil) { task in
            self.handleRefreshTask(task as! BGAppRefreshTask)
        }
        
        BGTaskScheduler.shared.register(forTaskWithIdentifier: monitoringTaskIdentifier, using: nil) { task in
            self.handleMonitoringTask(task as! BGProcessingTask)
        }
    }
    
    func startBackgroundProcessing() {
        beginBackgroundTask()
        startKeepAliveTimer()
        scheduleBackgroundTasks()
        isBackgroundModeActive = true
    }
    
    func stopBackgroundProcessing() {
        endBackgroundTask()
        isBackgroundModeActive = false
    }
    
    private func beginBackgroundTask() {
        endBackgroundTask()
        
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
    }
    
    private func endBackgroundTask() {
        timer?.invalidate()
        timer = nil
        
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    
    private func startKeepAliveTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.refreshBackgroundTask()
        }
        RunLoop.current.add(timer!, forMode: .common)
    }
    
    private func refreshBackgroundTask() {
        if backgroundTask != .invalid {
            let oldTask = backgroundTask
            
            backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
                self?.endBackgroundTask()
            }
            
            UIApplication.shared.endBackgroundTask(oldTask)
            
            NotificationCenter.default.post(name: Notification.Name("RefreshNetworkConnections"), object: nil)
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
        } catch {
            print("Could not schedule app refresh: \(error)")
        }
    }
    
    private func scheduleProcessingTask() {
        let request = BGProcessingTaskRequest(identifier: monitoringTaskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 5 * 60)
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule processing task: \(error)")
        }
    }
    
    private func handleRefreshTask(_ task: BGAppRefreshTask) {
        scheduleAppRefresh()
        
        NotificationCenter.default.post(name: Notification.Name("RefreshNetworkConnections"), object: nil)
        
        task.expirationHandler = {
        }
        
        task.setTaskCompleted(success: true)
    }
    
    private func handleMonitoringTask(_ task: BGProcessingTask) {
        scheduleProcessingTask()
        
        task.expirationHandler = {
        }
        
        task.setTaskCompleted(success: true)
    }
}

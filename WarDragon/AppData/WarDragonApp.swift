//
//  WarDragonApp.swift
//  WarDragon
//
//  Created by Luke on 11/18/24.
//

import SwiftUI

extension Font {
    static let appDefault = Font.system(.body, design: .monospaced)
    static let appHeadline = Font.system(.headline, design: .monospaced)
    static let appSubheadline = Font.system(.subheadline, design: .monospaced)
    static let appCaption = Font.system(.caption, design: .monospaced)
}


@main
struct WarDragonApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Register notifications
        UNUserNotificationCenter.current().delegate = self
        
        // Register background tasks
        BackgroundManager.shared.registerBackgroundTasks()
        
        // Register for app lifecycle notifications
        setupAppLifecycleObservers()
        
        return true
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.windows.first?.frame = windowScene.windows.first?.frame ?? .zero
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
    
    private func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appMovingToBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appMovingToForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    @objc private func appMovingToBackground() {
        // Start background processing if listening is active
        if Settings.shared.isListening && Settings.shared.enableBackgroundDetection {
            BackgroundManager.shared.startBackgroundProcessing()
        }
    }
    
    @objc private func appMovingToForeground() {
        // Nothing to do, let normal operation resume
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

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
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

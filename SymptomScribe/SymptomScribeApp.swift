//
//  SymptomScribeApp.swift
//  SymptomScribe
//
//  Created by Samay Prabhu
//

import SwiftUI
import UserNotifications

@main
struct SymptomScribeApp: App {
    let persistenceController = PersistenceController.shared
    
    init() {
        // Request notification permission on app launch
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("⚠️ Notification permission error on launch: \(error.localizedDescription)")
            } else {
                print("✅ Notification permission \(granted ? "granted" : "denied") on launch")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}

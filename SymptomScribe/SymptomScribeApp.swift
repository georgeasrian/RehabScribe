//
//  SymptomScribeApp.swift
//  SymptomScribe
//
//  Created by Samay Prabhu
//

import SwiftUI

@main
struct SymptomScribeApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}

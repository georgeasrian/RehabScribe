//
//  Persistence.swift
//  SymptomScribe
//
//  Created by Aashni Shah on 9/29/24.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    // Preview instance for SwiftUI previews
    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext

        // Create sample data
        for i in 0..<5 {
            let newNote = Note(context: viewContext)
            newNote.transcribedText = "Sample transcribed text \(i)"
            newNote.summary = "Sample summary \(i)"
            newNote.date = Date()
        }

        do {
            try viewContext.save()
        } catch {
            // Replace this with proper error handling
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }

        return result
    }()

    let container: NSPersistentContainer

    // Initialize the persistent container
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "SymptomScribe") // Ensure this matches your .xcdatamodeld file name
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                // Replace this with proper error handling
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}

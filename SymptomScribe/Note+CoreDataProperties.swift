//
//  Note+CoreDataProperties.swift
//  SymptomScribe
//
import Foundation
import CoreData

extension Note {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Note> {
        return NSFetchRequest<Note>(entityName: "Note")
    }

    @NSManaged public var date: Date?
    @NSManaged public var transcribedText: String?
    @NSManaged public var summary: String?
    @NSManaged public var symptoms: NSSet?

}

// MARK: Generated accessors for symptoms
extension Note {

    @objc(addSymptomsObject:)
    @NSManaged public func addToSymptoms(_ value: Symptom)

    @objc(removeSymptomsObject:)
    @NSManaged public func removeFromSymptoms(_ value: Symptom)

    @objc(addSymptoms:)
    @NSManaged public func addToSymptoms(_ values: NSSet)

    @objc(removeSymptoms:)
    @NSManaged public func removeFromSymptoms(_ values: NSSet)

}

extension Note : Identifiable {

}

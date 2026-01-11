//
//  Symptom+CoreDataProperties.swift
//  SymptomScribe
//
import Foundation
import CoreData

extension Symptom {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Symptom> {
        return NSFetchRequest<Symptom>(entityName: "Symptom")
    }

    @NSManaged public var date: Date?
    @NSManaged public var symptomName: String?
    @NSManaged public var isPresent: Bool
    @NSManaged public var note: Note?

}

extension Symptom : Identifiable {

}

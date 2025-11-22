//
//  NoteDetailView.swift
//  SymptomScribe
//
//  Created by Aashni Shah on 9/29/24.
//
//

import SwiftUI
import CoreData

struct NoteDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var note: Note

    @State private var editingResistanceTrainingID: NSManagedObjectID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Editable Transcribed Text
                Text("Transcribed Text:")
                    .font(.headline)
                TextEditor(text: Binding(
                    get: { note.transcribedText ?? "" },
                    set: { note.transcribedText = $0 }
                ))
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(8)
                .frame(minHeight: 100)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                )
                .onChange(of: note.transcribedText) { _ in
                    saveContext()
                }

                // Resistance Training List with Header Background
                Text("Resistance Training")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                ResistanceTrainingListView(note: note, editingResistanceTrainingID: $editingResistanceTrainingID)
            }
            .padding()
        }
        .navigationTitle("Note Details")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    saveContext()
                }) {
                    Text("Save")
                }
            }
        }
    }

    private func saveContext() {
        if viewContext.hasChanges {
            do {
                try viewContext.save()
                print("Context saved")
            } catch {
                print("Failed to save context: \(error.localizedDescription)")
            }
        }
    }
}

//RESISTANCE TRAINING LIST VIEW - NEW
import SwiftUI
import CoreData

struct ResistanceTrainingListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    var note: Note
    @Binding var editingResistanceTrainingID: NSManagedObjectID?

    @FetchRequest var resistanceTrainings: FetchedResults<ResistanceTraining>

    init(note: Note, editingResistanceTrainingID: Binding<NSManagedObjectID?>) {
        self.note = note
        self._editingResistanceTrainingID = editingResistanceTrainingID

        let request: NSFetchRequest<ResistanceTraining> = ResistanceTraining.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ResistanceTraining.setNumberInSequence, ascending: true)]
        request.predicate = NSPredicate(format: "note == %@", note)
        _resistanceTrainings = FetchRequest(fetchRequest: request)
    }

    var body: some View {
        VStack(alignment: .leading) {
            ForEach(resistanceTrainings, id: \.self) { rt in
                ResistanceTrainingRowView(resistanceTraining: rt)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.blue.opacity(0.5), lineWidth: 1)
                    )
                    .padding(.vertical, 5)
            }
            Button(action: addResistanceTraining) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Exercise")
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue.opacity(0.2))
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.top)
        }
    }

    private func addResistanceTraining() {
        let newRT = ResistanceTraining(context: viewContext)
        newRT.note = note
        newRT.setNumberInSequence = Int64((resistanceTrainings.last?.setNumberInSequence ?? 0) + 1)
        newRT.numberOfRepsInSet = 0
        newRT.totalWeightLifted = 0.0
        newRT.untilFailureYN = false
        newRT.painOrDiscomfortYN = false
        saveContext()
    }

    private func saveContext() {
        if viewContext.hasChanges {
            do {
                try viewContext.save()
                print("Context saved")
            } catch {
                print("Failed to save context: \(error.localizedDescription)")
            }
        }
    }
}

//Resistance Training Row View
import SwiftUI
import CoreData

struct ResistanceTrainingRowView: View {
    @ObservedObject var resistanceTraining: ResistanceTraining
    @Environment(\.managedObjectContext) private var viewContext

    @State private var restMinutes: Int = 0
    @State private var restSeconds: Int = 0

    private let integerFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        return formatter
    }()

    private let decimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                TextField("Exercise Name", text: Binding(
                    get: { resistanceTraining.exerciseName ?? "" },
                    set: { resistanceTraining.exerciseName = $0 }
                ))
                .font(.headline)
                .onChange(of: resistanceTraining.exerciseName) { _ in
                    saveContext()
                }
                Spacer()
                Button(action: deleteResistanceTraining) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }

            HStack {
                Text("Set Number")
                Spacer()
                TextField("", value: Binding(
                    get: { Int(resistanceTraining.setNumberInSequence) },
                    set: { resistanceTraining.setNumberInSequence = Int64($0) }
                ), formatter: integerFormatter)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 60)
                .onChange(of: resistanceTraining.setNumberInSequence) { _ in
                    saveContext()
                }
            }

            HStack {
                Text("Number of Reps")
                Spacer()
                TextField("", value: Binding(
                    get: { Int(resistanceTraining.numberOfRepsInSet) },
                    set: { resistanceTraining.numberOfRepsInSet = Int64($0) }
                ), formatter: integerFormatter)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 60)
                .onChange(of: resistanceTraining.numberOfRepsInSet) { _ in
                    saveContext()
                }
            }

            HStack {
                Text("Total Weight Lifted")
                Spacer()
                TextField("", value: Binding(
                    get: { resistanceTraining.totalWeightLifted },
                    set: { resistanceTraining.totalWeightLifted = $0 }
                ), formatter: decimalFormatter)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
                .onChange(of: resistanceTraining.totalWeightLifted) { _ in
                    saveContext()
                }
                Text("lbs")
            }

            HStack {
                Text("Resistance Type")
                Spacer()
                TextField("", text: Binding(
                    get: { resistanceTraining.resistanceType ?? "" },
                    set: { resistanceTraining.resistanceType = $0 }
                ))
                .multilineTextAlignment(.trailing)
                .frame(width: 120)
                .onChange(of: resistanceTraining.resistanceType) { _ in
                    saveContext()
                }
            }

            HStack {
                Text("Rest Time Before Set")
                Spacer()
                HStack(spacing: 4) {
                    TextField("", value: $restMinutes, formatter: integerFormatter)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 40)
                    Text("min")
                    TextField("", value: $restSeconds, formatter: integerFormatter)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 40)
                    Text("sec")
                }
            }
            .onAppear(perform: loadRestTime)
            .onChange(of: restMinutes) { _ in
                saveRestTime()
            }
            .onChange(of: restSeconds) { _ in
                saveRestTime()
            }

            HStack {
                Toggle("Until Failure", isOn: Binding(
                    get: { resistanceTraining.untilFailureYN },
                    set: { resistanceTraining.untilFailureYN = $0; saveContext() }
                ))
                Spacer()
                Toggle("Pain or Discomfort", isOn: Binding(
                    get: { resistanceTraining.painOrDiscomfortYN },
                    set: { resistanceTraining.painOrDiscomfortYN = $0; saveContext() }
                ))
            }

            HStack {
                Text("Muscle Group")
                Spacer()
                TextField("", text: Binding(
                    get: { resistanceTraining.muscleGroup ?? "" },
                    set: { resistanceTraining.muscleGroup = $0 }
                ))
                .multilineTextAlignment(.trailing)
                .frame(width: 120)
                .onChange(of: resistanceTraining.muscleGroup) { _ in
                    saveContext()
                }
            }
        }
    }

    private func loadRestTime() {
        let totalSeconds = resistanceTraining.restTimeInSecondsBeforeCurrentSetOptional?.doubleValue ?? 0
        restMinutes = Int(totalSeconds) / 60
        restSeconds = Int(totalSeconds) % 60
    }

    private func saveRestTime() {
        let totalSeconds = Double(restMinutes * 60 + restSeconds)
        resistanceTraining.restTimeInSecondsBeforeCurrentSetOptional = NSNumber(value: totalSeconds)
        saveContext()
    }

    private func deleteResistanceTraining() {
        viewContext.delete(resistanceTraining)
        saveContext()
    }

    private func saveContext() {
        if viewContext.hasChanges {
            do {
                try viewContext.save()
                print("Context saved")
            } catch {
                print("Failed to save context: \(error.localizedDescription)")
            }
        }
    }
}

//import SwiftUI
//import CoreData
//
//struct NoteDetailView: View {
//    @Environment(\.managedObjectContext) private var viewContext
//    @ObservedObject var note: Note
//
////    @State private var editingSymptomID: NSManagedObjectID?
////    @State private var editingContextID: NSManagedObjectID?
////    @State private var editingMedicationID: NSManagedObjectID?
//    @State private var editingResistanceTrainingID: NSManagedObjectID?
//
//    var body: some View {
//        ScrollView {
//            VStack(alignment: .leading, spacing: 20) {
//                // Display Transcribed Text
//                Text("Transcribed Text:")
//                    .font(.headline)
//                Text(note.transcribedText ?? "No Transcription Available")
//                    .padding()
//                    .background(Color(UIColor.secondarySystemBackground))
//                    .cornerRadius(8)
//
////                // Symptoms List with Header Background
////                Text("Symptoms")
////                    .font(.headline)
////                    .padding()
////                    .frame(maxWidth: .infinity, alignment: .leading)
////                    .background(Color.gray.opacity(0.2)) // Light gray background
////                    .cornerRadius(8)
////                SymptomsListView(note: note, editingSymptomID: $editingSymptomID)
////
////                // Contexts List with Header Background
////                Text("Contexts")
////                    .font(.headline)
////                    .padding()
////                    .frame(maxWidth: .infinity, alignment: .leading)
////                    .background(Color.gray.opacity(0.2)) // Light gray background
////                    .cornerRadius(8)
////                ContextsListView(note: note, editingContextID: $editingContextID)
////
////                // Medications List with Header Background
////                Text("Medications")
////                    .font(.headline)
////                    .padding()
////                    .frame(maxWidth: .infinity, alignment: .leading)
////                    .background(Color.gray.opacity(0.2)) // Light gray background
////                    .cornerRadius(8)
////                MedicationsListView(note: note, editingMedicationID: $editingMedicationID)
////
//                // Resistance Training List with Header Background
//                Text("Resistance Training")
//                    .font(.headline)
//                    .padding()
//                    .frame(maxWidth: .infinity, alignment: .leading)
//                    .background(Color.gray.opacity(0.2)) // Light gray background
//                    .cornerRadius(8)
//                ResistanceTrainingListView(note: note, editingResistanceTrainingID: $editingResistanceTrainingID)
//            }
//            .padding()
//        }
//        .navigationTitle("Note Details")
//    }
//}
//
////SYMPTOMS LIST VIEW
//import SwiftUI
//import CoreData
//
//struct SymptomsListView: View {
//    @Environment(\.managedObjectContext) private var viewContext
//    var note: Note
//    @Binding var editingSymptomID: NSManagedObjectID?
//
//    @State private var symptoms: [Symptom] = []
//
//    var body: some View {
//        VStack(alignment: .leading) {
//            ForEach(symptoms, id: \.self) { symptom in
//                VStack(alignment: .leading, spacing: 8) {
//                    Text("Symptom: \(symptom.symptom ?? "Unspecified")")
//                        .font(.headline)
//
//                    VStack(alignment: .leading, spacing: 5) {
//                        Text("Anatomy: \(symptom.anatomy ?? "Unspecified")")
//                        Text("Time Expression: \(symptom.timeExpression ?? "Unspecified")")
//                        Text("Quantitative Measure: \(symptom.quantitativeMeasure ?? "Unspecified")")
//                        Text("Qualitative Measure: \(symptom.qualitativeMeasure ?? "Unspecified")")
//                    }
//                    .padding(.leading)
//
//                    Divider()
//                }
//                .padding(.bottom)
//            }
//        }
//        .onAppear(perform: fetchSymptoms)
//        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)) { _ in
//            fetchSymptoms()
//        }
//    }
//
//    private func fetchSymptoms() {
//        let request: NSFetchRequest<Symptom> = Symptom.fetchRequest()
//        request.sortDescriptors = [NSSortDescriptor(keyPath: \Symptom.timestamp, ascending: true)]
//        request.predicate = NSPredicate(format: "note == %@", note)
//
//        do {
//            symptoms = try viewContext.fetch(request)
//        } catch {
//            print("Failed to fetch symptoms: \(error.localizedDescription)")
//        }
//    }
//}
//
//
////CONTEXTS LIST VIEW
//import SwiftUI
//import CoreData
//
//struct ContextsListView: View {
//    @Environment(\.managedObjectContext) private var viewContext
//    var note: Note
//    @Binding var editingContextID: NSManagedObjectID?
//
//    @State private var contexts: [Context] = []
//
//    var body: some View {
//        VStack(alignment: .leading) {
//            ForEach(contexts, id: \.self) { context in
//                VStack(alignment: .leading, spacing: 8) {
//                    Text("Context Category: \(context.contextCategory ?? "Unspecified")")
//                        .font(.headline)
//
//                    VStack(alignment: .leading, spacing: 5) {
//                        Text("Specific Context Detail: \(context.specificContextDetail ?? "Unspecified")")
//                    }
//                    .padding(.leading)
//
//                    Divider()
//                }
//                .padding(.bottom)
//            }
//        }
//        .onAppear(perform: fetchContexts)
//        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)) { _ in
//            fetchContexts()
//        }
//    }
//
//    private func fetchContexts() {
//        let request: NSFetchRequest<Context> = Context.fetchRequest()
//        request.sortDescriptors = []
//        request.predicate = NSPredicate(format: "note == %@", note)
//
//        do {
//            contexts = try viewContext.fetch(request)
//        } catch {
//            print("Failed to fetch contexts: \(error.localizedDescription)")
//        }
//    }
//}
//
////MEDICATIONS LIST VIEW
//import SwiftUI
//import CoreData
//
//struct MedicationsListView: View {
//    @Environment(\.managedObjectContext) private var viewContext
//    var note: Note
//    @Binding var editingMedicationID: NSManagedObjectID?
//
//    @State private var medications: [Medication] = []
//
//    var body: some View {
//        VStack(alignment: .leading) {
//            ForEach(medications, id: \.self) { medication in
//                VStack(alignment: .leading, spacing: 8) {
//                    Text("Medication Name: \(medication.medicationName ?? "Unspecified")")
//                        .font(.headline)
//
//                    VStack(alignment: .leading, spacing: 5) {
//                        Text("Brand or Generic: \(medication.brandNameOrGeneric ?? "Unspecified")")
//                        Text("Dosage: \(medication.dosage ?? "Unspecified")")
//                        Text("Frequency of Use: \(medication.frequencyPerDay ?? "Unspecified")")
//                        Text("Side Effects: \(medication.sideEffects ?? "Unspecified")")
//                        Text("Impact (+/-): \(medication.positiveOrNegativeImpact ?? "Unspecified")")
//                    }
//                    .padding(.leading)
//
//                    Divider()
//                }
//                .padding(.bottom)
//            }
//        }
//        .onAppear(perform: fetchMedications)
//        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)) { _ in
//            fetchMedications()
//        }
//    }
//
//    private func fetchMedications() {
//        let request: NSFetchRequest<Medication> = Medication.fetchRequest()
//        request.sortDescriptors = []
//        request.predicate = NSPredicate(format: "note == %@", note)
//
//        do {
//            medications = try viewContext.fetch(request)
//        } catch {
//            print("Failed to fetch medications: \(error.localizedDescription)")
//        }
//    }
//}


////RESISTANCE TRAINING LIST VIEW - OLD
//import SwiftUI
//import CoreData
//
//struct ResistanceTrainingListView: View {
//    @Environment(\.managedObjectContext) private var viewContext
//    var note: Note
//    @Binding var editingResistanceTrainingID: NSManagedObjectID?
//
//    @State private var resistanceTrainings: [ResistanceTraining] = []
//
//    var body: some View {
//        VStack(alignment: .leading) {
//            ForEach(resistanceTrainings, id: \.self) { rt in
//                VStack(alignment: .leading, spacing: 8) {
//                    Text("Exercise Name: \(rt.exerciseName ?? "Unspecified")")
//                        .font(.headline)
//
//                    VStack(alignment: .leading, spacing: 5) {
//                        Text("Set Number: \(rt.setNumberInSequence)")
//                        Text("Number of Reps: \(rt.numberOfRepsInSet)")
//                        Text("Total Weight Lifted: \(rt.totalWeightLifted, specifier: "%.2f") lbs")
//                        Text("Resistance Type: \(rt.resistanceType ?? "Unspecified")")
//                        if let restTime = rt.restTimeInSecondsBeforeCurrentSetOptional {
//                            Text("Rest Time Before Set: \(restTime.doubleValue, specifier: "%.2f") seconds")
//                        } else {
//                            Text("Rest Time Before Set: Unspecified")
//                        }
//                        Text("Until Failure: \(rt.untilFailureYN ? "Yes" : "No")")
//                        Text("Pain or Discomfort: \(rt.painOrDiscomfortYN ? "Yes" : "No")")
//                        Text("Muscle Group: \(rt.muscleGroup ?? "Unspecified")")
//                    }
//                    .padding(.leading)
//
//                    Divider()
//                }
//                .padding(.bottom)
//            }
//        }
//        .onAppear(perform: fetchResistanceTraining)
//        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)) { _ in
//            fetchResistanceTraining()
//        }
//    }
//
//    private func fetchResistanceTraining() {
//        let request: NSFetchRequest<ResistanceTraining> = ResistanceTraining.fetchRequest()
//        request.sortDescriptors = [NSSortDescriptor(keyPath: \ResistanceTraining.setNumberInSequence, ascending: true)]
//        request.predicate = NSPredicate(format: "note == %@", note)
//
//        do {
//            resistanceTrainings = try viewContext.fetch(request)
//        } catch {
//            print("Failed to fetch resistance training data: \(error.localizedDescription)")
//        }
//    }
//}

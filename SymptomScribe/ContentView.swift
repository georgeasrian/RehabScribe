//
//  ContentView.swift
//  SymptomScribe
//
//  Updated for proper grouping and friendly names
//

import SwiftUI
import CoreData
import UIKit

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        entity: ResistanceTraining.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \ResistanceTraining.resistanceType, ascending: false), // Symptoms first
            NSSortDescriptor(keyPath: \ResistanceTraining.setNumberInSequence, ascending: true)
        ],
        animation: .default)
    private var resistanceTrainings: FetchedResults<ResistanceTraining>
    
    @State private var isGeneratingCSV = false
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 0) {
                
                // Share button
                VStack {
                    Button(action: shareCSV) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export CSV")
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(isGeneratingCSV)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 16)
                
                if isGeneratingCSV {
                    Text("Just a moment, we are generating your file.")
                        .foregroundColor(.gray)
                        .padding(.bottom, 16)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                
                // Group ResistanceTrainings by resistanceType
                let groupedTrainings = Dictionary(grouping: resistanceTrainings, by: { $0.resistanceType ?? "Unknown" })
                ScrollView(.horizontal) {
                    VStack(alignment: .leading, spacing: 0) {
                        // Header row
                        HStack {
                            Text("Date").bold().frame(width: 150)
                            Text("Exercise Name").bold().frame(width: 140)
                            Text("Muscle Group").bold().frame(width: 120)
                            Text("Total Weight Lifted").bold().frame(width: 140)
                            Text("Number of Reps").bold().frame(width: 120)
                            Text("Set Number").bold().frame(width: 120)
                            Text("Rest Time").bold().frame(width: 120)
                            Text("Resistance Type").bold().frame(width: 140)
                            Text("Pain/Discomfort").bold().frame(width: 140)
                            Text("Until Failure").bold().frame(width: 120)
                        }
                        .padding(.horizontal)
                        .padding(.top, 0)
                        .background(Color(.systemGray6))
                        .border(Color.black, width: 1)
                        
                        ScrollView(.vertical) {
                            VStack(spacing: 0) {
                                // Loop over grouped sections
                                ForEach(groupedTrainings.keys.sorted(), id: \.self) { type in
                                    Text(type)
                                        .font(.headline)
                                        .padding(.vertical, 4)
                                        .padding(.horizontal)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color(.systemGray5))
                                    
                                    ForEach(groupedTrainings[type]!, id: \.objectID) { training in
                                        HStack {
                                            Text(training.date ?? Date(), formatter: itemFormatter).frame(width: 150)
                                            Text(training.exerciseName ?? "N/A").frame(width: 140)
                                            Text(training.muscleGroup ?? "N/A").frame(width: 120)
                                            Text(String(format: "%.2f lbs", training.totalWeightLifted)).frame(width: 140)
                                            Text("\(training.numberOfRepsInSet)").frame(width: 120)
                                            Text("\(training.setNumberInSequence)").frame(width: 120)
                                            Text(String(format: "%.0f sec", training.restTimeInSecondsBeforeCurrentSetOptional?.doubleValue ?? 0.0)).frame(width: 120)
                                            Text(training.resistanceType ?? "N/A").frame(width: 140)
                                            Text(training.painOrDiscomfortYN ? "Yes" : "No").frame(width: 140)
                                            Text(training.untilFailureYN ? "Yes" : "No").frame(width: 120)
                                        }
                                        .padding(.horizontal)
                                        .background(Color(UIColor.secondarySystemBackground))
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .navigationTitle("Workout Notes Table")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var itemFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
    
    // MARK: - CSV Export
    
    func shareCSV() {
        isGeneratingCSV = true
        DispatchQueue.global(qos: .userInitiated).async {
            let csvString = generateCSVString()
            let tempDirectory = FileManager.default.temporaryDirectory
            let fileName = "ResistanceTrainings.csv"
            let csvURL = tempDirectory.appendingPathComponent(fileName)
            do {
                try csvString.write(to: csvURL, atomically: true, encoding: .utf8)
                DispatchQueue.main.async {
                    isGeneratingCSV = false
                    presentShareSheet(with: [csvURL])
                }
            } catch {
                print("Error writing CSV file: \(error)")
                DispatchQueue.main.async {
                    isGeneratingCSV = false
                }
            }
        }
    }
    
    func presentShareSheet(with items: [Any]) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }
        let activityViewController = UIActivityViewController(activityItems: items, applicationActivities: nil)
        rootViewController.present(activityViewController, animated: true)
    }
    
    func generateCSVString() -> String {
        var csvText = "Date,Exercise Name,Muscle Group,Total Weight Lifted,Number of Reps,Set Number,Rest Time,Resistance Type,Pain/Discomfort,Until Failure\n"
        
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        
        for training in resistanceTrainings {
            let dateString = formatter.string(from: training.date ?? Date())
            let exerciseName = training.exerciseName?.replacingOccurrences(of: "\"", with: "\"\"") ?? ""
            let muscleGroup = training.muscleGroup?.replacingOccurrences(of: "\"", with: "\"\"") ?? ""
            let totalWeightLifted = String(format: "%.2f", training.totalWeightLifted)
            let numberOfReps = "\(training.numberOfRepsInSet)"
            let setNumber = "\(training.setNumberInSequence)"
            let restTime = String(format: "%.0f", training.restTimeInSecondsBeforeCurrentSetOptional?.doubleValue ?? 0.0)
            let resistanceType = training.resistanceType?.replacingOccurrences(of: "\"", with: "\"\"") ?? ""
            let painOrDiscomfort = training.painOrDiscomfortYN ? "Yes" : "No"
            let untilFailure = training.untilFailureYN ? "Yes" : "No"
            
            let line = "\"\(dateString)\",\"\(exerciseName)\",\"\(muscleGroup)\",\"\(totalWeightLifted)\",\"\(numberOfReps)\",\"\(setNumber)\",\"\(restTime)\",\"\(resistanceType)\",\"\(painOrDiscomfort)\",\"\(untilFailure)\"\n"
            csvText += line
        }
        return csvText
    }
}

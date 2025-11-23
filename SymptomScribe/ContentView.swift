import SwiftUI
import CoreData
import UIKit // Import UIKit to use UIActivityViewController

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        entity: ResistanceTraining.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \ResistanceTraining.date, ascending: false)],
        animation: .default)
    private var resistanceTrainings: FetchedResults<ResistanceTraining>
    
    // State variables
    @State private var isGeneratingCSV = false
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 0) {
                // Share button placed above the data table
                VStack {
                    Button(action: {
                        shareCSV()
                    }) {
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
                    .disabled(isGeneratingCSV) // Disable button while generating
                }
                .frame(maxWidth: .infinity) // Make the VStack take up the entire width of the screen
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 16) // Add spacing between button and table
                
                // Loading message
                if isGeneratingCSV {
                    VStack {
                        Text("Just a moment, we are generating your file.")
                            .foregroundColor(.gray)
                            .padding(.bottom, 16) // Space between message and table
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
                
                // Data table starts here
                ScrollView(.horizontal) {
                    VStack(alignment: .leading, spacing: 0) {
                        // Header Row
                        HStack {
                            Text("Date").bold().frame(width: 150)
                            Text("Exercise Name").bold().frame(width: 120)
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
                        
                        // Data Rows with Vertical Scrolling
                        ScrollView(.vertical) {
                            VStack(spacing: 0) {
                                ForEach(resistanceTrainings, id: \ResistanceTraining.objectID) { training in
                                    HStack {
                                        Text(training.date ?? Date(), formatter: itemFormatter).frame(width: 150)
                                        Text(training.exerciseName ?? "N/A").frame(width: 120)
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
    
    // Function to generate CSV and present share sheet
    func shareCSV() {
        isGeneratingCSV = true // Show the loading message
        DispatchQueue.global(qos: .userInitiated).async {
            let csvString = self.generateCSVString()
            let tempDirectory = FileManager.default.temporaryDirectory
            let fileName = "ResistanceTrainings.csv"
            let csvURL = tempDirectory.appendingPathComponent(fileName)
            do {
                try csvString.write(to: csvURL, atomically: true, encoding: .utf8)
                DispatchQueue.main.async {
                    isGeneratingCSV = false // Hide the loading message
                    // Present the share sheet
                    presentShareSheet(with: [csvURL])
                }
            } catch {
                print("Error writing CSV file: \(error)")
                DispatchQueue.main.async {
                    isGeneratingCSV = false // Hide the loading message
                }
            }
        }
    }
    
    // Function to present the share sheet
    func presentShareSheet(with items: [Any]) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }
        
        let activityViewController = UIActivityViewController(activityItems: items, applicationActivities: nil)
        rootViewController.present(activityViewController, animated: true, completion: nil)
    }
    
    // Function to generate CSV string from Core Data
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
            
            // Wrap each field in double quotes to handle commas and quotes in data
            let line = "\"\(dateString)\",\"\(exerciseName)\",\"\(muscleGroup)\",\"\(totalWeightLifted)\",\"\(numberOfReps)\",\"\(setNumber)\",\"\(restTime)\",\"\(resistanceType)\",\"\(painOrDiscomfort)\",\"\(untilFailure)\"\n"
            csvText += line
        }
        return csvText
    }
}


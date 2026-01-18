import SwiftUI
import CoreData
import UIKit

struct ExerciseLogView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ExerciseSet.date, ascending: false)],
        animation: .default)
    private var exerciseSets: FetchedResults<ExerciseSet>
    
    @State private var isGeneratingCSV = false
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 0) {
                
                // Export Button
                VStack(spacing: 12) {
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
                    
                    if isGeneratingCSV {
                        Text("Generating your export file...")
                            .foregroundColor(.gray)
                            .padding(.bottom, 16)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 16)
                
                // Exercise Sets Table
                ScrollView(.horizontal) {
                    VStack(alignment: .leading, spacing: 0) {
                        // Header Row
                        HStack(spacing: 0) {
                            Text("Date & Time")
                                .bold()
                                .frame(width: 180, alignment: .leading)
                                .padding(.horizontal, 8)
                            
                            Text("Exercise Name")
                                .bold()
                                .frame(width: 220, alignment: .leading)
                                .padding(.horizontal, 8)
                            
                            Text("Set #")
                                .bold()
                                .frame(width: 80, alignment: .center)
                                .padding(.horizontal, 8)
                            
                            Text("Reps")
                                .bold()
                                .frame(width: 80, alignment: .center)
                                .padding(.horizontal, 8)
                            
                            Text("Pain")
                                .bold()
                                .frame(width: 80, alignment: .center)
                                .padding(.horizontal, 8)
                        }
                        .padding(.vertical, 12)
                        .background(Color(.systemGray6))
                        .border(Color.black, width: 1)
                        
                        // Data Rows
                        ScrollView(.vertical) {
                            VStack(spacing: 0) {
                                if exerciseSets.isEmpty {
                                    Text("No exercise sets recorded yet")
                                        .foregroundColor(.gray)
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                } else {
                                    ForEach(exerciseSets, id: \.objectID) { exerciseSet in
                                        HStack(spacing: 0) {
                                            Text(exerciseSet.date ?? Date(), formatter: itemFormatter)
                                                .frame(width: 180, alignment: .leading)
                                                .padding(.horizontal, 8)
                                            
                                            Text(exerciseSet.exerciseName ?? "Unknown")
                                                .frame(width: 220, alignment: .leading)
                                                .padding(.horizontal, 8)
                                            
                                            Text("\(exerciseSet.setNumber)")
                                                .font(.caption)
                                                .frame(width: 80, alignment: .center)
                                                .padding(.horizontal, 8)
                                            
                                            Text("\(exerciseSet.reps)")
                                                .font(.caption)
                                                .frame(width: 80, alignment: .center)
                                                .padding(.horizontal, 8)
                                            
                                            HStack {
                                                Image(systemName: exerciseSet.hasPain ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                                    .foregroundColor(exerciseSet.hasPain ? .red : .green)
                                                Text(exerciseSet.hasPain ? "Yes" : "No")
                                                    .font(.caption)
                                            }
                                            .frame(width: 80, alignment: .center)
                                            .padding(.horizontal, 8)
                                        }
                                        .padding(.vertical, 8)
                                        .background(exerciseSet.hasPain ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
                                        .border(Color.gray.opacity(0.2), width: 0.5)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                
                // Summary Stats
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    HStack {
                        Text("Total Sets:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(exerciseSets.count)")
                            .font(.caption)
                            .bold()
                        
                        Spacer()
                        
                        Text("Total Reps:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(exerciseSets.reduce(0) { $0 + Int($1.reps) })")
                            .font(.caption)
                            .bold()
                        
                        Spacer()
                        
                        Text("Sets with Pain:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(exerciseSets.filter { $0.hasPain }.count)")
                            .font(.caption)
                            .bold()
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Exercise Log")
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
            let fileName = "ExerciseLog_\(Date().timeIntervalSince1970).csv"
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
        var csvText = "Date,Time,Exercise Name,Set #,Reps,Pain\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        
        for exerciseSet in exerciseSets {
            let date = exerciseSet.date ?? Date()
            let dateString = dateFormatter.string(from: date)
            let timeString = timeFormatter.string(from: date)
            let exerciseName = (exerciseSet.exerciseName ?? "Unknown").replacingOccurrences(of: "\"", with: "\"\"")
            let setNumber = "\(exerciseSet.setNumber)"
            let reps = "\(exerciseSet.reps)"
            let pain = exerciseSet.hasPain ? "Yes" : "No"
            
            let line = "\"\(dateString)\",\"\(timeString)\",\"\(exerciseName)\",\"\(setNumber)\",\"\(reps)\",\"\(pain)\"\n"
            csvText += line
        }
        
        return csvText
    }
}
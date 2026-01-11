import SwiftUI
import CoreData
import UIKit

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Symptom.date, ascending: false)],
        animation: .default)
    private var symptoms: FetchedResults<Symptom>
    
    @State private var isGeneratingCSV = false
    @State private var filterPresent: Bool? = nil // nil = all, true = present only, false = absent only
    
    var filteredSymptoms: [Symptom] {
        if let filterPresent = filterPresent {
            return symptoms.filter { $0.isPresent == filterPresent }
        }
        return Array(symptoms)
    }
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 0) {
                
                // Export and Filter Controls
                VStack(spacing: 12) {
                    // Export Button
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
                    
                    // Filter Controls
                    HStack(spacing: 8) {
                        Text("Filter:")
                            .font(.subheadline)
                        
                        Button(action: { filterPresent = nil }) {
                            Text("All")
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(filterPresent == nil ? Color.blue : Color.gray.opacity(0.3))
                                .foregroundColor(filterPresent == nil ? .white : .primary)
                                .cornerRadius(6)
                        }
                        
                        Button(action: { filterPresent = true }) {
                            Text("Present")
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(filterPresent == true ? Color.green : Color.gray.opacity(0.3))
                                .foregroundColor(filterPresent == true ? .white : .primary)
                                .cornerRadius(6)
                        }
                        
                        Button(action: { filterPresent = false }) {
                            Text("Absent")
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(filterPresent == false ? Color.red : Color.gray.opacity(0.3))
                                .foregroundColor(filterPresent == false ? .white : .primary)
                                .cornerRadius(6)
                        }
                    }
                    .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 16)
                
                if isGeneratingCSV {
                    Text("Generating your export file...")
                        .foregroundColor(.gray)
                        .padding(.bottom, 16)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                
                // Symptom Table
                ScrollView(.horizontal) {
                    VStack(alignment: .leading, spacing: 0) {
                        // Header Row
                        HStack(spacing: 0) {
                            Text("Date & Time")
                                .bold()
                                .frame(width: 180, alignment: .leading)
                                .padding(.horizontal, 8)
                            
                            Text("Symptom Name")
                                .bold()
                                .frame(width: 220, alignment: .leading)
                                .padding(.horizontal, 8)
                            
                            Text("Status")
                                .bold()
                                .frame(width: 100, alignment: .center)
                                .padding(.horizontal, 8)
                        }
                        .padding(.vertical, 12)
                        .background(Color(.systemGray6))
                        .border(Color.black, width: 1)
                        
                        // Data Rows
                        ScrollView(.vertical) {
                            VStack(spacing: 0) {
                                if filteredSymptoms.isEmpty {
                                    Text("No symptoms recorded yet")
                                        .foregroundColor(.gray)
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                } else {
                                    ForEach(filteredSymptoms, id: \.objectID) { symptom in
                                        HStack(spacing: 0) {
                                            Text(symptom.date ?? Date(), formatter: itemFormatter)
                                                .frame(width: 180, alignment: .leading)
                                                .padding(.horizontal, 8)
                                            
                                            Text(symptom.symptomName ?? "Unknown")
                                                .frame(width: 220, alignment: .leading)
                                                .padding(.horizontal, 8)
                                            
                                            HStack {
                                                Image(systemName: symptom.isPresent ? "checkmark.circle.fill" : "xmark.circle")
                                                    .foregroundColor(symptom.isPresent ? .green : .red)
                                                Text(symptom.isPresent ? "Present" : "Absent")
                                                    .font(.caption)
                                            }
                                            .frame(width: 100, alignment: .center)
                                            .padding(.horizontal, 8)
                                        }
                                        .padding(.vertical, 8)
                                        .background(symptom.isPresent ? Color.green.opacity(0.1) : Color(UIColor.secondarySystemBackground))
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
                        Text("Total Entries:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(symptoms.count)")
                            .font(.caption)
                            .bold()
                        
                        Spacer()
                        
                        Text("Present:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(symptoms.filter { $0.isPresent }.count)")
                            .font(.caption)
                            .bold()
                            .foregroundColor(.green)
                        
                        Spacer()
                        
                        Text("Absent:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(symptoms.filter { !$0.isPresent }.count)")
                            .font(.caption)
                            .bold()
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Symptom Log")
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
            let fileName = "SymptomLog_\(Date().timeIntervalSince1970).csv"
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
        var csvText = "Date,Time,Symptom Name,Status\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        
        for symptom in symptoms {
            let date = symptom.date ?? Date()
            let dateString = dateFormatter.string(from: date)
            let timeString = timeFormatter.string(from: date)
            let symptomName = (symptom.symptomName ?? "Unknown").replacingOccurrences(of: "\"", with: "\"\"")
            let status = symptom.isPresent ? "Present" : "Absent"
            
            let line = "\"\(dateString)\",\"\(timeString)\",\"\(symptomName)\",\"\(status)\"\n"
            csvText += line
        }
        
        return csvText
    }
}

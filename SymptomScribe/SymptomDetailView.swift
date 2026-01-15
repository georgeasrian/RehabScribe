//
//  SymptomDetailView.swift
//  SymptomScribe
//
//  Created by Samay coding on 1/11/26.
//


import SwiftUI
import CoreData

struct SymptomDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var note: Note
    
    @FetchRequest var symptoms: FetchedResults<Symptom>
    
    init(note: Note) {
        self.note = note
        
        // Fetch symptoms for this note
        let request: NSFetchRequest<Symptom> = Symptom.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Symptom.symptomName, ascending: true)]
        request.predicate = NSPredicate(format: "note == %@", note)
        _symptoms = FetchRequest(fetchRequest: request)
    }
    
    var presentSymptoms: [Symptom] {
        symptoms.filter { $0.isPresent }
    }
    
    var absentSymptoms: [Symptom] {
        symptoms.filter { !$0.isPresent }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                // Date and Time
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recording Date")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(note.date ?? Date(), style: .date)
                        .font(.headline)
                    Text(note.date ?? Date(), style: .time)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(8)
                
                // Transcribed Text
                VStack(alignment: .leading, spacing: 8) {
                    Text("Transcribed Speech")
                        .font(.headline)
                    
                    TextEditor(text: Binding(
                        get: { note.transcribedText ?? "" },
                        set: { note.transcribedText = $0 }
                    ))
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(Color(UIColor.tertiarySystemBackground))
                    .cornerRadius(8)
                    .onChange(of: note.transcribedText) { _ in
                        saveContext()
                    }
                }
                
                // Detected Symptoms (Present)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Detected Symptoms")
                            .font(.headline)
                        Spacer()
                        Text("\(presentSymptoms.count)")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    }
                    
                    if presentSymptoms.isEmpty {
                        Text("No symptoms detected in this recording")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .italic()
                            .padding()
                    } else {
                        VStack(spacing: 12) {
                            ForEach(presentSymptoms, id: \.objectID) { symptom in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "circle.fill")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                        Text(symptom.symptomName ?? "Unknown")
                                            .font(.subheadline)
                                        Spacer()
                                        
                                        // Toggle to mark as absent
                                        Toggle("", isOn: Binding(
                                            get: { symptom.isPresent },
                                            set: { symptom.isPresent = $0; saveContext() }
                                        ))
                                        .labelsHidden()
                                    }
                                    
                                    // Severity selector
                                    HStack {
                                        Text("Severity:")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        // Severity slider or null indicator
                                        if symptom.severity > 0 && symptom.severity <= 10 {
                                            HStack(spacing: 4) {
                                                Slider(value: Binding(
                                                    get: { Double(symptom.severity) },
                                                    set: { 
                                                        symptom.severity = Int16($0)
                                                        saveContext()
                                                    }
                                                ), in: 1...10, step: 1)
                                                .frame(maxWidth: 150)
                                                
                                                Text("\(symptom.severity)/10")
                                                    .font(.caption)
                                                    .foregroundColor(.primary)
                                                    .frame(width: 40, alignment: .trailing)
                                            }
                                        } else {
                                            Text("Not specified")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .italic()
                                            
                                            Spacer()
                                            
                                            // Button to set severity
                                            Button("Set") {
                                                symptom.severity = 5  // Default to 5
                                                saveContext()
                                            }
                                            .font(.caption)
                                            .buttonStyle(.bordered)
                                        }
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(6)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(8)
                
                // Non-Detected Symptoms (Absent)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "xmark.circle")
                            .foregroundColor(.gray)
                        Text("Not Detected")
                            .font(.headline)
                        Spacer()
                        Text("\(absentSymptoms.count)")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.gray)
                            .cornerRadius(4)
                    }
                    
                    if !absentSymptoms.isEmpty {
                        VStack(spacing: 6) {
                            ForEach(absentSymptoms, id: \.objectID) { symptom in
                                HStack {
                                    Image(systemName: "circle")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Text(symptom.symptomName ?? "Unknown")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    
                                    // Toggle to mark as present
                                    Toggle("", isOn: Binding(
                                        get: { symptom.isPresent },
                                        set: { 
                                            symptom.isPresent = $0
                                            // When marking as present, set default severity if not set
                                            if $0 && symptom.severity == 0 {
                                                symptom.severity = 5
                                            }
                                            saveContext() 
                                        }
                                    ))
                                    .labelsHidden()
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.gray.opacity(0.05))
                                .cornerRadius(4)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(8)
            }
            .padding()
        }
        .navigationTitle("Symptom Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveContext()
                }
            }
        }
    }
    
    private func saveContext() {
        // Update summary when symptoms change
        let detected = symptoms.filter { $0.isPresent }.map { $0.symptomName ?? "" }
        if detected.isEmpty {
            note.summary = "No symptoms"
        } else {
            note.summary = detected.prefix(3).joined(separator: ", ")
            if detected.count > 3 {
                note.summary! += ", ..."
            }
        }
        
        // Reset severity to 0 when marking as not present
        for symptom in symptoms {
            if !symptom.isPresent && symptom.severity > 0 {
                symptom.severity = 0
            }
        }
        
        if viewContext.hasChanges {
            do {
                try viewContext.save()
                print("Context saved successfully")
            } catch {
                print("Failed to save context: \(error.localizedDescription)")
            }
        }
    }
}

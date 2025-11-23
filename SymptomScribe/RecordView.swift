//
//  RecordView.swift
//  SymptomScribe
//
//  Created by Aashni Shah on 9/29/24.
//  Modified by Samay Prabhu on 11/22/25
//

import SwiftUI
import Speech
import CoreData

struct RecordView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var speechRecognizer: SpeechRecognizer?
    @State private var isRecording = false
    @State private var transcribedText = ""
    @State private var statusMessage = ""
    @State private var submissionStatus: String? = nil
    @State private var isSubmitting = false
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            
            // Status Message During Recording
            if isRecording {
                Text(statusMessage)
                    .frame(height: 150)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.blue)
            }
            
            // Submission Status Message After Submission
            if let submissionStatus = submissionStatus {
                Text(submissionStatus)
                    .padding()
                    .background(submissionStatus.contains("successfully") ? Color.green.opacity(0.3) : Color.red.opacity(0.3))
                    .foregroundColor(submissionStatus.contains("successfully") ? .green : .red)
                    .cornerRadius(8)
                    .multilineTextAlignment(.center)
            }
            
            // Recording Buttons: Record and Stop
            HStack {
                Button(action: {
                    if !isRecording {
                        startRecording()
                    }
                }) {
                    Text("Record")
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .padding()
                        .background(isRecording ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .accessibilityLabel("Record Button")
                .disabled(isRecording)
                
                Button(action: {
                    if isRecording {
                        stopRecording()
                    }
                }) {
                    Text("Stop")
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .padding()
                        .background(isRecording ? Color.red : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .accessibilityLabel("Stop Button")
                .disabled(!isRecording)
            }
            .padding(.horizontal)
            
            // Submit Button
            Button(action: submitRecording) {
                Text("Submit")
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .padding()
                    .background(transcribedText.isEmpty || isRecording ? Color.gray : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .accessibilityLabel("Submit Button")
            .disabled(transcribedText.isEmpty || isRecording || isSubmitting)
            .padding(.horizontal)
            
            // Text to Prompt the User for Cardiology Recording
            Text("Cardiology Symptom Recorder")
                .font(.headline)
                .padding(.top, 20)
            
            Text("""
                Please describe any cardiac symptoms experienced, including:

                - Chest pain (at rest or on exertion)  
                - Palpitations or irregular heartbeats  
                - Shortness of breath  
                - Fatigue or lightheadedness  
                - Sweating, nausea, or anxiety  
                - Any dizziness or fainting episodes  

                Try to provide context: when the symptom occurred, what triggered it, and how long it lasted.

                Multiple episodes can be recorded in separate entries.
                """)
                .multilineTextAlignment(.leading)
                .padding()
            
            Spacer()
            
            // Navigation Button to View Recordings
            NavigationLink(destination: NotesListView()) {
                Text("View Recordings")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(idealWidth: 100)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
                    .padding(.horizontal)
            }
        }
        .padding()
        .navigationTitle("Cardiology Recorder")
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK")) {
                    submissionStatus = nil
                }
            )
        }
    }
    
    // MARK: - Recording Functions
    func startRecording() {
        if speechRecognizer == nil {
            speechRecognizer = SpeechRecognizer()
        }
        speechRecognizer?.transcribe { success in
            DispatchQueue.main.async {
                if success {
                    self.isRecording = true
                    self.statusMessage = "Recording... Press Stop when done."
                    self.submissionStatus = nil
                } else {
                    self.alertTitle = "Permission Denied"
                    self.alertMessage = "Please enable speech recognition and microphone permissions in settings."
                    self.showingAlert = true
                    self.speechRecognizer = nil
                }
            }
        }
    }
    
    func stopRecording() {
        speechRecognizer?.stopTranscribing()
        transcribedText = speechRecognizer?.transcript.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        print("Transcribed Text: \(transcribedText)")
        statusMessage = "Recording stopped. Review your transcription and press Submit."
        isRecording = false
        speechRecognizer = nil
    }
    
    func submitRecording() {
        guard !isSubmitting else { return }
        isSubmitting = true
        statusMessage = "Processing your recording..."
        submissionStatus = nil
        
        LocalLLMProcessor.shared.analyzeText(transcribedText) { output in
            DispatchQueue.main.async {
                self.isSubmitting = false
                
                guard let jsonString = output else {
                    self.showError("Failed to process recording with local model.")
                    return
                }

                guard let data = jsonString.data(using: .utf8),
                      let symptomsDict = try? JSONSerialization.jsonObject(with: data) as? [String: Bool] else {
                    self.showError("Invalid JSON format:\n\(jsonString)")
                    return
                }

                let success = self.saveSymptoms(symptomsDict, transcribedText: self.transcribedText)
                self.transcribedText = ""
                if success {
                    self.submissionStatus = "Recording submitted successfully."
                    self.alertTitle = "Success"
                } else {
                    self.submissionStatus = "Failed to save recording."
                    self.alertTitle = "Error"
                }
                self.alertMessage = self.submissionStatus ?? ""
                self.showingAlert = true
            }
        }
    }
    
    // MARK: - Core Data Saving
    private func saveSymptoms(_ symptoms: [String: Bool], transcribedText: String) -> Bool {
        let newNote = Note(context: viewContext)
        newNote.date = Date()
        newNote.transcribedText = transcribedText
        newNote.summary = ""
        
        for (symptom, present) in symptoms {
            let entry = ResistanceTraining(context: viewContext)
            entry.note = newNote
            entry.date = newNote.date
            entry.exerciseName = symptom
            entry.painOrDiscomfortYN = present
            entry.setNumberInSequence = 0
            entry.numberOfRepsInSet = 0
            entry.totalWeightLifted = 0
            entry.untilFailureYN = false
            entry.resistanceType = "Symptom"
            entry.muscleGroup = ""
            entry.restTimeInSecondsBeforeCurrentSetOptional = 0
        }
        
        do {
            try viewContext.save()
            print("Note and symptoms saved successfully.")
            return true
        } catch {
            print("Save error:", error)
            return false
        }
    }
    
    private func showError(_ message: String) {
        statusMessage = ""
        alertTitle = "Error"
        alertMessage = message
        showingAlert = true
    }
}

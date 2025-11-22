//
//  RecordView.swift
//  SymptomScribe
//
//  Created by Aashni Shah on 9/29/24.
//  Modified by Samay Prabhu on 08/03/25
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
            Button(action: {
                submitRecording()
            }) {
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
                        
            // Text to Prompt the User for Recording
            Text("We're here to help!")
                .font(.headline)
                .padding(.top, 20)
            
            //NEW TEXT TO DISPLAY ON SCREEN
            Text("""
                Please include in your recording:
                                
                Name of exercise, weights, sets, reps (and whether until failure), rest time between sets, and whether you experienced pain or discomfort.
                
                If multiple exercises performed in one session, record separate notes.
                
                If recording workouts involving two weights (one per hand), please record the total combined weight lifted.
                
                Similarly, for exercises with one weight that are repeated on both sides, please multiply the weight lifted by two.
                
                """)
                .multilineTextAlignment(.leading)
                .padding()

            
            Spacer()
            
            // Navigation Button at the Top
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
        .navigationTitle("Workout Recorder")
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
    
    
    func startRecording() {
        if speechRecognizer == nil {
            speechRecognizer = SpeechRecognizer()
        }
        speechRecognizer?.transcribe { success in
            DispatchQueue.main.async {
                if success {
                    self.isRecording = true
                    self.statusMessage = "Recording... Press Stop when done."
                    self.submissionStatus = nil // Reset submission status
                } else {
                    self.alertTitle = "Permission Denied"
                    self.alertMessage = "Please enable speech recognition and microphone permissions in settings."
                    self.showingAlert = true
                    self.speechRecognizer = nil // Release resources
                }
            }
        }
    }
    
    func stopRecording() {
        speechRecognizer?.stopTranscribing()
        transcribedText = speechRecognizer?.transcript.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        print("Transcribed Text: \(transcribedText)") // Debugging
        statusMessage = "Recording stopped. Review your transcription and press Submit."
        isRecording = false
        speechRecognizer = nil // Release resources
    }
    
    
    func submitRecording() {
        // Prevent multiple submissions by checking if we're already submitting
        guard !isSubmitting else { return }
        
        // Mark submission as in progress
        isSubmitting = true
        
        // Show a loading indicator if needed
        statusMessage = "Processing your recording..."
        submissionStatus = nil // Reset submission status
        
        // Call the local model
        LocalLLMProcessor.shared.analyzeText(transcribedText) { output in
            DispatchQueue.main.async {
                self.isSubmitting = false
                
                guard let output = output else {
                    self.statusMessage = ""
                    self.alertTitle = "Error"
                    self.alertMessage = "Failed to process recording with local model."
                    self.showingAlert = true
                    return
                }
                
                guard let jsonString = extractFirstJSONObject(from: output) else {
                    self.showError("No JSON object found in model output.")
                    return
                }

                // Parse into Swift array
                guard let data = jsonString.data(using: .utf8),
                      let exercises = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                    self.showError("Invalid JSON format:\n\(jsonString)")
                    return
                }
                
                // Save to Core Data
                let success = self.saveNote(resistanceTrainingData: exercises, transcribedText: self.transcribedText)
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
    
    private func saveNote(
        resistanceTrainingData: [[String: Any]],
        transcribedText: String
    ) -> Bool {
        // Create the parent Note
        let newNote = Note(context: viewContext)
        newNote.date = Date()
        newNote.transcribedText = transcribedText
        newNote.summary = ""

        // For each JSON object, create a ResistanceTraining child
        for rt in resistanceTrainingData {
            let entry = ResistanceTraining(context: viewContext)

            // Required fields:
            entry.date = newNote.date
            entry.resistanceType = rt["resistance_type"] as? String
                ?? "Unspecified"
            
            // Map JSON fields
            entry.exerciseName = rt["exercise"] as? String    ?? "Unspecified"
            entry.muscleGroup = rt["muscle_group"] as? String ?? "Unspecified"
            entry.setNumberInSequence = Int64(rt["sets"] as? Int ?? 0)
            entry.numberOfRepsInSet = Int64(rt["reps"] as? Int ?? 0)
            entry.untilFailureYN = rt["until_failure"] as? Bool ?? false

            // painOrDiscomfortYN is non-optional Bool
            entry.painOrDiscomfortYN   = (rt["pain_felt"] as? String) != nil

            // Optional numeric fields—use defaults if missing
            entry.totalWeightLifted = rt["weight"] as? Double ?? 0.0
            entry.restTimeInSecondsBeforeCurrentSetOptional =
                rt["rest_time_before_set"] as? Double as NSNumber?

            // Link back to the note
            entry.note = newNote
        }

        // Save context
        do {
            try viewContext.save()
            print("Note and associated data saved successfully.")
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
    
    // helper func for extracting JSON
    private func extractFirstJSONObject(from text: String) -> String? {
        guard let startIdx = text.firstIndex(of: "{") else { return nil }

        var braceCount = 0
        var endIdx: String.Index? = nil

        for idx in text[startIdx...].indices {
            if text[idx] == "{" {
                braceCount += 1
            } else if text[idx] == "}" {
                braceCount -= 1
                if braceCount == 0 {
                    endIdx = idx
                    break
                }
            }
        }

        if let endIdx = endIdx {
            let jsonObjectString = String(text[startIdx...endIdx])
            // Wrap the single JSON object in [ ] to form an array string
            return "[\(jsonObjectString)]"
        }
        return nil
    }



}

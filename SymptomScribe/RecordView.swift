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
            
            // Submission Status Message
            if let submissionStatus = submissionStatus {
                Text(submissionStatus)
                    .padding()
                    .background(submissionStatus.contains("successfully") ? Color.green.opacity(0.3) : Color.red.opacity(0.3))
                    .foregroundColor(submissionStatus.contains("successfully") ? .green : .red)
                    .cornerRadius(8)
                    .multilineTextAlignment(.center)
            }
            
            // Recording Buttons
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
            .disabled(transcribedText.isEmpty || isRecording || isSubmitting)
            .padding(.horizontal)
            
            // Instructions
            Text("Cardiology Symptom Recorder")
                .font(.headline)
                .padding(.top, 20)
            
            Text("""
                Please describe any cardiac symptoms you're experiencing:

                • Chest pain or discomfort (at rest or during activity)
                • Palpitations or irregular heartbeats
                • Shortness of breath or difficulty breathing
                • Fatigue, weakness, or lightheadedness
                • Swelling in legs, ankles, or feet
                • Dizziness, fainting, or near-fainting episodes
                • Sweating, nausea, or anxiety
                • Cough, wheezing, or abdominal discomfort

                """)
                .font(.subheadline)
                .multilineTextAlignment(.leading)
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(8)
            
            Spacer()
            
            // Navigation to Recordings
            NavigationLink(destination: NotesListView()) {
                Text("View Recordings")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(idealWidth: 100)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
        .padding()
        .navigationTitle("Record Symptoms")
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
                    self.alertMessage = "Please enable speech recognition and microphone permissions in Settings."
                    self.showingAlert = true
                    self.speechRecognizer = nil
                }
            }
        }
    }
    
    func stopRecording() {
        speechRecognizer?.stopTranscribing()
        transcribedText = speechRecognizer?.transcript.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        print("=== TRANSCRIBED TEXT ===")
        print(transcribedText)
        print("========================")
        statusMessage = "Recording stopped. Review and press Submit."
        isRecording = false
        speechRecognizer = nil
    }
    
    func submitRecording() {
        guard !isSubmitting else { return }
        isSubmitting = true
        statusMessage = "Processing your recording with AI..."
        submissionStatus = nil
        
        LocalLLMProcessor.shared.analyzeText(transcribedText) { output in
            DispatchQueue.main.async {
                self.isSubmitting = false
                
                guard let jsonString = output else {
                    self.showError("Failed to process recording. Please try again.")
                    return
                }
                
                print("=== JSON STRING ===")
                print(jsonString)
                print("===================")
                
                guard let data = jsonString.data(using: .utf8),
                      let symptomsDict = try? JSONSerialization.jsonObject(with: data) as? [String: Bool] else {
                    self.showError("Invalid response from AI model:\n\(jsonString)")
                    return
                }
                
                let success = self.saveSymptoms(symptomsDict, transcribedText: self.transcribedText)
                
                if success {
                    self.transcribedText = ""
                    self.submissionStatus = "Symptoms recorded successfully!"
                    self.alertTitle = "Success"
                    self.alertMessage = "Your symptoms have been saved."
                } else {
                    self.submissionStatus = "Failed to save symptoms."
                    self.alertTitle = "Error"
                    self.alertMessage = "There was a problem saving your recording."
                }
                
                self.showingAlert = true
            }
        }
    }
    
    // MARK: - Core Data Saving
    
    private func saveSymptoms(_ symptoms: [String: Bool], transcribedText: String) -> Bool {
        // Create new Note
        let newNote = Note(context: viewContext)
        newNote.date = Date()
        newNote.transcribedText = transcribedText
        
        // Create summary from detected symptoms
        let detectedSymptoms = symptoms.filter { $0.value }.map { $0.key }
        if detectedSymptoms.isEmpty {
            newNote.summary = "No symptoms detected"
        } else {
            newNote.summary = detectedSymptoms.prefix(3).joined(separator: ", ")
            if detectedSymptoms.count > 3 {
                newNote.summary! += ", ..."
            }
        }
        
        // Create Symptom entries for ALL symptoms (present and absent)
        for (symptomName, isPresent) in symptoms {
            let symptomEntry = Symptom(context: viewContext)
            symptomEntry.note = newNote
            symptomEntry.date = newNote.date
            symptomEntry.symptomName = symptomName
            symptomEntry.isPresent = isPresent
        }
        
        do {
            try viewContext.save()
            print("✅ Note and \(symptoms.count) symptoms saved successfully")
            return true
        } catch {
            print("❌ Save error: \(error)")
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

import SwiftUI
import Speech
import CoreData
import UserNotifications

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
            
            // Processing Status
            if isSubmitting {
                VStack(spacing: 8) {
                    Text("Processing...")
                        .font(.headline)
                    if !statusMessage.isEmpty {
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.3))
                .foregroundColor(.orange)
                .cornerRadius(8)
                .multilineTextAlignment(.center)
            }
            
            // Submission Status Message
            if let submissionStatus = submissionStatus, !isSubmitting {
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
        statusMessage = "Processing... This may take a minute or two."
        submissionStatus = "Analyzing symptoms..."
        
        // Request notification permission if not already granted
        requestNotificationPermission()
        
        // IMPORTANT: Metal GPU work requires app to be in foreground.
        // Background task helps extend time, but Metal calls will fail if app is backgrounded.
        // Processing should ideally complete while app is still active.
        var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(expirationHandler: {
            // Called when background time is about to expire (~30 seconds)
            // Don't end task here - let it continue processing if possible
            print("⚠️ Background task time expiring soon - processing may continue but Metal may fail if backgrounded")
            // Note: We don't end the task here to allow processing to continue
        })
        
        let capturedTaskID = backgroundTaskID
        print("🟢 submitRecording: Starting analysis for: '\(transcribedText)'")
        
        // Process immediately while app is in foreground (Metal works best here)
        LocalLLMProcessor.shared.analyzeText(transcribedText) { output in
            let appState = UIApplication.shared.applicationState
            let stateString = appState == .active ? "FOREGROUND" : appState == .background ? "BACKGROUND" : "INACTIVE"
            print("🟢 submitRecording: Completion callback received (app state: \(stateString)), output: \(output?.prefix(100) ?? "nil")")
            DispatchQueue.main.async {
                self.isSubmitting = false
                self.statusMessage = "" // Clear processing message
                
                // Handle nil output - use empty JSON as fallback
                let jsonString = output ?? "{}"
                
                print("=== JSON STRING ===")
                print(jsonString)
                print("===================")
                
                // Parse JSON with better error handling
                guard let data = jsonString.data(using: .utf8) else {
                    print("⚠️ Could not convert JSON string to data")
                    // Fallback: save with empty symptoms
                    let success = self.saveSymptoms([:], transcribedText: self.transcribedText)
                    
                    // End background task
                    if capturedTaskID != .invalid {
                        UIApplication.shared.endBackgroundTask(capturedTaskID)
                    }
                    
                    self.handleSubmissionResult(success: success, hadError: true)
                    return
                }
                
                var symptomsDict: [String: Any] = [:]
                
                do {
                    if let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        symptomsDict = parsed
                    } else {
                        print("⚠️ JSON is not a dictionary, using empty dict")
                        symptomsDict = [:]
                    }
                } catch {
                    print("⚠️ JSON parsing error: \(error.localizedDescription)")
                    print("Raw JSON string: \(jsonString)")
                    // Fallback: use empty dictionary (no symptoms detected)
                    symptomsDict = [:]
                }
                
                // Save symptoms (even if empty, we still save the note)
                let success = self.saveSymptoms(symptomsDict, transcribedText: self.transcribedText)
                
                // End background task
                if capturedTaskID != .invalid {
                    UIApplication.shared.endBackgroundTask(capturedTaskID)
                }
                
                // Send notification if processing completed
                if success {
                    self.sendNotification(title: "Symptom Interpretation Logged", body: "Your symptoms have been saved and analyzed.")
                }
                
                self.handleSubmissionResult(success: success, hadError: false)
            }
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("⚠️ Notification permission error: \(error.localizedDescription)")
            } else if granted {
                print("✅ Notification permission granted")
            } else {
                print("⚠️ Notification permission denied")
            }
        }
    }
    
    private func sendNotification(title: String, body: String) {
        // Check if app is in foreground - if so, use UNNotificationPresentationOption
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            content.badge = 1
            
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil // Send immediately
            )
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("⚠️ Failed to send notification: \(error.localizedDescription)")
                    print("⚠️ Notification settings: authorized=\(settings.authorizationStatus == .authorized)")
                } else {
                    print("✅ Notification sent: \(title)")
                    print("✅ Notification settings: authorized=\(settings.authorizationStatus == .authorized), alert=\(settings.alertSetting.rawValue)")
                }
            }
        }
    }
    
    private func handleSubmissionResult(success: Bool, hadError: Bool) {
        if success {
            self.transcribedText = ""
            self.submissionStatus = "Symptoms recorded successfully!"
            self.alertTitle = "Success"
            if hadError {
                self.alertMessage = "Your symptoms have been saved. Note: Some symptoms may not have been detected due to processing issues."
            } else {
                self.alertMessage = "Your symptoms have been saved."
            }
        } else {
            self.submissionStatus = "Failed to save symptoms."
            self.alertTitle = "Error"
            self.alertMessage = "There was a problem saving your recording. Please try again."
        }
        
        self.showingAlert = true
    }
    
    // MARK: - Core Data Saving
    
    private func saveSymptoms(_ symptomsDict: [String: Any], transcribedText: String) -> Bool {
        // Create new Note
        let newNote = Note(context: viewContext)
        newNote.date = Date()
        newNote.transcribedText = transcribedText
        
        // Parse symptoms from LLM response
        // IMPORTANT: Only accept symptom names from the predefined list to prevent invalid entries
        var detectedSymptoms: [String] = []
        var symptomData: [String: (isPresent: Bool, severity: Int16?)] = [:]
        let validSymptomNames = Set(LocalLLMProcessor.allSymptoms)
        
        for (symptomName, value) in symptomsDict {
            // Filter out any symptom names not in the predefined list
            guard validSymptomNames.contains(symptomName) else {
                print("⚠️ Ignoring invalid symptom name from LLM: '\(symptomName)'")
                continue
            }
            
            if let symptomInfo = value as? [String: Any] {
                let isPresent = symptomInfo["isPresent"] as? Bool ?? false
                var severity: Int16? = nil
                if let severityValue = symptomInfo["severity"] as? Int {
                    severity = Int16(severityValue)
                } else if let severityValue = symptomInfo["severity"] as? Int64 {
                    severity = Int16(severityValue)
                }
                symptomData[symptomName] = (isPresent: isPresent, severity: severity)
                if isPresent {
                    detectedSymptoms.append(symptomName)
                }
            }
        }
        
        // Create summary from detected symptoms
        if detectedSymptoms.isEmpty {
            newNote.summary = "No symptoms detected"
        } else {
            newNote.summary = detectedSymptoms.prefix(3).joined(separator: ", ")
            if detectedSymptoms.count > 3 {
                newNote.summary! += ", ..."
            }
        }
        
        // Create Symptom entries for ALL symptoms from allSymptoms list
        // This ensures every symptom card is tracked for each recording
        for symptomName in LocalLLMProcessor.allSymptoms {
            let symptomEntry = Symptom(context: viewContext)
            symptomEntry.note = newNote
            symptomEntry.date = newNote.date
            symptomEntry.symptomName = symptomName
            
            if let data = symptomData[symptomName] {
                // Symptom was detected by LLM
                symptomEntry.isPresent = data.isPresent
                symptomEntry.severity = data.severity ?? 0  // 0 means null/not specified
            } else {
                // Symptom was not detected/mentioned by LLM
                symptomEntry.isPresent = false
                symptomEntry.severity = 0  // 0 means null/not detected
            }
        }
        
        do {
            try viewContext.save()
            print("✅ Note and \(LocalLLMProcessor.allSymptoms.count) symptoms saved successfully")
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

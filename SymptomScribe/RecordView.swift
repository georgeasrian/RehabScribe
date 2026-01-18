import SwiftUI
import Speech
import CoreData

enum RecordingMode {
    case exercises
    case koosJR
}

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
    @State private var recordingMode: RecordingMode? = nil
    
    var body: some View {
        VStack(spacing: 20) {
            
            // Mode Selection Buttons (shown when not recording)
            if !isRecording && recordingMode == nil {
                VStack(spacing: 16) {
                    Button(action: {
                        recordingMode = .exercises
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.system(size: 40))
                            Text("Record Exercise Session")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                    Button(action: {
                        recordingMode = .koosJR
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: "list.clipboard")
                                .font(.system(size: 40))
                            Text("Record KOOS JR Survey")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
            }
            
            // Instructions for current mode
            if let mode = recordingMode {
                VStack(alignment: .leading, spacing: 12) {
                    if mode == .exercises {
                        Text("Exercise Recording Mode")
                            .font(.headline)
                            .padding(.bottom, 4)
                        
                        Text("""
                        Describe your rehabilitation exercises. Include:
                        • Exercise name (e.g., "Supine heel slides", "Quad sets")
                        • Set number and number of reps
                        • Any pain or discomfort
        
                        Example: "Supine heel slides, set one, ten reps, no discomfort. Set two, ten reps, slight pain."
                        """)
                            .font(.subheadline)
                    } else {
                        Text("KOOS JR Questionnaire")
                            .font(.headline)
                            .padding(.bottom, 4)
                        
                        Text("""
                        Answer these 7 questions about your knee:
                        1. Stiffness after wakening
                        2. Twisting/pivoting pain
                        3. Straightening knee fully
                        4. Going up or down stairs
                        5. Standing upright
                        6. Rising from sitting
                        7. Bending to floor/picking up object
        
                        For each, say: None, Mild, Moderate, Severe, or Extreme
                        You can speak freely about all questions.
                        """)
                            .font(.subheadline)
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(8)
            }
            
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
            
            // Recording Buttons (shown when mode is selected)
            if recordingMode != nil {
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
                
                // Back button to change mode
                Button(action: {
                    recordingMode = nil
                    transcribedText = ""
                    submissionStatus = nil
                    statusMessage = ""
                }) {
                    Text("Change Mode")
                        .foregroundColor(.blue)
                }
                .padding(.top, 8)
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Record")
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK")) {
                    submissionStatus = nil
                    if submissionStatus?.contains("successfully") == true {
                        recordingMode = nil
                        transcribedText = ""
                    }
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
        guard !isSubmitting, let mode = recordingMode else { return }
        isSubmitting = true
        statusMessage = "Processing your recording with AI..."
        submissionStatus = nil
        
        // Add timeout protection (60 seconds)
        var timeoutWorkItem: DispatchWorkItem?
        timeoutWorkItem = DispatchWorkItem {
            DispatchQueue.main.async {
                if self.isSubmitting {
                    self.isSubmitting = false
                    self.showError("Processing took too long. Please try again.")
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 60, execute: timeoutWorkItem!)
        
        let completion: (String?) -> Void = { output in
            timeoutWorkItem?.cancel()
            
            DispatchQueue.main.async {
                self.isSubmitting = false
                
                // Handle nil output - use empty JSON as fallback
                let jsonString = output ?? (mode == .exercises ? "[]" : "{}")
                
                print("=== JSON STRING ===")
                print(jsonString)
                print("===================")
                
                // Parse JSON with better error handling
                guard let data = jsonString.data(using: .utf8) else {
                    print("⚠️ Could not convert JSON string to data")
                    let success = mode == .exercises ? self.saveExerciseSets([], transcribedText: self.transcribedText) : self.saveKOOSJR([:], transcribedText: self.transcribedText)
                    self.handleSubmissionResult(success: success, hadError: true, mode: mode)
                    return
                }
                
                if mode == .exercises {
                    // Parse array of exercise sets
                    do {
                        if let setsArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                            let success = self.saveExerciseSets(setsArray, transcribedText: self.transcribedText)
                            self.handleSubmissionResult(success: success, hadError: false, mode: mode)
                        } else {
                            print("⚠️ JSON is not an array")
                            let success = self.saveExerciseSets([], transcribedText: self.transcribedText)
                            self.handleSubmissionResult(success: success, hadError: true, mode: mode)
                        }
                    } catch {
                        print("⚠️ JSON parsing error: \(error.localizedDescription)")
                        let success = self.saveExerciseSets([], transcribedText: self.transcribedText)
                        self.handleSubmissionResult(success: success, hadError: true, mode: mode)
                    }
                } else {
                    // Parse KOOS JR responses
                    do {
                        if let responsesDict = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            let success = self.saveKOOSJR(responsesDict, transcribedText: self.transcribedText)
                            self.handleSubmissionResult(success: success, hadError: false, mode: mode)
                        } else {
                            print("⚠️ JSON is not a dictionary")
                            let success = self.saveKOOSJR([:], transcribedText: self.transcribedText)
                            self.handleSubmissionResult(success: success, hadError: true, mode: mode)
                        }
                    } catch {
                        print("⚠️ JSON parsing error: \(error.localizedDescription)")
                        let success = self.saveKOOSJR([:], transcribedText: self.transcribedText)
                        self.handleSubmissionResult(success: success, hadError: true, mode: mode)
                    }
                }
            }
        }
        
        if mode == .exercises {
            LocalLLMProcessor.shared.analyzeExerciseText(transcribedText, completion: completion)
        } else {
            LocalLLMProcessor.shared.analyzeKOOSJRText(transcribedText, completion: completion)
        }
    }
    
    private func handleSubmissionResult(success: Bool, hadError: Bool, mode: RecordingMode) {
        if success {
            self.transcribedText = ""
            let modeText = mode == .exercises ? "exercises" : "KOOS JR responses"
            self.submissionStatus = "\(modeText.capitalized) recorded successfully!"
            self.alertTitle = "Success"
            if hadError {
                self.alertMessage = "Your \(modeText) have been saved. Note: Some data may not have been detected due to processing issues."
            } else {
                self.alertMessage = "Your \(modeText) have been saved."
            }
        } else {
            let modeText = mode == .exercises ? "exercises" : "KOOS JR responses"
            self.submissionStatus = "Failed to save \(modeText)."
            self.alertTitle = "Error"
            self.alertMessage = "There was a problem saving your recording. Please try again."
        }
        
        self.showingAlert = true
    }
    
    // MARK: - Core Data Saving
    
    private func saveExerciseSets(_ setsArray: [[String: Any]], transcribedText: String) -> Bool {
        let today = Calendar.current.startOfDay(for: Date())
        
        // Get existing sets for today to calculate next set number
        let fetchRequest: NSFetchRequest<ExerciseSet> = ExerciseSet.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "date >= %@", today as NSDate)
        
        var maxSetNumber = 0
        do {
            let existingSets = try viewContext.fetch(fetchRequest)
            maxSetNumber = existingSets.map { Int($0.setNumber) }.max() ?? 0
        } catch {
            print("⚠️ Error fetching existing sets: \(error)")
        }
        
        let validExercises = Set(LocalLLMProcessor.allExercises)
        var savedCount = 0
        var currentSetNumber = maxSetNumber
        
        for setDict in setsArray {
            guard let exerciseName = setDict["exerciseName"] as? String,
                  validExercises.contains(exerciseName) else {
                print("⚠️ Ignoring invalid exercise name")
                continue
            }
            
            // If LLM provided set number, use it (but ensure it's at least maxSetNumber + 1)
            // Otherwise, increment from maxSetNumber
            currentSetNumber += 1
            let llmSetNumber = setDict["setNumber"] as? Int
            let finalSetNumber = llmSetNumber != nil ? max(currentSetNumber, llmSetNumber!) : currentSetNumber
            
            let exerciseSet = ExerciseSet(context: viewContext)
            exerciseSet.date = Date()
            exerciseSet.exerciseName = exerciseName
            exerciseSet.setNumber = Int32(finalSetNumber)
            exerciseSet.reps = Int32((setDict["reps"] as? Int) ?? 0)
            exerciseSet.hasPain = (setDict["hasPain"] as? Bool) ?? true // Default to true if not clarified
            
            currentSetNumber = finalSetNumber
            savedCount += 1
        }
        
        do {
            try viewContext.save()
            print("✅ Saved \(savedCount) exercise sets successfully")
            return true
        } catch {
            print("❌ Save error: \(error)")
            return false
        }
    }
    
    private func saveKOOSJR(_ responsesDict: [String: Any], transcribedText: String) -> Bool {
        let koosJR = KOOSJRResponse(context: viewContext)
        koosJR.date = Date()
        
        // Extract responses (default to 0 if not found)
        koosJR.stiffnessAfterWaking = Int16((responsesDict["stiffnessAfterWaking"] as? Int) ?? 0)
        koosJR.twistingPivotingPain = Int16((responsesDict["twistingPivotingPain"] as? Int) ?? 0)
        koosJR.straighteningKneeFully = Int16((responsesDict["straighteningKneeFully"] as? Int) ?? 0)
        koosJR.goingUpDownStairs = Int16((responsesDict["goingUpDownStairs"] as? Int) ?? 0)
        koosJR.standingUpright = Int16((responsesDict["standingUpright"] as? Int) ?? 0)
        koosJR.risingFromSitting = Int16((responsesDict["risingFromSitting"] as? Int) ?? 0)
        koosJR.bendingToFloor = Int16((responsesDict["bendingToFloor"] as? Int) ?? 0)
        
        // Calculate raw score (sum of all 7 items)
        let rawScore = koosJR.stiffnessAfterWaking +
                      koosJR.twistingPivotingPain +
                      koosJR.straighteningKneeFully +
                      koosJR.goingUpDownStairs +
                      koosJR.standingUpright +
                      koosJR.risingFromSitting +
                      koosJR.bendingToFloor
        
        koosJR.rawScore = rawScore
        
        // Calculate transformed score (0-100, higher = better)
        koosJR.transformedScore = LocalLLMProcessor.calculateKOOSJRScore(rawScore: rawScore)
        
        do {
            try viewContext.save()
            print("✅ KOOS JR response saved successfully (raw score: \(rawScore), transformed: \(koosJR.transformedScore))")
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
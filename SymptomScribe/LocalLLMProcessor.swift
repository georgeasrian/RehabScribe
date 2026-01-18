import Foundation
import LLM  // The eastriverlee/LLM.swift package

class LocalLLMProcessor {
    static let shared = LocalLLMProcessor()
    private var llm: LLM?
    
    // Exercise names (normalized/cleaned up)
    static let allExercises = [
        "Supine Heel Slides",
        "Supine Hamstring Stretch",
        "Long Sitting Calf Stretch",
        "Quad Sets",
        "Sit-to-Stands",
        "Goblet Squats",
        "Step-Ups / Step-Downs",
        "Machine Leg Press"
    ]
    
    // KOOS JR questions
    static let koosJRQuestions = [
        "stiffnessAfterWaking": "Stiffness in your knee after wakening",
        "twistingPivotingPain": "Twisting/pivoting on your knee",
        "straighteningKneeFully": "Straightening your knee fully",
        "goingUpDownStairs": "Going up or down stairs",
        "standingUpright": "Standing upright",
        "risingFromSitting": "Rising from sitting",
        "bendingToFloor": "Bending to floor/picking up an object"
    ]
    
    private let systemPrompt = """
    You extract exercise data and KOOS JR questionnaire responses from speech transcripts and output only JSON.
    """
    
    private init() {
        loadModel()
    }
    
    private func loadModel() {
        guard let url = Bundle.main.url(
            forResource: "phi-2.Q4_K_M",
            withExtension: "gguf"
        ) else {
            print("phi-2.Q4_K_M.gguf not found in bundle")
            return
        }
        
        llm = LLM(
            from: url,
            template: .chatML(systemPrompt),
            maxTokenCount: 2048
        )
        print("Phi-2 model loaded successfully")
    }
    
    /// Analyzes exercise transcript and returns JSON with detected exercise sets
    func analyzeExerciseText(_ transcript: String, completion: @escaping (String?) -> Void) {
        // Reload model to reset state
        loadModel()
        
        guard let llm = llm else {
            print("LLM not yet loaded")
            completion(nil)
            return
        }
        
        let userMessage = buildExercisePrompt(transcript: transcript)
        
        Task.detached {
            let inputSeq = llm.preprocess(userMessage, [])
            let rawOutput = await llm.getCompletion(from: inputSeq)
            
            print("=== RAW LLM OUTPUT ===")
            print(rawOutput)
            print("======================")
            
            let cleanedOutput = self.extractValidJSON(from: rawOutput)
            
            print("=== CLEANED JSON ===")
            print(cleanedOutput ?? "nil")
            print("====================")
            
            DispatchQueue.main.async {
                completion(cleanedOutput)
            }
        }
    }
    
    /// Analyzes KOOS JR questionnaire transcript and returns JSON with structured answers
    func analyzeKOOSJRText(_ transcript: String, completion: @escaping (String?) -> Void) {
        // Reload model to reset state
        loadModel()
        
        guard let llm = llm else {
            print("LLM not yet loaded")
            completion(nil)
            return
        }
        
        let userMessage = buildKOOSJRPrompt(transcript: transcript)
        
        Task.detached {
            let inputSeq = llm.preprocess(userMessage, [])
            let rawOutput = await llm.getCompletion(from: inputSeq)
            
            print("=== RAW LLM OUTPUT (KOOS JR) ===")
            print(rawOutput)
            print("=================================")
            
            let cleanedOutput = self.extractValidJSON(from: rawOutput)
            
            print("=== CLEANED JSON (KOOS JR) ===")
            print(cleanedOutput ?? "nil")
            print("==============================")
            
            DispatchQueue.main.async {
                completion(cleanedOutput)
            }
        }
    }
    
    private func buildExercisePrompt(transcript: String) -> String {
        let exercisesList = LocalLLMProcessor.allExercises.map { "\"\($0)\"" }.joined(separator: ", ")
        return """
        Task: Extract exercise data from a rehabilitation session transcript. Output ONLY valid JSON. No explanations.
        
        CRITICAL RULES:
        1. You MUST ONLY use exercise names from the predefined list below. Map variations to canonical names:
           - "heel slides" or "supine heel slides" → "Supine Heel Slides"
           - "hamstring stretch" → "Supine Hamstring Stretch"
           - "calf stretch" or "long sitting calf stretch" → "Long Sitting Calf Stretch"
           - "quad sets" or "quadriceps sets" → "Quad Sets"
           - "sit to stands" or "sit-to-stand" → "Sit-to-Stands"
           - "goblet squats" → "Goblet Squats"
           - "step ups" or "step downs" or "step ups step downs" → "Step-Ups / Step-Downs"
           - "leg press" or "machine leg press" → "Machine Leg Press"
        
        2. For each set mentioned, extract:
           - exerciseName: normalized exercise name from list
           - setNumber: integer representing set number (increment for same exercise)
           - reps: integer number of repetitions
           - hasPain: boolean (true if pain/discomfort mentioned, false if explicitly "no pain"/"no discomfort", or default to true if not clarified)
        
        3. If user says "pain on all sets" or doesn't clarify pain for a set, assume hasPain = true for that set.
        
        4. Output format: An array of objects, each representing one set:
        [
          {"exerciseName": "Supine Heel Slides", "setNumber": 1, "reps": 10, "hasPain": false},
          {"exerciseName": "Supine Heel Slides", "setNumber": 2, "reps": 10, "hasPain": true}
        ]
        
        Available exercises (USE ONLY THESE EXACT NAMES):
        [\(exercisesList)]
        
        Example:
        Transcript: "Supine heel slides, set one, ten reps, no discomfort. Supine heel slides set two ten reps still a little twinge. Quad sets, set one, fifteen reps pain."
        JSON output:
        [{"exerciseName": "Supine Heel Slides", "setNumber": 1, "reps": 10, "hasPain": false}, {"exerciseName": "Supine Heel Slides", "setNumber": 2, "reps": 10, "hasPain": true}, {"exerciseName": "Quad Sets", "setNumber": 1, "reps": 15, "hasPain": true}]
        
        Now extract exercise data from this transcript:
        "\(transcript)"
        JSON output:
        """
    }
    
    private func buildKOOSJRPrompt(transcript: String) -> String {
        return """
        Task: Extract KOOS JR questionnaire responses from a patient's unstructured speech. Output ONLY valid JSON. No explanations.
        
        KOOS JR is a 7-item questionnaire. Each question is answered on a 5-point Likert scale:
        0 = None, 1 = Mild, 2 = Moderate, 3 = Severe, 4 = Extreme
        
        The 7 questions are:
        1. Stiffness in your knee after wakening (stiffnessAfterWaking)
        2. Twisting/pivoting on your knee (twistingPivotingPain)
        3. Straightening your knee fully (straighteningKneeFully)
        4. Going up or down stairs (goingUpDownStairs)
        5. Standing upright (standingUpright)
        6. Rising from sitting (risingFromSitting)
        7. Bending to floor/picking up an object (bendingToFloor)
        
        CRITICAL RULES:
        1. Map natural language to Likert scale values:
           - "none", "no", "nothing" → 0
           - "mild", "slight", "minimal", "a little" → 1
           - "moderate", "medium", "some" → 2
           - "severe", "bad", "very", "significant" → 3
           - "extreme", "worst", "terrible", "unbearable" → 4
        
        2. Extract answers from unstructured speech. If not mentioned, use 0 as default.
        
        3. Output format: A single JSON object with all 7 fields:
        {
          "stiffnessAfterWaking": 2,
          "twistingPivotingPain": 3,
          "straighteningKneeFully": 2,
          "goingUpDownStairs": 3,
          "standingUpright": 1,
          "risingFromSitting": 1,
          "bendingToFloor": 2
        }
        
        Example:
        Transcript: "My knee stiffness after waking in the morning is moderate. Twisting or pivoting on my knee gives me severe pain. Straightening my knee fully is moderate pain. Going up or down stairs is severe. Standing upright minimal pain. Rising from sitting is mild difficulty. Bending to the floor or picking up an object is moderate."
        JSON output:
        {"stiffnessAfterWaking": 2, "twistingPivotingPain": 3, "straighteningKneeFully": 2, "goingUpDownStairs": 3, "standingUpright": 1, "risingFromSitting": 1, "bendingToFloor": 2}
        
        Now extract KOOS JR responses from this transcript:
        "\(transcript)"
        JSON output:
        """
    }
    
    // Extract valid JSON object from LLM output with robust error handling
    func extractValidJSON(from rawOutput: String) -> String? {
        let trimmed = rawOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If empty, return empty JSON object
        guard !trimmed.isEmpty else {
            print("⚠️ Empty output from model, returning empty JSON")
            return "{}"
        }
        
        // Look for JSON object/array starting with '{' or '['
        let startChar: Character
        var endChar: Character
        
        if let objIdx = trimmed.firstIndex(of: "{") {
            startChar = "{"
            endChar = "}"
        } else if let arrIdx = trimmed.firstIndex(of: "[") {
            startChar = "["
            endChar = "]"
        } else {
            print("⚠️ No JSON object/array found in output, returning empty JSON")
            print("Raw output: \(trimmed)")
            return "{}"
        }
        
        guard let startIdx = trimmed.firstIndex(of: startChar) else {
            return "{}"
        }
        
        var braceCount = 0
        var endIdx: String.Index? = nil
        
        // Find matching closing brace/bracket
        for idx in trimmed[startIdx...].indices {
            let char = trimmed[idx]
            if char == startChar {
                braceCount += 1
            } else if char == endChar {
                braceCount -= 1
                if braceCount == 0 {
                    endIdx = idx
                    break
                }
            }
        }
        
        var jsonString: String
        
        if let endIdx = endIdx {
            // Complete JSON found
            jsonString = String(trimmed[startIdx...endIdx])
        } else {
            // JSON is incomplete - try to repair it
            print("⚠️ JSON incomplete, attempting repair...")
            var partial = String(trimmed[startIdx...])
            
            // Remove trailing comma if present
            partial = partial.trimmingCharacters(in: .whitespacesAndNewlines)
            if partial.hasSuffix(",") {
                partial = String(partial.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            // Add missing closing brace(s) based on brace count
            while braceCount > 0 {
                partial += String(endChar)
                braceCount -= 1
            }
            
            jsonString = partial
            print("🔧 Repaired JSON: \(jsonString)")
        }
        
        // Validate that the JSON is actually parseable
        if let data = jsonString.data(using: .utf8) {
            do {
                let _ = try JSONSerialization.jsonObject(with: data)
                print("✅ Valid JSON extracted")
                return jsonString
            } catch {
                print("⚠️ Extracted JSON is invalid: \(error.localizedDescription)")
                print("Attempted JSON: \(jsonString)")
                
                // Try one more repair: ensure it's at least a valid empty object
                if jsonString.trimmingCharacters(in: .whitespacesAndNewlines) == "{" {
                    return "{}"
                }
                
                // Last resort: return empty JSON object
                print("⚠️ Returning empty JSON as fallback")
                return "{}"
            }
        }
        
        // Fallback: return empty JSON object
        print("⚠️ Could not convert to data, returning empty JSON")
        return "{}"
    }
    
    // Calculate KOOS JR transformed score (0-100, higher = better)
    static func calculateKOOSJRScore(rawScore: Int16) -> Double {
        // KOOS JR transformation: score = 100 - (rawScore * 100 / 28)
        // Raw score range: 0-28 (7 items * 4 max)
        if rawScore == 0 {
            return 100.0
        }
        return 100.0 - (Double(rawScore) * 100.0 / 28.0)
    }
}
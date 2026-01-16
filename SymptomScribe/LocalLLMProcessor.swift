import Foundation
import LLM  // The eastriverlee/LLM.swift package

class LocalLLMProcessor {
    static let shared = LocalLLMProcessor()
    private var llm: LLM?
    
    // All 25 cardiac symptoms
    static let allSymptoms = [
        "Chest pain at rest",
        "Chest pain on exertion",
        "Chest discomfort",
        "Palpitations",
        "Fatigue at rest",
        "Exertional fatigue",
        "Dyspnea",
        "Orthopnea",
        "Paroxysmal nocturnal dyspnea",
        "Syncope",
        "Lightheadedness",
        "Peripheral edema",
        "Cough / wheezing",
        "Abdominal pain",
        "Early satiety",
        "Diaphoresis",
        "Nausea / vomiting",
        "Anxiety / restlessness",
        "Feeling irregularity of HR",
        "Pulse deficit",
        "Tachycardia",
        "Bradycardia",
        "Dizziness at rest",
        "Dizziness upon standing",
        "Nocturia"
    ]
    
    private let systemPrompt = """
    You extract symptoms from medical notes and output only JSON.
    """
    
    private init() {
        loadModel()
    }
    
    private func loadModel() {
        // Only load if not already loaded - CRITICAL for performance
        guard llm == nil else { return }
        
        guard let url = Bundle.main.url(
            forResource: "phi-2.Q4_K_M",
            withExtension: "gguf"
        ) else {
            print("phi-2.Q4_K_M.gguf not found in bundle")
            return
        }
        
        // Reduced context size for faster processing: 2048 -> 1536
        // LLM.swift should use Metal by default if available
        llm = LLM(
            from: url,
            template: .chatML(systemPrompt),
            maxTokenCount: 1536  // Reduced from 2048 for speed
        )
        print("Phi-2 model loaded successfully (Metal should be active if available)")
    }
    
    /// Analyzes transcript and returns JSON with detected symptoms
    func analyzeText(_ transcript: String, completion: @escaping (String?) -> Void) {
        // Ensure model is loaded, but don't reload every time
        if llm == nil {
            loadModel()
        }
        
        guard let llm = llm else {
            print("LLM not yet loaded")
            completion(nil)
            return
        }
        
        let userMessage = buildPrompt(transcript: transcript)
        
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
    
    private func buildPrompt(transcript: String) -> String {
        // SEMANTIC INTERPRETATION PROMPT - emphasizes understanding and reasoning
        let symptomsList = LocalLLMProcessor.allSymptoms.map { "\"\($0)\"" }.joined(separator: ", ")
        return """
        You are a medical symptom analyzer. Your job is to THINK and INTERPRET the patient's description semantically, understanding what they MEAN, not just matching words.
        
        SYMPTOM LIST (output ONLY these exact symptom names): [\(symptomsList)]
        
        HOW TO ANALYZE - Think conceptually about each symptom:
        
        CHEST PAIN SYMPTOMS - Understand context and timing:
        - "Chest pain at rest" = any chest pain/discomfort/pressure/tightness occurring when patient is NOT physically active (sitting, lying, standing still, at desk, relaxing, sleeping, etc.)
        - "Chest pain on exertion" = chest pain/discomfort during ANY physical activity (walking, exercise, climbing stairs, bending, lifting, moving around, etc.)
        - "Chest discomfort" = any non-painful chest sensation (pressure, tightness, fullness, heaviness)
        
        BREATHING SYMPTOMS - Understand what difficulty breathing means:
        - "Dyspnea" = ANY form of shortness of breath, difficulty breathing, feeling breathless, can't get enough air
        - "Orthopnea" = trouble breathing when lying flat/flat on back, better when sitting up or propped up
        - "Paroxysmal nocturnal dyspnea" = waking up suddenly at night feeling breathless, needing to sit up or stand
        
        FATIGUE - Understand when tiredness occurs:
        - "Fatigue at rest" = feeling tired/weak/exhausted even when not active, at baseline rest
        - "Exertional fatigue" = becoming unusually tired during or after physical activity
        
        DIZZINESS/LIGHTHEADEDNESS - Understand triggers and context:
        - "Lightheadedness" = feeling faint, woozy, like might pass out, general unsteadiness
        - "Dizziness at rest" = dizziness when sitting/lying/not moving
        - "Dizziness upon standing" = dizziness specifically when standing up from sitting/lying (orthostatic)
        
        HEART RATE SYMPTOMS:
        - "Palpitations" = feeling heart beating irregularly, skipping, fluttering, pounding, awareness of heartbeat
        - "Tachycardia" = fast heart rate, racing heart, heart beating too fast
        - "Bradycardia" = slow heart rate, heart beating too slow
        - "Feeling irregularity of HR" = patient notices their heartbeat is irregular, not normal rhythm
        - "Pulse deficit" = difference between heart rate and pulse rate (medical finding)
        
        OTHER SYMPTOMS:
        - "Peripheral edema" = ANY swelling in legs, ankles, feet, lower extremities
        - "Syncope" = fainting, passing out, loss of consciousness
        - "Cough / wheezing" = coughing, wheezing, whistling sounds when breathing
        - "Diaphoresis" = excessive sweating, profuse sweating
        - "Nausea / vomiting" = feeling nauseous, throwing up, vomiting
        - "Anxiety / restlessness" = feeling anxious, restless, uneasy, nervous
        - "Early satiety" = feeling full quickly after eating little
        - "Nocturia" = waking up at night to urinate
        - "Abdominal pain" = pain in stomach/abdomen area
        
        YOUR APPROACH:
        1. Read the patient's description carefully
        2. Understand what they MEAN conceptually, not just what words they used
        3. Think: "What symptom category does this description fall into?"
        4. Match to the closest symptom from the list based on MEANING
        5. Extract severity numbers if mentioned (1-10 scale)
        
        EXAMPLES OF REASONING (not phrase matching):
        - Any description of chest pain while inactive → "Chest pain at rest" (whether they say "sitting", "at desk", "watching TV", "lying down", "not doing anything")
        - Any description of chest pain during activity → "Chest pain on exertion" (whether they say "walking", "climbing stairs", "during exercise", "while active")
        - Any description of trouble breathing when lying down → "Orthopnea" (whether they say "can't breathe flat", "need pillows", "sit up to breathe")
        - Any description of leg/ankle swelling → "Peripheral edema" (whether they say "swollen legs", "ankles puffy", "feet bloated")
        
        OUTPUT FORMAT:
        For each symptom found: {"<Exact Symptom Name from list>": {"isPresent": true, "severity": <number 1-10 or null>}}
        Only include symptoms that ARE present. Don't include symptoms not mentioned.
        Extract severity from any format: "7/10", "eight out of ten", "rating 5", "mild", "severe", etc.
        
        Patient note: "\(transcript)"
        
        Think through what symptoms are described, then output JSON only:
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
        
        // Look for JSON object starting with '{'
        guard let startIdx = trimmed.firstIndex(of: "{") else {
            print("⚠️ No JSON object found in output, returning empty JSON")
            print("Raw output: \(trimmed)")
            return "{}"
        }
        
        var braceCount = 0
        var endIdx: String.Index? = nil
        
        // Find matching closing brace
        for idx in trimmed[startIdx...].indices {
            let char = trimmed[idx]
            if char == "{" { 
                braceCount += 1 
            } else if char == "}" { 
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
            
            // Remove any trailing invalid characters before the closing brace
            while !partial.isEmpty && partial.last != "}" && partial.last != "{" {
                let lastChar = partial.last!
                if lastChar != "," && lastChar != "\n" && lastChar != "\r" && lastChar != " " && lastChar != "\t" {
                    // Check if it's part of a valid JSON value
                    if !lastChar.isLetter && !lastChar.isNumber && lastChar != "\"" && lastChar != "'" && lastChar != ":" {
                        partial = String(partial.dropLast())
                    } else {
                        break
                    }
                } else {
                    partial = String(partial.dropLast())
                }
            }
            
            // Add missing closing brace(s) based on brace count
            while braceCount > 0 {
                partial += "}"
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
}

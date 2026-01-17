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
        // CONCISE SEMANTIC PROMPT for phi-2 - shorter but still semantic
        let symptomsList = LocalLLMProcessor.allSymptoms.map { "\"\($0)\"" }.joined(separator: ", ")
        return """
        Analyze patient note for cardiac symptoms. Interpret MEANING, not exact words.
        
        SYMPTOMS: [\(symptomsList)]
        
        RULES:
        - Chest pain while sitting/lying/resting/at desk → "Chest pain at rest"
        - Chest pain during walking/exercise/activity → "Chest pain on exertion"
        - Any shortness of breath → "Dyspnea"
        - Trouble breathing when lying flat → "Orthopnea"
        - Waking breathless at night → "Paroxysmal nocturnal dyspnea"
        - Leg/ankle/foot swelling → "Peripheral edema"
        - Dizzy when standing up → "Dizziness upon standing"
        - Fast heart rate → "Tachycardia"
        - Slow heart rate → "Bradycardia"
        - Irregular heartbeat feeling → "Palpitations"
        - Extract severity (1-10) if mentioned, else null
        
        OUTPUT JSON: {"Symptom Name": {"isPresent": true, "severity": number or null}}
        Only include symptoms that ARE present.
        
        Patient: "\(transcript)"
        JSON:
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

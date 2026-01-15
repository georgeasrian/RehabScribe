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
    
    /// Analyzes transcript and returns JSON with detected symptoms
    func analyzeText(_ transcript: String, completion: @escaping (String?) -> Void) {
        // Reload model to reset state
        loadModel()
        
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
        let symptomsList = LocalLLMProcessor.allSymptoms.map { "\"\($0)\"" }.joined(separator: ", ")
        return """
        Task: Read the patient note and extract cardiac symptoms with their severity (1-10 scale, where 1 is mild and 10 is severe).
        Output ONLY valid JSON. No explanations.
        
        CRITICAL RULES:
        1. You MUST ONLY use symptom names from the predefined list below. NEVER create new symptom names.
        2. Phrases like "seven out of ten", "8/10", "rating it 5", etc. are SEVERITY RATINGS, NOT symptom names.
        3. Map natural language descriptions to the exact symptom names from the list (e.g., "chest pain" → "Chest pain at rest" or "Chest pain on exertion").
        4. Extract severity numbers from phrases like "seven out of ten" = 7, "8/10" = 8, "rating it 5" = 5.
        
        For each symptom that is mentioned, include:
        - "isPresent": true
        - "severity": a number from 1-10 (or null if severity cannot be determined)
        
        For symptoms NOT mentioned, do NOT include them in the output (they will be marked as absent automatically).
        
        Available symptoms to check (USE ONLY THESE EXACT NAMES):
        [\(symptomsList)]
        
        Example:
        Patient note: "I just had chest pain seven out of ten"
        JSON output:
        {"Chest pain at rest": {"isPresent": true, "severity": 7}}
        
        Example:
        Patient note: "I felt severe chest pain while resting, rating it 8 out of 10, and had mild dizziness when I stood up, maybe a 3"
        JSON output:
        {"Chest pain at rest": {"isPresent": true, "severity": 8}, "Dizziness upon standing": {"isPresent": true, "severity": 3}}
        
        Example:
        Patient note: "Some chest discomfort when walking, not too bad"
        JSON output:
        {"Chest pain on exertion": {"isPresent": true, "severity": null}, "Chest discomfort": {"isPresent": true, "severity": null}}
        
        That was just the example. Now do that process, but for this task:
        Patient note: "\(transcript)"
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
